defmodule PolarisUI.Components.TreeView do
  @moduledoc """
  The Polaris tree view: the hierarchical, file-system-style browser —
  the port of the Supabase design system TreeView (`packages/ui`,
  `TreeView.tsx`), a styled wrapper over `react-accessible-treeview`
  (the 28px data row: per-level guide lines, chevron + folder glyph,
  inline rename with the accidental-blur guard). The React state
  machine becomes one data-driven function component plus a colocated
  runtime hook that owns expansion and selection client-side.

  ## Anatomy

      <.tree_view
        id="schema-tree"
        label="Database schema"
        items={@tree}
        expanded={["public"]}
        selected={@selected_id}
        editing_id={@editing_id}
        on_select="select-node"
        on_toggle="toggle-node"
        on_rename="rename-node"
      />

      <.tree_view id="schema-tree" items={@tree} on_select="select-node">
        <:item :let={row}>
          <svg aria-hidden="true" … />
          <span class="truncate font-mono">{row.item.name}</span>
          <button phx-click="rename-node" phx-value-id={row.item.id} class="ml-auto …">
            Rename
          </button>
        </:item>
      </.tree_view>

    * **root** — the `<ul role="tree">` the colocated hook anchors
      on; `label` names it for assistive tech.
    * **rows** — one `<li role="treeitem">` per node wrapping the
      source's 28px row: level padding, per-level guide lines, the
      selection bar, chevron/folder (branches) or file glyph (leaves),
      and the truncated name.
    * **groups** — a branch row owns a nested `<ul role="group">`
      with its children's rows (the classic accessible tree), hidden
      while collapsed.
    * **rename input** — the row whose id equals `editing_id` swaps
      its content cluster for the inline rename form.

  ## Data model

  `items` is a list of nested maps — `%{id: "public", name: "Public",
  children: […]}` — where ids must be unique binary strings across the
  whole tree, names are binaries, and leaves simply omit `children`
  (or pass `[]`). Extra per-node keys:

    * `disabled: true` — dims the row, drops it from the tab order,
      and makes the hook skip it (no select, no toggle, no keyboard).
    * `loading: true` — a branch whose children are loading: the
      spinner replaces the chevron (the source's `Loader2`).
    * `description: "…"` — appended to the row's native `title`
      (`name` + newline + the description, exactly the source's
      `titleText`).

  `flatten_tree/1` (public, mirroring the source's exported
  `flattenTree`) flattens the tree depth-first into rows of
  `%{id, name, parent_id, level, is_branch, children_ids, node}` —
  handy for building server-side views of the same data. Bad shapes
  raise `ArgumentError` with a helpful message (non-map items,
  missing/non-binary ids, duplicate ids, non-binary names,
  non-list children).

  ## State model

  Expansion and selection are **client-owned**, like Radix: the hook
  seeds `expanded`, `selected`, and `editing_id` from the
  server-rendered DOM once, then owns them — later patches never
  reset what the user opened or picked (`updated/0` re-applies the
  hook's own sets over the patched HTML). Clicking a branch toggles
  *and* selects it (the source's default config); clicking a leaf
  selects it. Each change optionally mirrors to the server:

    * `on_select` — `%{"id" => id}` on every selection.
    * `on_toggle` — `%{"id" => id, "state" => "open" | "closed"}`.
    * `on_rename` — `%{"id" => id, "value" => value}` on rename
      submit (including the cancelled/original value on Escape, like
      the source).

  `editing_id` is server-driven: set it to a node's id to open the
  rename input in that row (typically from a row action), clear it
  after `on_rename` lands.

  ## Keyboard

  One tab stop for the whole tree (roving tabindex — the selected
  item, else the first visible); arrows walk **visible** items only:

    * **ArrowDown / ArrowUp** — next / previous visible item (no wrap).
    * **ArrowRight** — expand a collapsed branch; on an expanded
      branch, move to the next visible item.
    * **ArrowLeft** — collapse an expanded branch; on a collapsed
      branch or leaf, move to its parent row.
    * **Home / End** — first / last visible item.
    * **Enter / Space** — select (and toggle, on a branch), like a
      click. Disabled rows are skipped entirely.

  ## Editing

  The rename input ports the source's exact timing contract: focus is
  attempted after **200ms** (a closing dropdown steals focus first —
  radix-ui/primitives#3106), the text up to the **last dot** is
  selected **50ms** later (rename `users.sql`, keep the extension),
  **Enter** blurs (submitting), **Escape** restores the original name
  and submits that, and a blur within **400ms** of edit start is
  treated as accidental — focus is taken back instead of submitting.
  The push happens once per edit session.

  ## Accessibility

    * The root is a `<ul role="tree" aria-label>`; rows are
      `<li role="treeitem">` carrying `aria-level`, `aria-selected`
      (on every item), `aria-expanded` (branches only), and
      `aria-disabled`; branch groups are nested `<ul role="group">`
      hidden with the `hidden` attribute while collapsed.
    * Roving tabindex keeps exactly one tab stop; focus rings on the
      row via the `group/tree-item` relationship.
    * The chevron, folder, file, and spinner glyphs are
      `aria-hidden` decoration; actions inside custom rows stay
      focusable and never trigger select/toggle.

  ## Microcopy

  Tree labels are short nouns — table names, folder names, schema
  names ("public", "Tables", "users"). The `label` names the whole
  tree ("Database schema"); descriptions are one-line noun phrases.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @chevron_half 7

  # ─────────────────────────────────────────────────────────────
  # flatten_tree/1 — the source's exported flattenTree
  # ─────────────────────────────────────────────────────────────

  @doc """
  Flattens a nested tree into depth-first rows, validating the shape.

  Every entry is `%{id, name, parent_id, level, is_branch,
  children_ids, node}` — `parent_id` is `nil` at the root level,
  `is_branch` is true when the node has children, and `node` is the
  original item map. Raises `ArgumentError` on malformed items.
  """
  @spec flatten_tree(list()) :: [map()]
  def flatten_tree(items) when is_list(items) do
    {entries, _seen} = do_flatten(items, nil, 1, %{}, [])
    Enum.reverse(entries)
  end

  def flatten_tree(other) do
    raise ArgumentError,
          "PolarisUI tree_view: :items must be a list of node maps, got: #{inspect(other)}"
  end

  defp do_flatten(items, parent_id, level, seen, acc) do
    Enum.reduce(items, {acc, seen}, fn node, {acc, seen} ->
      validate_node!(node)

      id = Map.fetch!(node, :id)

      if Map.has_key?(seen, id) do
        raise ArgumentError,
              "PolarisUI tree_view: duplicate item id #{inspect(id)} — ids must be unique across the whole tree"
      end

      children = Map.get(node, :children, [])

      entry = %{
        id: id,
        name: Map.fetch!(node, :name),
        parent_id: parent_id,
        level: level,
        is_branch: children != [],
        children_ids: Enum.map(children, &Map.fetch!(&1, :id)),
        node: node
      }

      do_flatten(children, id, level + 1, Map.put(seen, id, true), [entry | acc])
    end)
  end

  defp validate_node!(node) do
    unless is_map(node) do
      raise ArgumentError,
            "PolarisUI tree_view: every tree item must be a map, got: #{inspect(node)}"
    end

    id = Map.get(node, :id)
    name = Map.get(node, :name)
    children = Map.get(node, :children, [])

    unless is_binary(id) and id != "" do
      raise ArgumentError,
            "PolarisUI tree_view: every tree item needs a non-empty string :id, got: #{inspect(id)} — in item #{inspect(node)}"
    end

    unless is_binary(name) do
      raise ArgumentError,
            "PolarisUI tree_view: every tree item needs a string :name, got: #{inspect(name)} — in item #{inspect(node)}"
    end

    unless is_list(children) and Enum.all?(children, &is_map/1) do
      raise ArgumentError,
            "PolarisUI tree_view: :children must be a list of item maps, got: #{inspect(children)} — in item #{inspect(node)}"
    end

    :ok
  end

  # ─────────────────────────────────────────────────────────────
  # tree_view
  # ─────────────────────────────────────────────────────────────

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the tree root — required because the colocated hook
    that owns expansion and selection anchors on it. Row and group
    element ids derive from it (`"<id>-<item id>-item"` / `"-group"`).
    """
  )

  attr(:items, :list,
    required: true,
    doc: """
    The nested node maps: `%{id: "public", name: "Public", children: […]}`.
    Ids must be unique strings; leaves omit `children` (or pass `[]`).
    Per-node extras: `disabled: true`, `loading: true` (branches),
    `description` (the native title).
    """
  )

  attr(:expanded, :list,
    default: [],
    doc: "Ids open on first render — seeds only; the hook owns expansion from then on."
  )

  attr(:selected, :string,
    default: nil,
    doc: "The id selected on first render — seed only; the hook owns selection."
  )

  attr(:editing_id, :string,
    default: nil,
    doc: """
    The node whose row renders the inline rename input — server-driven
    (set it from a row action, clear it after `on_rename`).
    """
  )

  attr(:on_select, :string,
    default: nil,
    doc: """
    LiveView event pushed on every selection with `%{"id" => id}`.
    """
  )

  attr(:on_toggle, :string,
    default: nil,
    doc: """
    LiveView event pushed on expand/collapse with
    `%{"id" => id, "state" => "open" | "closed"}`.
    """
  )

  attr(:on_rename, :string,
    default: nil,
    doc: """
    LiveView event pushed on rename submit with
    `%{"id" => id, "value" => value}`.
    """
  )

  attr(:label, :string,
    default: nil,
    doc: "Accessible name for the tree landmark (\"Database schema\")."
  )

  attr(:x_padding, :integer,
    default: 16,
    doc: "The row's base left padding in px (the source's `xPadding`)."
  )

  attr(:level_padding, :integer,
    default: 38,
    doc: """
    Indent stride per level in px (the source's `levelPadding`) — each
    level adds `level_padding / 2` px: row padding is
    `x_padding + (level - 1) * level_padding / 2`.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root `<ul>` — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the root `<ul>`: `data-*`, `phx-*`, …")

  slot(:item,
    doc: """
    Optional custom row content — replaces the default chevron +
    folder/file icon + name cluster on **every** row. Receives let
    bindings:

        <:item :let={row}>
          … row.item (the node map) · row.level · row.is_branch ·
          row.is_expanded · row.is_selected …
        </:item>

    Actions (rename buttons, badges, menus) belong inside this slot's
    content — there is no separate actions slot. Anchors, buttons,
    and inputs inside the content never trigger select/toggle, and
    can rebuild the default cluster from the bindings.
    """
  )

  def tree_view(assigns) do
    validate_padding!(:x_padding, assigns.x_padding)
    validate_padding!(:level_padding, assigns.level_padding)

    entries = flatten_tree(assigns.items)
    by_id = Map.new(entries, &{&1.id, &1})

    expanded_ids =
      assigns.expanded
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> MapSet.new()

    selected_id = assigns.selected && to_string(assigns.selected)

    visible_ids =
      entries
      |> Enum.filter(&visible_entry?(&1, expanded_ids, by_id))
      |> Map.new(&{&1.id, true})

    tabindex_id = seed_tabindex_id(entries, visible_ids, by_id, selected_id)

    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        ctx: %{
          root_id: assigns.id,
          expanded: expanded_ids,
          selected: selected_id,
          editing_id: assigns.editing_id && to_string(assigns.editing_id),
          x_padding: assigns.x_padding,
          level_padding: assigns.level_padding,
          tabindex: Map.new(entries, &{&1.id, if(&1.id == tabindex_id, do: "0", else: "-1")}),
          item_slot: assigns.item,
          has_slot: assigns.item != []
        }
      )

    ~H"""
    <ul
      id={@id}
      role="tree"
      aria-label={@label}
      data-polaris-tree-view
      data-select-event={@on_select}
      data-toggle-event={@on_toggle}
      data-rename-event={@on_rename}
      phx-hook={@hook}
      class={cn(["w-full list-none p-0 text-sm", @class])}
      {@rest}
    >
      <.tree_row :for={item <- @items} item={item} level={1} ctx={@ctx} />
    </ul>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          // Seed expansion + selection from the server-rendered DOM once;
          // from here the hook owns them, like Radix.
          this._expanded = new Set(
            this._items()
              .filter((item) => item.dataset.state === "open")
              .map((item) => item.dataset.id)
          )
          const selected = this._items().find(
            (item) => item.getAttribute("aria-selected") === "true"
          )
          this._selected = selected ? selected.dataset.id : null
          this._onClick = (event) => {
            // Actions and links inside custom rows never select/toggle.
            if (event.target.closest("a, button, input, select, textarea, [contenteditable]")) {
              return
            }
            const row = event.target.closest("[data-polaris-tree-row]")
            if (!row || !this.el.contains(row)) return
            const item = row.closest("[data-polaris-tree-item]")
            if (!item || item.dataset.disabled === "true") return
            this._activate(item)
          }
          this._onKeydown = (event) => {
            const rename = event.target.closest("[data-polaris-tree-rename-input]")
            if (rename) {
              // Enter blurs (the blur path submits); Escape restores the
              // original name and submits it; every other key stays local.
              if (event.key === "Enter") {
                event.preventDefault()
                rename.blur()
              } else if (event.key === "Escape") {
                event.preventDefault()
                rename.value = this._renameOriginal
                this._submitRename(this._renameOriginal)
              }
              return
            }
            const item = event.target.closest("[data-polaris-tree-item]")
            if (!item || !this.el.contains(item) || item.dataset.disabled === "true") return
            const visible = this._visibleItems()
            const index = visible.indexOf(item)
            if (index === -1) return
            if (event.key === "ArrowDown") {
              event.preventDefault()
              const next = visible[index + 1]
              if (next) next.focus()
            } else if (event.key === "ArrowUp") {
              event.preventDefault()
              const prev = visible[index - 1]
              if (prev) prev.focus()
            } else if (event.key === "ArrowRight") {
              event.preventDefault()
              if (item.dataset.branch === "true" && !this._expanded.has(item.dataset.id)) {
                this._toggle(item.dataset.id)
              } else {
                const next = visible[index + 1]
                if (next) next.focus()
              }
            } else if (event.key === "ArrowLeft") {
              event.preventDefault()
              if (item.dataset.branch === "true" && this._expanded.has(item.dataset.id)) {
                this._collapse(item.dataset.id)
              } else {
                const group = item.closest("[data-polaris-tree-group]")
                if (group) {
                  const parent = this._itemById(group.dataset.parentId)
                  if (parent) parent.focus()
                }
              }
            } else if (event.key === "Home") {
              event.preventDefault()
              if (visible[0]) visible[0].focus()
            } else if (event.key === "End") {
              event.preventDefault()
              visible[visible.length - 1].focus()
            } else if (event.key === "Enter" || event.key === " ") {
              event.preventDefault()
              this._activate(item)
            }
          }
          this._onFocusOut = (event) => {
            const input = event.target.closest("[data-polaris-tree-rename-input]")
            if (!input || input !== this._renameInput) return
            // Accidental-blur guard: a blur within 400ms of edit start is
            // the closing animation stealing focus — take it back.
            if (Date.now() - this._editStart < 400) {
              event.preventDefault()
              input.focus()
            } else {
              this._submitRename(input.value)
            }
          }
          this._onSubmit = (event) => {
            const form = event.target.closest("[data-polaris-tree-rename]")
            if (!form) return
            event.preventDefault()
            const input = form.querySelector("[data-polaris-tree-rename-input]")
            if (input) this._submitRename(input.value)
          }
          this.el.addEventListener("click", this._onClick)
          this.el.addEventListener("keydown", this._onKeydown)
          this.el.addEventListener("focusout", this._onFocusOut)
          this.el.addEventListener("submit", this._onSubmit)
          this._apply()
          this._bindRename()
        },
        updated() {
          // LiveView patches stomp aria/data-state/hidden — reconcile the
          // DOM from the hook-owned sets, never from the server HTML.
          this._apply()
          this._bindRename()
        },
        destroyed() {
          this.el.removeEventListener("click", this._onClick)
          this.el.removeEventListener("keydown", this._onKeydown)
          this.el.removeEventListener("focusout", this._onFocusOut)
          this.el.removeEventListener("submit", this._onSubmit)
          this._clearRenameTimers()
        },
        _items() {
          return Array.from(this.el.querySelectorAll("[data-polaris-tree-item]"))
        },
        _itemById(id) {
          return this._items().find((item) => item.dataset.id === id) || null
        },
        _visibleItems() {
          // Visible = not inside a collapsed group (its ul carries [hidden]).
          return this._items().filter(
            (item) => !item.closest("[data-polaris-tree-group][hidden]")
          )
        },
        _activate(item) {
          // The source's default config: a branch click both selects and toggles.
          if (item.dataset.branch === "true") {
            this._toggle(item.dataset.id)
          }
          this._select(item.dataset.id)
        },
        _toggle(id) {
          const open = !this._expanded.has(id)
          if (open) {
            this._expanded.add(id)
          } else {
            this._expanded.delete(id)
          }
          this._apply()
          this._push(this.el.dataset.toggleEvent, { id: id, state: open ? "open" : "closed" })
        },
        _collapse(id) {
          this._expanded.delete(id)
          this._apply()
          this._push(this.el.dataset.toggleEvent, { id: id, state: "closed" })
        },
        _select(id) {
          this._selected = id
          this._apply()
          this._push(this.el.dataset.selectEvent, { id: id })
        },
        _push(name, payload) {
          if (name && typeof this.pushEvent === "function") {
            this.pushEvent(name, payload)
          }
        },
        _apply() {
          const items = this._items()
          const groups = new Map()
          for (const group of this.el.querySelectorAll("[data-polaris-tree-group]")) {
            groups.set(group.dataset.parentId, group)
          }
          for (const item of items) {
            const id = item.dataset.id
            item.setAttribute("aria-selected", String(id === this._selected))
            if (item.dataset.branch === "true") {
              const open = this._expanded.has(id)
              item.setAttribute("aria-expanded", String(open))
              item.dataset.state = open ? "open" : "closed"
              const group = groups.get(id)
              if (group) {
                group.hidden = !open
              }
            }
          }
          this._rove()
        },
        _rove() {
          // Exactly one tab stop: the selected item, else the first visible.
          const items = this._items()
          const enabled = this._visibleItems().filter(
            (item) => item.dataset.disabled !== "true"
          )
          const active =
            (this._selected && enabled.find((item) => item.dataset.id === this._selected)) ||
            enabled[0] ||
            null
          for (const item of items) {
            item.tabIndex = item === active ? 0 : -1
          }
        },
        // ── Inline rename — the source's exact timing contract ──
        _bindRename() {
          const input = this.el.querySelector("[data-polaris-tree-rename-input]")
          if (!input) {
            this._clearRenameTimers()
            this._renameInput = null
            return
          }
          if (input === this._renameInput) return
          this._renameInput = input
          this._renameOriginal = input.value
          this._renameDone = false
          this._editStart = Date.now()
          this._clearRenameTimers()
          // Focus is attempted after 200ms so dropdown close animations
          // are complete (they steal focus — radix-ui/primitives#3106).
          this._renameTimers = [
            setTimeout(() => {
              if (document.activeElement !== input) {
                input.focus()
              }
              // Selection needs focus established first (+50ms), then
              // selects up to the last dot — rename "users.sql", keep ".sql".
              this._renameTimers.push(
                setTimeout(() => {
                  const fileName = input.value
                  const lastDotIndex = fileName.lastIndexOf(".")
                  const endPos = lastDotIndex > 0 ? lastDotIndex : fileName.length
                  try {
                    input.setSelectionRange(0, endPos)
                  } catch (e) {
                    console.error("Could not set selection range", e)
                  }
                }, 50)
              )
            }, 200)
          ]
        },
        _clearRenameTimers() {
          if (this._renameTimers) {
            for (const timer of this._renameTimers) clearTimeout(timer)
          }
          this._renameTimers = []
        },
        _submitRename(value) {
          if (this._renameDone || !this._renameInput) return
          this._renameDone = true
          const item = this._renameInput.closest("[data-polaris-tree-item]")
          this._push(this.el.dataset.renameEvent, {
            id: item ? item.dataset.id : null,
            value: value
          })
        }
      }
    </script>
    """
  end

  # ─────────────────────────────────────────────────────────────
  # Row rendering (recursive)
  # ─────────────────────────────────────────────────────────────

  # The treeitem <li> carries the ARIA state (group/tree-item); the row
  # div inside is the source's 28px visual, reacting to the li's aria
  # through group-aria-* variants. Branch rows nest their children's
  # <ul role="group"> inside the li — the classic accessible tree.
  defp tree_row(assigns) do
    %{item: item, level: level, ctx: ctx} = assigns

    children = Map.get(item, :children, [])
    is_branch = children != []
    is_expanded = is_branch and MapSet.member?(ctx.expanded, item.id)
    is_selected = ctx.selected == item.id
    is_editing = ctx.editing_id == item.id
    is_disabled = Map.get(item, :disabled, false) == true
    is_loading = Map.get(item, :loading, false) == true

    description = Map.get(item, :description)
    trimmed = description && String.trim(description)

    assigns =
      assign(assigns,
        children: children,
        level: level,
        is_branch: is_branch,
        is_expanded: is_expanded,
        is_selected: is_selected,
        is_editing: is_editing,
        is_disabled: is_disabled,
        is_loading: is_loading,
        title_text: if(trimmed && trimmed != "", do: "#{item.name}\n#{trimmed}", else: item.name),
        row_classes:
          cn([
            "relative flex h-[28px] items-center gap-3 text-sm cursor-pointer select-none",
            "text-content-secondary transition-colors",
            "hover:bg-surface-muted",
            "group-aria-selected/tree-item:bg-brand-emerald-muted",
            "group-aria-selected/tree-item:text-content-primary",
            "group-focus-visible/tree-item:outline-none",
            "group-focus-visible/tree-item:ring-2 group-focus-visible/tree-item:ring-brand-emerald",
            "group-focus-visible/tree-item:ring-offset-2 group-focus-visible/tree-item:ring-offset-surface-ground",
            "group-aria-disabled/tree-item:pointer-events-none group-aria-disabled/tree-item:opacity-50",
            "group-aria-disabled/tree-item:cursor-not-allowed"
          ]),
        pad: ctx.x_padding + div((level - 1) * ctx.level_padding, 2),
        # One vertical guide line per ancestor level (level - 1 of them),
        # at x_padding + i * level_padding / 2 + 7 (the chevron's half
        # width, the source's CHEVRON_ICON_SIZE / 2).
        guide_lefts:
          Enum.map(0..(level - 2)//1, fn i ->
            "#{ctx.x_padding + div(i * ctx.level_padding, 2) + @chevron_half}px"
          end)
      )

    ~H"""
    <li
      id={"#{@ctx.root_id}-#{@item.id}-item"}
      role="treeitem"
      data-polaris-tree-item
      data-id={@item.id}
      data-branch={to_string(@is_branch)}
      data-state={@is_branch and ((@is_expanded && "open") || "closed")}
      data-disabled={@is_disabled && "true"}
      data-loading={@is_loading && "true"}
      aria-level={@level}
      aria-selected={to_string(@is_selected)}
      aria-expanded={@is_branch and to_string(@is_expanded)}
      aria-disabled={@is_disabled && "true"}
      tabindex={Map.get(@ctx.tabindex, @item.id, "-1")}
      class="group/tree-item outline-none"
    >
      <div
        data-polaris-tree-row
        title={@title_text}
        class={@row_classes}
        style={"padding-left: #{@pad}px;"}
      >
        <div
          :for={left <- @guide_lefts}
          aria-hidden="true"
          class="absolute h-full w-px bg-surface-border-hover"
          style={"left: #{left};"}
        >
        </div>
        <div
          :if={@is_selected}
          class="absolute left-0 h-full w-0.5 bg-content-primary"
          aria-hidden="true"
        >
        </div>
        <%= if @is_editing do %>
          <form data-polaris-tree-rename class="w-full">
            <input
              type="text"
              data-polaris-tree-rename-input
              aria-label={"Rename #{@item.name}"}
              value={@item.name}
              class={
                cn([
                  "flex h-7 w-full rounded-md border border-surface-border bg-surface-panel",
                  "px-2 py-1 text-sm text-content-primary placeholder:text-content-muted",
                  "transition-colors hover:border-surface-border-hover",
                  "focus:border-surface-border-hover focus:outline-none",
                  "focus-visible:ring-2 focus-visible:ring-brand-emerald",
                  "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
                  "disabled:cursor-not-allowed disabled:text-content-muted"
                ])
              }
            />
          </form>
        <% else %>
          <%= if @ctx.has_slot do %>
            {render_slot(@ctx.item_slot, %{
              item: @item,
              level: @level,
              is_branch: @is_branch,
              is_expanded: @is_expanded,
              is_selected: @is_selected
            })}
          <% else %>
            <div class="flex items-center gap-x-3 truncate">
              <%= if @is_branch do %>
                <%= if @is_loading do %>
                  <.spinner />
                <% else %>
                  <.chevron />
                <% end %>
                <.folder_icon open={@is_expanded} />
              <% else %>
                <.leaf_icon />
              <% end %>
              <span class="truncate text-sm">{@item.name}</span>
            </div>
          <% end %>
        <% end %>
      </div>
      <ul
        :if={@is_branch}
        id={"#{@ctx.root_id}-#{@item.id}-group"}
        role="group"
        data-polaris-tree-group
        data-parent-id={@item.id}
        class="list-none p-0"
        hidden={!@is_expanded}
      >
        <.tree_row :for={child <- @children} item={child} level={@level + 1} ctx={@ctx} />
      </ul>
    </li>
    """
  end

  # The branch chevron — lucide ChevronRight at 14px, rotating 90° while
  # expanded (group-aria-expanded on the treeitem li), like the source.
  defp chevron(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={
        cn([
          "size-3.5 shrink-0 text-content-muted transition-transform duration-200",
          "group-aria-selected/tree-item:text-content-secondary",
          "group-aria-expanded/tree-item:text-content-secondary",
          "group-aria-expanded/tree-item:rotate-90",
          "motion-reduce:transition-none"
        ])
      }
      aria-hidden="true"
    >
      <path d="m9 18 6-6-6-6" />
    </svg>
    """
  end

  # The branch folder — lucide FolderClosed / FolderOpen geometry at
  # 16px. Both paths render and CSS picks the geometry from the li's
  # `aria-expanded` (the same contract the chevron rotates on), so the
  # hook's client-side toggles stay visually in sync without a re-render.
  defp folder_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={
        cn([
          "size-4 shrink-0 text-content-muted transition-colors",
          "group-aria-selected/tree-item:text-content-secondary",
          "group-aria-expanded/tree-item:text-content-secondary"
        ])
      }
      aria-hidden="true"
    >
      <path
        class="group-aria-expanded/tree-item:hidden"
        d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"
      />
      <path
        class="hidden group-aria-expanded/tree-item:block"
        d="M6 14l1.45-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.55 6a2 2 0 0 1-1.93 1.5H4a2 2 0 0 1-2-2V5c0-1.1.9-2 2-2h3.93a2 2 0 0 1 1.66.9l.82 1.2a2 2 0 0 0 1.66.9H18a2 2 0 0 1 2 2v2"
      />
    </svg>
    """
  end

  # The default leaf glyph. Deviation: the source renders the Supabase
  # SQL product glyph on leaves — a brand mark, not a design-system
  # asset. The port ships a neutral file icon (lucide File geometry);
  # pass any icon per node through the `item` slot.
  defp leaf_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={
        cn([
          "size-4 shrink-0 text-content-muted transition-colors",
          "group-aria-selected/tree-item:text-content-secondary"
        ])
      }
      aria-hidden="true"
    >
      <path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z" />
      <path d="M14 2v4a2 2 0 0 0 2 2h4" />
    </svg>
    """
  end

  # The loading branch's spinner — lucide Loader2 at 14px, replacing
  # the chevron while children load.
  defp spinner(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      class="size-3.5 shrink-0 animate-spin text-content-muted"
      aria-hidden="true"
    >
      <path d="M21 12a9 9 0 1 1-6.219-8.56" />
    </svg>
    """
  end

  # ─────────────────────────────────────────────────────────────
  # Server-side seed helpers
  # ─────────────────────────────────────────────────────────────

  # A row is visible when every ancestor is expanded (seed set).
  defp visible_entry?(%{parent_id: nil}, _expanded, _by_id), do: true

  defp visible_entry?(%{parent_id: parent_id}, expanded, by_id) do
    case Map.get(by_id, parent_id) do
      nil ->
        true

      parent ->
        MapSet.member?(expanded, parent.id) and visible_entry?(parent, expanded, by_id)
    end
  end

  # The roving-tabindex seed: the selected row (when visible and
  # enabled), else the first visible enabled row — the hook's rule.
  defp seed_tabindex_id(entries, visible_ids, by_id, selected_id) do
    selected_usable? =
      is_binary(selected_id) and
        Map.has_key?(visible_ids, selected_id) and
        not disabled_entry?(Map.get(by_id, selected_id))

    if selected_usable? do
      selected_id
    else
      case Enum.find(entries, &(Map.has_key?(visible_ids, &1.id) and not disabled_entry?(&1))) do
        nil -> nil
        entry -> entry.id
      end
    end
  end

  defp disabled_entry?(nil), do: false

  defp disabled_entry?(entry), do: Map.get(entry.node, :disabled, false) == true

  defp validate_padding!(name, value) do
    unless is_integer(value) and value >= 0 do
      raise ArgumentError,
            "PolarisUI tree_view: :#{name} must be a non-negative integer, got: #{inspect(value)}"
    end
  end
end
