defmodule PolarisUI.Components.Command do
  @moduledoc """
  The Polaris command: a searchable, keyboard-driven list of actions —
  the port of the Supabase design system Command (`packages/ui`, the
  cmdk wrapper) that also powers the Supabase Combobox and Command
  Menu compositions.

  Like cmdk, the command is **client-side**: the colocated hook owns
  filtering, highlighting, and keyboard navigation over whatever items
  the server rendered; item activation is the only thing that rounds
  the loop — Enter and click both land on the item's own `phx-click`.

  ## Anatomy

      <.command id="actions" class="rounded-lg border border-surface-border">
        <.command_input placeholder="Type a command or search..." />
        <.command_list>
          <.command_empty>No results found.</.command_empty>
          <.command_group heading="Suggestions">
            <.command_item value="calendar" phx-click="open-calendar">
              Calendar
              <:shortcut>⌘P</:shortcut>
            </.command_item>
            <.command_item value="search emoji" phx-click="open-emoji">
              Search Emoji
            </.command_item>
          </.command_group>
          <.command_separator />
          <.command_group heading="Settings">
            <.command_item value="profile" phx-click="open-profile">Profile</.command_item>
            <.command_item value="billing" phx-click="open-billing">Billing</.command_item>
          </.command_group>
        </.command_list>
      </.command>

    * **root** — the `flex flex-col overflow-hidden rounded-md
      bg-surface-panel` surface carrying the hook.
    * **input** — the search row: bordered bottom, optional magnifier
      glyph, `text-sm` field, and an optional ✕ reset (the source's
      `showResetIcon`) that clears the query client-side.
    * **list** — the `overflow-y-auto` scroll container (`role="listbox"`).
    * **empty** — the `py-6 text-center text-xs` miss state, revealed by
      the hook when nothing matches.
    * **group** — a labelled cluster; the heading renders as the
      signature Supabase mono microcopy (`font-mono uppercase
      tracking-wider text-xs text-content-muted`).
    * **item** — one action. `value` is the filter target (pack
      alternate phrasings into `keywords`, the cmdk pattern), the
      `shortcut` slot right-aligns a ⌘-string, and `phx-click` fires on
      both click and Enter.
    * **separator** — the `-mx-1 h-px` hairline between groups.

  ## Filtering and keyboard

  The hook matches the query against each item's `value` plus
  `keywords` case-insensitively (substring, falling back to cmdk-style
  in-order fuzzy matching), hides misses, hides groups whose items all
  miss, and toggles the empty state. Keys, on the input:

    * **ArrowDown / ArrowUp** — cycle the highlighted item (wraps);
      **Home** / **End** jump to the first / last.
    * **Enter** — activate the highlighted item (the first visible one
      when none is highlighted) by dispatching its own click, so
      `phx-click` bindings fire identically for pointer and keyboard.
    * **Hover** — moving the pointer over an item highlights it, the
      cmdk behavior.

  Highlight rides `aria-activedescendant` off the input (`role=
  "combobox"`), so focus never leaves the field while typing.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the command root — required because the colocated hook
    that owns filtering and keyboard navigation anchors on it. Item ids
    for aria-activedescendant derive from it.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root.")

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, doc: "The command parts: input, list, groups, items, …")

  def command(assigns) do
    assigns = assign(assigns, hook: "#{inspect(__MODULE__)}.Root")

    ~H"""
    <div
      id={@id}
      data-polaris-command
      class={
        cn([
          "flex h-full w-full flex-col overflow-hidden rounded-md",
          "bg-surface-panel text-content-primary",
          @class
        ])
      }
      phx-hook={@hook}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          this._active = null

          this._input = () => root.querySelector("[data-polaris-command-input]")

          this._items = () =>
            Array.from(root.querySelectorAll("[data-polaris-command-item]")).filter(
              (el) => !el.hasAttribute("hidden") && el.dataset.disabled !== "true"
            )

          // cmdk-style matching: substring first, then in-order fuzzy.
          this._matches = (haystack, needle) => {
            if (!needle) return true
            if (haystack.includes(needle)) return true
            let i = 0
            for (const ch of haystack) {
              if (ch === needle[i]) i++
              if (i === needle.length) return true
            }
            return false
          }

          this._filter = () => {
            const input = this._input()
            const needle = (input ? input.value : "").trim().toLowerCase()
            const items = Array.from(root.querySelectorAll("[data-polaris-command-item]"))
            let visible = 0
            items.forEach((item) => {
              const haystack = ((item.dataset.value || "") + " " + (item.dataset.keywords || ""))
                .toLowerCase()
                .trim()
              const hit = this._matches(haystack, needle)
              if (hit) {
                visible = visible + 1
                item.removeAttribute("hidden")
              } else {
                item.setAttribute("hidden", "")
                if (item === this._active) this._setActive(null)
              }
            })
            root.querySelectorAll("[data-polaris-command-group]").forEach((group) => {
              const any = Array.from(
                group.querySelectorAll("[data-polaris-command-item]")
              ).some((item) => !item.hasAttribute("hidden"))
              if (any) {
                group.removeAttribute("hidden")
              } else {
                group.setAttribute("hidden", "")
              }
            })
            const empty = root.querySelector("[data-polaris-command-empty]")
            if (empty) {
              if (visible === 0) {
                empty.removeAttribute("hidden")
              } else {
                empty.setAttribute("hidden", "")
              }
            }
            // cmdk always keeps a selected item when the list is non-empty.
            if (!this._active || this._active.hasAttribute("hidden")) {
              this._setActive(this._items()[0] || null)
            }
          }

          this._setActive = (item) => {
            this._active = item
            const input = this._input()
            root.querySelectorAll("[data-polaris-command-item]").forEach((el) => {
              const selected = el === item
              el.setAttribute("data-selected", String(selected))
              el.setAttribute("aria-selected", String(selected))
              if (selected && input && !el.id) {
                el.id = root.id + "-item-" + Array.from(root.querySelectorAll("[data-polaris-command-item]")).indexOf(el)
              }
            })
            if (input) {
              input.setAttribute("aria-activedescendant", item ? item.id : "")
            }
            if (item) {
              item.scrollIntoView({ block: "nearest" })
            }
          }

          this._onInput = (event) => {
            if (event.target.matches("[data-polaris-command-input]")) {
              this._filter()
              this._syncReset()
            }
          }
          root.addEventListener("input", this._onInput)

          // Hover highlights, like cmdk's pointermove tracking.
          this._onPointerMove = (event) => {
            const item = event.target.closest("[data-polaris-command-item]")
            if (item && root.contains(item) && item !== this._active) {
              if (item.hasAttribute("hidden") || item.dataset.disabled === "true") return
              this._setActive(item)
            }
          }
          root.addEventListener("pointermove", this._onPointerMove)

          this._onKeydown = (event) => {
            const input = this._input()
            if (!input || event.target !== input) {
              return
            }
            const items = this._items()
            if (event.key === "ArrowDown") {
              event.preventDefault()
              const index = items.indexOf(this._active)
              this._setActive(items[(index + 1) % items.length] || items[0] || null)
            } else if (event.key === "ArrowUp") {
              event.preventDefault()
              const index = items.indexOf(this._active)
              this._setActive(items[(index - 1 + items.length) % items.length] || items[0] || null)
            } else if (event.key === "Home") {
              event.preventDefault()
              this._setActive(items[0] || null)
            } else if (event.key === "End") {
              event.preventDefault()
              this._setActive(items[items.length - 1] || null)
            } else if (event.key === "Enter") {
              const item = this._active || items[0]
              if (item) {
                event.preventDefault()
                item.click()
              }
            }
          }
          root.addEventListener("keydown", this._onKeydown)

          this._onClick = (event) => {
            // The reset ✕ clears the query client-side (the source's
            // handleReset); item clicks fall through to their own bindings.
            if (event.target.closest("[data-polaris-command-reset]")) {
              event.preventDefault()
              const input = this._input()
              if (input) {
                input.value = ""
                input.focus()
              }
              this._filter()
              this._syncReset()
            }
          }
          root.addEventListener("click", this._onClick)

          this._syncReset = () => {
            const input = this._input()
            const reset = root.querySelector("[data-polaris-command-reset]")
            if (reset && input) {
              reset.disabled = input.disabled || input.value.length === 0
              reset.tabIndex = reset.disabled ? -1 : 0
              if (input.value.length > 0) {
                reset.classList.add("opacity-100")
              } else {
                reset.classList.remove("opacity-100")
              }
            }
          }

          this._filter()
          this._syncReset()
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("input", this._onInput)
          this.el.removeEventListener("pointermove", this._onPointerMove)
          this.el.removeEventListener("keydown", this._onKeydown)
          this.el.removeEventListener("click", this._onClick)
        }
      }
    </script>
    """
  end

  @doc """
  The command input: the search row under the list's top edge — the
  source's CommandInput (bordered wrapper, magnifier glyph, transparent
  field, optional ✕ reset).
  """
  attr(:placeholder, :string,
    default: "Type a command or search...",
    doc: "Field placeholder — name the domain (\"Search framework...\")."
  )

  attr(:disabled, :boolean, default: false, doc: "Disables the field (dims and blocks typing).")

  attr(:show_search_icon, :boolean,
    default: true,
    doc: "Render the leading magnifier glyph (the source's `showSearchIcon`)."
  )

  attr(:show_reset_icon, :boolean,
    default: false,
    doc: """
    Render the trailing ✕ that clears the query client-side (the
    source's `showResetIcon`).
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<input>`.")

  attr(:wrapper_class, :string,
    default: nil,
    doc: "Additional classes merged onto the search row wrapper."
  )

  attr(:rest, :global, doc: "Forwarded to the `<input>`: `id`, `aria-label`, `phx-*`, …")

  slot(:inner_block, doc: "Ignored — present for slot-API symmetry.")

  def command_input(assigns) do
    ~H"""
    <div
      data-polaris-command-input-wrapper
      class={cn(["flex items-center border-b border-surface-border px-4", @wrapper_class])}
    >
      <svg
        :if={@show_search_icon}
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="size-4 shrink-0 opacity-50"
        aria-hidden="true"
      >
        <circle cx="11" cy="11" r="8" />
        <path d="m21 21-4.3-4.3" />
      </svg>
      <input
        type="text"
        data-polaris-command-input
        placeholder={@placeholder}
        autocomplete="off"
        spellcheck="false"
        role="combobox"
        aria-expanded="true"
        aria-autocomplete="list"
        disabled={@disabled}
        class={
          cn([
            "flex h-9 w-full rounded-md bg-transparent py-3 text-sm outline-none",
            "placeholder:text-content-muted border-none",
            "disabled:cursor-not-allowed disabled:opacity-50",
            @class
          ])
        }
        {@rest}
      />
      <button
        :if={@show_reset_icon}
        type="button"
        data-polaris-command-reset
        tabindex="-1"
        disabled
        aria-label="Clear search"
        class="cursor-pointer text-content-secondary transition-all duration-100 opacity-0 hover:text-content-primary"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-3.5"
          aria-hidden="true"
        >
          <path d="M18 6 6 18" />
          <path d="m6 6 12 12" />
        </svg>
      </button>
    </div>
    """
  end

  @doc """
  The command list: the scroll container for groups and items — the
  source's CommandList (`max-h-full overflow-y-auto overflow-x-hidden`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the list.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `aria-label`, `data-*`, …")

  slot(:inner_block, doc: "Groups, items, separators, the empty state.")

  def command_list(assigns) do
    ~H"""
    <div
      data-polaris-command-list
      role="listbox"
      class={cn(["max-h-full overflow-y-auto overflow-x-hidden", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The command empty state: shown by the hook when the query matches
  nothing — the source's CommandEmpty (`py-6 text-center text-xs`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the empty state.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "Miss microcopy — \"No results found.\"")

  def command_empty(assigns) do
    ~H"""
    <div
      data-polaris-command-empty
      role="presentation"
      hidden
      class={cn(["py-6 text-center text-xs text-content-muted", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The command group: a labelled cluster of items — the source's
  CommandGroup. The heading renders as the signature Supabase mono
  microcopy: `font-mono uppercase tracking-wider text-xs`.
  """
  attr(:heading, :string,
    default: nil,
    doc: "Group label — short and plural (\"Suggestions\", \"Settings\")."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")

  attr(:heading_class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the heading — the Command Menu
    overrides the mono microcopy with its own rhythm.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The group's items.")

  def command_group(assigns) do
    ~H"""
    <div
      data-polaris-command-group
      role="group"
      aria-label={@heading}
      class={cn(["overflow-hidden p-1 text-content-primary", @class])}
      {@rest}
    >
      <div
        :if={@heading}
        data-polaris-command-group-heading
        class={
          cn([
            "px-2 py-1.5 text-xs font-normal font-mono uppercase tracking-wider text-content-muted",
            @heading_class
          ])
        }
      >
        {@heading}
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The command item: one action — the source's CommandItem. `value` is
  the filter target; `keywords` adds alternate phrasings (the cmdk
  pattern, e.g. `[\"dark mode\", \"theme\"]`); the `shortcut` slot
  right-aligns a ⌘-string. Activation goes through `phx-click` (via
  `rest`), fired by both pointer clicks and Enter.
  """
  attr(:value, :string,
    required: true,
    doc: "Filter target for this item — pack search phrasings in, the cmdk value pattern."
  )

  attr(:keywords, :list,
    default: [],
    doc: "Alternate filter phrasings joined onto the value (list of strings)."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Dims the item, blocks activation, and drops it from keyboard navigation."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:shortcut, doc: "Right-aligned ⌘-string (\"⌘P\") — or use the standalone `command_shortcut`.")

  slot(:inner_block, doc: "The item label.")

  def command_item(assigns) do
    assigns =
      assign(assigns,
        keywords:
          assigns.keywords
          |> Enum.map(&to_string/1)
          |> Enum.join(",")
      )

    ~H"""
    <div
      data-polaris-command-item
      data-value={@value}
      data-keywords={@keywords}
      data-disabled={to_string(@disabled)}
      data-selected="false"
      aria-selected="false"
      aria-disabled={to_string(@disabled)}
      role="option"
      tabindex="-1"
      class={
        cn([
          "relative flex cursor-default select-none items-center rounded-xs px-2 py-1.5 text-xs outline-none",
          "data-[selected=true]:bg-surface-panel-hover",
          "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
      <span :if={@shortcut != []} class="ml-auto pl-4">
        {render_slot(@shortcut)}
      </span>
    </div>
    """
  end

  @doc """
  The command separator: the hairline between groups — the source's
  CommandSeparator (`-mx-1 h-px bg-border-overlay`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the separator.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  def command_separator(assigns) do
    ~H"""
    <div
      data-polaris-command-separator
      class={cn(["-mx-1 h-px bg-surface-border", @class])}
      {@rest}
    />
    """
  end

  @doc """
  The command shortcut: the right-aligned ⌘-string — the source's
  CommandShortcut (`ml-auto text-xs tracking-widest`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the shortcut.")

  attr(:rest, :global, doc: "Forwarded to the `<span>`: `data-*`, …")

  slot(:inner_block, doc: "The shortcut glyphs (\"⌘P\").")

  def command_shortcut(assigns) do
    ~H"""
    <span
      data-polaris-command-shortcut
      class={cn(["ml-auto text-xs tracking-widest text-content-muted", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end
end
