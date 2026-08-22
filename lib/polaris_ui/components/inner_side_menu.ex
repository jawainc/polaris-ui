defmodule PolarisUI.Components.InnerSideMenu do
  @moduledoc """
  The Polaris inner side menu: the composable family for the secondary
  navigation column inside a dashboard page — collapsible sections,
  nav items, separators, search, sorting, loading rows, and empty
  panels.

  Port of the Supabase design system fragment
  `ui-patterns/InnerSideMenu`. The fragment ships fourteen loose
  Radix-composed exports; here the pieces map onto LiveView idioms:

  | Fragment | Polaris |
  |---|---|
  | (none — demos wrap in a Card) | `inner_side_menu` — a `<nav>` landmark (an improvement: the fragment has none) |
  | `InnerSideBarTitle` | `inner_side_menu_title` — static mono-uppercase section header |
  | `InnerSideMenuCollapsible` + `Trigger` + `Content` | `inner_side_menu_collapsible` — one component with `title` (LiveView has no context to wire the three Radix pieces) |
  | `InnerSideMenuItem` | `inner_side_menu_item` — the nav link |
  | `InnerSideMenuDataItem` | `inner_side_menu_data_item` — the tree-view styled link (table-editor sidebars) |
  | `InnerSideMenuItemLoading` | `inner_side_menu_item_loading` — a skeleton row |
  | `InnerSideMenuSeparator` | `inner_side_menu_separator` |
  | `InnerSideBarFilters` | `inner_side_menu_filters` — the filter row |
  | `InnerSideBarFilterSearchInput` | `inner_side_menu_search_input` — icon/spinner search field |
  | `InnerSideBarFilterSortDropdown(Item)` | `inner_side_menu_sort_dropdown` — the sort popover with radio items |
  | `InnerSideBarEmptyPanel` | `inner_side_menu_empty_panel` |

  ## Composition

      <.inner_side_menu label="Project navigation">
        <.inner_side_menu_search_input
          name="menu-search"
          label="Search items"
          phx-change="search-menu"
        />
        <.inner_side_menu_collapsible id="development" title="Development" default_open>
          <.inner_side_menu_item href="/project/api" is_active={@path == "/project/api"}>
            API
          </.inner_side_menu_item>
          <.inner_side_menu_item href="/project/db">Database</.inner_side_menu_item>
        </.inner_side_menu_collapsible>
        <.inner_side_menu_separator />
        <.inner_side_menu_title>Analytics</.inner_side_menu_title>
        <.inner_side_menu_item href="/project/reports">Reports</.inner_side_menu_item>
      </.inner_side_menu>

  ## Section headers

  Collapsible groups carry the mono-uppercase trigger (chevron rotating
  90° while open, `text-sm tracking-wide`); when a section never needs
  collapsing, use `inner_side_menu_title` and wrap the items yourself.
  Keep titles to short noun phrases ("Development", "Analytics").

  ## Items and active state

  `is_active` is prop-driven like the fragment — the caller computes it
  (usually a path match); active items render `aria-current="page"`
  (the fragment renders `aria-current="true"`; `"page"` is the correct
  token for route-based actives) with the selection fill. Items keep
  1–2 word labels ("Dashboard", "API").

  ## Loading and empty states

  `inner_side_menu_item_loading` stacks skeleton rows sized to real rows
  (`h-7`) so loading never shifts layout. `inner_side_menu_empty_panel`
  is the zero-results panel inside a section: title "No {things} found",
  a constructive description, an optional illustration, and an action
  with a direct verb ("Create function").

  No colocated hook is required for the static pieces — only the
  collapsible groups and the sort dropdown carry *runtime* hooks (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  ## ------------------------------------------------------------------
  ## Root navigation wrapper
  ## ------------------------------------------------------------------

  attr(:label, :string,
    default: nil,
    doc: "Accessible name for the `<nav>` landmark (e.g. \"Project navigation\")."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the `<nav>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "Sections, titles, items, separators, filters.")

  def inner_side_menu(assigns) do
    ~H"""
    <nav
      class={cn(["flex flex-col gap-6", @class])}
      aria-label={@label}
      data-polaris-inner-side-menu
      {@rest}
    >
      {render_slot(@inner_block)}
    </nav>
    """
  end

  ## ------------------------------------------------------------------
  ## Static section title
  ## ------------------------------------------------------------------

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the title.")
  attr(:rest, :global, doc: "Forwarded to the `<span>`: `id`, `data-*`, …")

  slot(:inner_block, required: true, doc: "The section heading — a short noun phrase.")

  def inner_side_menu_title(assigns) do
    ~H"""
    <span
      class={
        cn([
          "group flex w-full items-center gap-1 px-3 font-mono text-sm font-normal uppercase tracking-wide text-content-muted transition-colors group-hover:text-content-primary",
          "hover:text-content-primary",
          @class
        ])
      }
      data-polaris-ism-title
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  ## ------------------------------------------------------------------
  ## Collapsible section (trigger + content)
  ## ------------------------------------------------------------------

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the section root — required because the colocated hook
    that manages open/close state anchors on it. The content id derives
    as `"<id>-content"`.
    """
  )

  attr(:title, :string,
    required: true,
    doc: "Section heading — a short noun phrase (\"Development\")."
  )

  attr(:default_open, :boolean,
    default: false,
    doc: "Start expanded instead of collapsed (initial state only — state is client-side)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root.")

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The section's items (or empty panel).")

  def inner_side_menu_collapsible(assigns) do
    state = if assigns.default_open, do: "open", else: "closed"

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Group",
        state: state,
        content_id: "#{assigns.id}-content",
        root_classes: cn(["group/ism w-full px-2", assigns.class])
      )

    ~H"""
    <div id={@id} class={@root_classes} data-state={@state} phx-hook={@hook} {@rest}>
      <button
        type="button"
        class={
          cn([
            "flex w-full items-center gap-1 px-3 font-mono text-sm font-normal uppercase tracking-wide text-content-muted",
            "transition-colors hover:text-content-primary focus-visible:outline-none",
            "focus-visible:ring-2 focus-visible:ring-brand-emerald focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "data-[state=open]:text-content-secondary"
          ])
        }
        aria-expanded={to_string(@state == "open")}
        aria-controls={@content_id}
        data-state={@state}
        data-polaris-ism-collapsible-trigger
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-4 text-content-muted transition-all group-data-[state=open]/ism:rotate-90"
          aria-hidden="true"
        >
          <path d="m9 18 6-6-6-6" />
        </svg>
        <span class="truncate">{@title}</span>
      </button>
      <div
        id={@content_id}
        class="grid grid-rows-[0fr] invisible transition-[grid-template-rows,visibility] duration-100 ease-out data-[state=open]:grid-rows-[1fr] data-[state=open]:visible"
        data-state={@state}
        data-polaris-ism-collapsible-content
      >
        <%!-- pt-2 lives inside the collapsing row so it animates away too. --%>
        <div class="min-h-0 overflow-hidden pt-2">
          <div class="flex w-full flex-col gap-0">{render_slot(@inner_block)}</div>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Group" runtime>
      {
        mounted() {
          const root = this.el
          this._open = root.dataset.state === "open"
          this._apply = (open) => {
            this._open = open
            root.dataset.state = open ? "open" : "closed"
            const content = root.querySelector("[data-polaris-ism-collapsible-content]")
            if (content) {
              content.dataset.state = open ? "open" : "closed"
            }
            const trigger = root.querySelector("[data-polaris-ism-collapsible-trigger]")
            if (trigger) {
              trigger.dataset.state = open ? "open" : "closed"
              trigger.setAttribute("aria-expanded", String(open))
            }
          }
          // Delegated on the root so the listener survives child re-patches.
          this._onClick = (event) => {
            const trigger = event.target.closest("[data-polaris-ism-collapsible-trigger]")
            if (trigger && root.contains(trigger)) {
              event.preventDefault()
              this._apply(!this._open)
            }
          }
          root.addEventListener("click", this._onClick)
        },
        updated() {
          // A LiveView patch resets the server-rendered data-state;
          // restore the client's current state.
          if (this._apply) {
            this._apply(this._open)
          }
        },
        destroyed() {
          if (this.el && this._onClick) {
            this.el.removeEventListener("click", this._onClick)
          }
        }
      }
    </script>
    """
  end

  ## ------------------------------------------------------------------
  ## Nav item
  ## ------------------------------------------------------------------

  attr(:href, :string, required: true, doc: "Link target — the route this item navigates to.")

  attr(:is_active, :boolean,
    default: false,
    doc:
      "Selection state (compute from the current path). Renders `aria-current=\"page\"` when set."
  )

  attr(:force_hover_state, :boolean,
    default: false,
    doc: "Pin the hover background (e.g. for parent-hover effects in consuming apps)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<a>`: `phx-click`, `data-*`, `aria-*`, …")

  slot(:inner_block,
    required: true,
    doc: "Item label (left) and any trailing content (badge, chevron)."
  )

  def inner_side_menu_item(assigns) do
    ~H"""
    <a
      href={@href}
      aria-current={@is_active && "page"}
      class={
        cn([
          "group relative flex h-7 items-center justify-between rounded-md pl-3 pr-2 text-sm transition-colors",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
          item_state_classes(@is_active, @force_hover_state),
          @class
        ])
      }
      data-polaris-ism-item
      data-active={to_string(@is_active)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  ## ------------------------------------------------------------------
  ## Data (tree-view styled) item
  ## ------------------------------------------------------------------

  attr(:href, :string, required: true, doc: "Link target.")

  attr(:is_active, :boolean,
    default: true,
    doc:
      "Selection state — defaults to `true` like the fragment's DataItem (opt out with `false`)."
  )

  attr(:is_opened, :boolean,
    default: true,
    doc:
      "Marks the row as opened (e.g. the table currently open in the editor) — subtle control fill."
  )

  attr(:is_preview, :boolean,
    default: false,
    doc: "Preview mode — control fill without the selection indicator bar."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<a>`: `phx-click`, `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "Item label and trailing content.")

  def inner_side_menu_data_item(assigns) do
    ~H"""
    <a
      href={@href}
      aria-current={@is_active && "page"}
      class={
        cn([
          "group relative flex h-7 cursor-pointer select-none items-center gap-3 px-4 text-sm text-content-secondary transition-colors",
          "hover:bg-surface-panel-hover hover:text-content-primary aria-expanded:bg-transparent",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
          data_item_state_classes(assigns),
          @class
        ])
      }
      data-polaris-ism-data-item
      data-active={to_string(@is_active)}
      {@rest}
    >
      <div
        :if={@is_active and not @is_preview}
        class="absolute left-0 h-full w-0.5 bg-content-primary"
        aria-hidden="true"
      />
      {render_slot(@inner_block)}
    </a>
    """
  end

  ## ------------------------------------------------------------------
  ## Loading row
  ## ------------------------------------------------------------------

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the skeleton.")
  attr(:rest, :global, doc: "Forwarded to the wrapper `<div>`: `data-*`, …")

  def inner_side_menu_item_loading(assigns) do
    ~H"""
    <div class="h-7 py-0.5" data-polaris-ism-item-loading {@rest}>
      <div
        class={cn(["h-full w-full animate-pulse rounded-md bg-surface-panel-hover", @class])}
        aria-hidden="true"
      >
      </div>
    </div>
    """
  end

  ## ------------------------------------------------------------------
  ## Separator
  ## ------------------------------------------------------------------

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the hairline.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  def inner_side_menu_separator(assigns) do
    ~H"""
    <div class={cn(["h-px bg-surface-border", @class])} data-polaris-ism-separator {@rest} />
    """
  end

  ## ------------------------------------------------------------------
  ## Filters row + search input
  ## ------------------------------------------------------------------

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the row.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The search input (and any sibling filter controls).")

  def inner_side_menu_filters(assigns) do
    ~H"""
    <div class={cn(["flex items-center gap-2 px-2", @class])} data-polaris-ism-filters {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:name, :string,
    required: true,
    doc: "Input `name` (and `id`) — also the `<label for>` wiring target."
  )

  attr(:label, :string,
    required: true,
    doc: "Visually-hidden label text (\"Search items\") — the input carries no visible label."
  )

  attr(:value, :string, default: nil, doc: "Controlled search term.")

  attr(:placeholder, :string,
    default: "Search...",
    doc: "Placeholder — keep it at \"Search...\"."
  )

  attr(:loading, :boolean,
    default: false,
    doc: "Swap the search glyph for a spinner while results load."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the input.")

  attr(:rest, :global,
    doc: """
    Forwarded to the `<input>`: `phx-change`, `phx-keyup`, `phx-blur`,
    `phx-debounce`, `autocomplete`, …
    """
  )

  slot(:trailing,
    doc: "Control rendered inside the field's trailing slot — the sort dropdown."
  )

  def inner_side_menu_search_input(assigns) do
    has_trailing? = slot_content?(assigns.trailing, assigns)

    assigns =
      assigns
      |> assign(
        has_trailing?: has_trailing?,
        input_classes:
          cn([
            "h-8 w-full rounded-sm border border-surface-border bg-surface-panel pl-7 pr-7",
            "text-base text-content-primary placeholder:text-content-muted transition-colors md:h-7 md:text-xs",
            "hover:border-surface-border-hover",
            "focus:border-surface-border-hover focus:outline-none focus:ring-2 focus:ring-brand-emerald",
            "focus:ring-offset-2 focus:ring-offset-surface-ground",
            "disabled:cursor-not-allowed disabled:text-content-muted",
            assigns.class
          ])
      )

    ~H"""
    <label for={@name} class="relative w-full" data-polaris-ism-search>
      <span class="sr-only">{@label}</span>
      <input
        type="text"
        id={@name}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        class={@input_classes}
        {@rest}
      />
      <%= if @loading do %>
        <.spinner />
      <% else %>
        <.search_glyph />
      <% end %>
      <span
        :if={@has_trailing?}
        class="absolute right-1 top-1/2 -translate-y-1/2"
        data-polaris-ism-search-trailing
      >
        {render_slot(@trailing)}
      </span>
    </label>
    """
  end

  ## ------------------------------------------------------------------
  ## Sort dropdown (radio items)
  ## ------------------------------------------------------------------

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the dropdown root — required because the colocated hook
    that manages open/close state anchors on it.
    """
  )

  attr(:value, :string,
    required: true,
    doc: "Currently selected sort value (matches an item's `value` attr)."
  )

  attr(:on_change, :string,
    required: true,
    doc: "LiveView event fired when a sort option is chosen (receives `value`)."
  )

  attr(:label, :string,
    default: "Sort By",
    doc: "Accessible name / tooltip text for the icon-only trigger."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the menu panel.")

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, …")

  slot(:item,
    required: true,
    validate_attrs: false,
    doc: """
    One sort option per slot, each carrying a `value` attribute — the
    mutually exclusive radio set:

        <:item value="alphabetical">Sort Alphabetically</:item>
        <:item value="reverse">Sort Reverse Alphabetically</:item>
    """
  )

  def inner_side_menu_sort_dropdown(assigns) do
    unless Enum.all?(assigns.item, &Map.has_key?(&1, :value)) do
      raise ArgumentError, """
      PolarisUI inner_side_menu_sort_dropdown: every <:item> needs a \
      value attribute — it is the payload sent with on_change and the \
      key the selected state matches against.
      """
    end

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Sort",
        menu_classes:
          cn([
            "invisible absolute right-0 top-full z-50 mt-1 w-48 origin-top-right rounded-md",
            "border border-surface-border bg-surface-panel py-1 opacity-0 shadow-md",
            "transition-[opacity,visibility] duration-100 ease-out",
            "group-data-[state=open]/ism-sort:visible group-data-[state=open]/ism-sort:opacity-100",
            assigns.class
          ])
      )

    ~H"""
    <div
      id={@id}
      class="group/ism-sort relative inline-flex"
      data-state="closed"
      data-polaris-ism-sort
      phx-hook={@hook}
      {@rest}
    >
      <button
        type="button"
        class={
          cn([
            "flex rounded-xs p-0.5 text-content-secondary transition-colors",
            "hover:text-content-primary focus-visible:outline-none",
            "focus-visible:ring-2 focus-visible:ring-brand-emerald focus-visible:ring-offset-2",
            "focus-visible:ring-offset-surface-ground",
            "data-[state=open]:text-content-primary"
          ])
        }
        aria-label={@label}
        aria-haspopup="menu"
        aria-expanded="false"
        data-state="closed"
        data-polaris-ism-sort-trigger
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-4.5"
          aria-hidden="true"
        >
          <path d="m7 20 5-5 5 5" />
          <path d="m7 4 5 5 5-5" />
        </svg>
      </button>
      <div class={@menu_classes} role="menu" aria-label={@label} data-polaris-ism-sort-content>
        <button
          :for={item <- @item}
          type="button"
          role="menuitemradio"
          aria-checked={to_string(item.value == @value)}
          phx-click={@on_change}
          phx-value-value={item.value}
          class={
            cn([
              "relative flex h-7 w-full cursor-pointer select-none items-center gap-2 pl-6 pr-2",
              "text-left text-xs text-content-primary transition-colors hover:bg-surface-panel-hover",
              "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
              "focus-visible:ring-inset",
              if(item.value == @value, do: "bg-surface-panel-hover")
            ])
          }
          data-polaris-ism-sort-item
          data-value={item.value}
        >
          <span
            class={
              cn([
                "absolute left-2 top-1/2 size-1.5 -translate-y-1/2 rounded-full",
                if(item.value == @value, do: "bg-brand-emerald", else: "bg-content-muted/40")
              ])
            }
            aria-hidden="true"
          />
          {render_slot(item)}
        </button>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Sort" runtime>
      {
        mounted() {
          const root = this.el
          this._open = false
          this._apply = (open) => {
            this._open = open
            root.dataset.state = open ? "open" : "closed"
            const trigger = root.querySelector("[data-polaris-ism-sort-trigger]")
            if (trigger) {
              trigger.dataset.state = open ? "open" : "closed"
              trigger.setAttribute("aria-expanded", String(open))
            }
          }
          this._onTriggerClick = (event) => {
            const trigger = event.target.closest("[data-polaris-ism-sort-trigger]")
            if (trigger && root.contains(trigger)) {
              event.preventDefault()
              this._apply(!this._open)
            }
          }
          this._onItemClick = (event) => {
            const item = event.target.closest("[data-polaris-ism-sort-item]")
            if (item && root.contains(item)) {
              // Let the phx-click push through, then close.
              this._apply(false)
            }
          }
          this._onOutside = (event) => {
            if (this._open && !root.contains(event.target)) {
              this._apply(false)
            }
          }
          this._onKeydown = (event) => {
            if (event.key === "Escape" && this._open) {
              this._apply(false)
            }
          }
          root.addEventListener("click", this._onTriggerClick)
          root.addEventListener("click", this._onItemClick)
          document.addEventListener("click", this._onOutside)
          document.addEventListener("keydown", this._onKeydown)
        },
        updated() {
          if (this._apply) {
            this._apply(this._open)
          }
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onTriggerClick)
          this.el.removeEventListener("click", this._onItemClick)
          document.removeEventListener("click", this._onOutside)
          document.removeEventListener("keydown", this._onKeydown)
        }
      }
    </script>
    """
  end

  ## ------------------------------------------------------------------
  ## Empty panel
  ## ------------------------------------------------------------------

  attr(:title, :string,
    required: true,
    doc: "Zero-results heading — \"No functions found\" (name the things missing)."
  )

  attr(:description, :string,
    default: nil,
    doc: "Constructive one-liner — \"Create your first serverless function to get started.\""
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the panel.")

  attr(:rest, :global, doc: "Forwarded to the panel `<div>`: `data-*`, …")

  slot(:illustration, doc: "Custom illustration markup above the copy (an inline SVG or emoji).")

  slot(:actions, doc: "Action buttons — direct verbs, `<.button>` carries the state machine.")

  slot(:inner_block, doc: "Extra content under the actions.")

  def inner_side_menu_empty_panel(assigns) do
    ~H"""
    <div
      class={
        cn([
          "flex flex-col items-center justify-center gap-y-3 rounded-md border border-surface-border",
          "bg-surface-base px-5 py-4",
          @class
        ])
      }
      data-polaris-ism-empty-panel
      {@rest}
    >
      <div class="flex w-full flex-col items-center gap-y-1">
        {render_slot(@illustration)}
        <p :if={@title} class="text-xs text-content-secondary" data-polaris-ism-empty-title>
          {@title}
        </p>
        <p :if={@description} class="text-center text-xs text-content-muted">
          {@description}
        </p>
        <div :if={@actions != []} class="mt-2">{render_slot(@actions)}</div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  ## ------------------------------------------------------------------
  ## Shared styles
  ## ------------------------------------------------------------------

  # InnerSideMenuItem: selection fill or hover fill, per the fragment
  # (bg-selection / hover:bg-surface-200).
  defp item_state_classes(true, _force_hover),
    do: "bg-content-primary/10 text-content-primary hover:bg-content-primary/15"

  defp item_state_classes(false, true),
    do: "bg-surface-panel-hover text-content-secondary hover:text-content-primary"

  defp item_state_classes(false, false),
    do: "text-content-secondary hover:bg-surface-panel-hover hover:text-content-primary"

  # InnerSideMenuDataItem: the TreeViewItemVariant compounds — selection
  # fill, opened fill, preview fill.
  defp data_item_state_classes(%{is_active: active, is_opened: opened, is_preview: preview}) do
    cond do
      preview ->
        "bg-surface-panel-hover text-content-primary"

      active ->
        "bg-content-primary/10 text-content-primary"

      opened ->
        "bg-surface-panel-hover"

      true ->
        nil
    end
  end

  # Lucide search glyph, absolutely placed inside the field.
  defp search_glyph(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="absolute left-2 top-1/2 size-3.5 -translate-y-1/2 text-content-muted"
      aria-hidden="true"
    >
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </svg>
    """
  end

  # Loader2-style spinner that replaces the search glyph while loading.
  defp spinner(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class="absolute left-2 top-1/2 size-3.5 -translate-y-1/2 animate-spin text-content-muted"
      aria-hidden="true"
    >
      <path d="M21 12a9 9 0 1 1-6.219-8.56" />
    </svg>
    """
  end
end
