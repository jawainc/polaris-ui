defmodule PolarisUI.Components.ContextMenu do
  @moduledoc """
  The Polaris context menu: a right-click menu of actions anchored to
  the cursor — the port of the Supabase design system Context Menu
  (`packages/ui`, built on the Radix ContextMenu primitive).

  ## Client-side visibility, server-side actions

  Unlike the popover and dialog (whose visibility is server-driven so
  forms inside them can round-trip), a context menu opens at the cursor
  with zero latency, so the colocated hook owns open/close entirely:
  `contextmenu` (right-click) opens, Escape / click-outside / item
  activation closes. Item activation itself rides each item's own
  `phx-click`, exactly like the source's `onSelect`.

  ## Anatomy

      <.context_menu id="row-menu">
        <:trigger>
          <div class="flex h-[150px] w-[300px] items-center justify-center rounded-md border border-dashed border-surface-border text-sm">
            Right click here
          </div>
        </:trigger>
        <.context_menu_item phx-click="open-profile">Profile</.context_menu_item>
        <.context_menu_item phx-click="open-billing">
          Billing
          <.context_menu_shortcut>⌘B</.context_menu_shortcut>
        </.context_menu_item>
        <.context_menu_separator />
        <.context_menu_label>Team</.context_menu_label>
        <.context_menu_checkbox_item checked={@show_hidden} phx-click="toggle-hidden">
          Show hidden files
        </.context_menu_checkbox_item>
        <.context_menu_sub>
          <.context_menu_sub_trigger>Invite members</.context_menu_sub_trigger>
          <.context_menu_sub_content>
            <.context_menu_item phx-click="invite-email">Invite by email</.context_menu_item>
            <.context_menu_item phx-click="invite-link">Copy invite link</.context_menu_item>
          </.context_menu_sub_content>
        </.context_menu_sub>
        <.context_menu_separator />
        <.context_menu_item phx-click="delete-row" class="text-danger">Delete row</.context_menu_item>
      </.context_menu>

    * **trigger slot** — the area that reacts to right-click; any
      markup.
    * **menu** — the `role="menu"` panel (`z-50 min-w-32 rounded-md
      border bg-surface-panel p-1 shadow-md`), always in the DOM
      (`hidden` until opened), positioned at the cursor by the hook and
      clamped to the viewport.
    * **items** — `context_menu_item` (plain action),
      `context_menu_checkbox_item` / `context_menu_radio_item`
      (server-driven `checked`, like the Radix controlled props),
      grouped under `context_menu_label`, split by
      `context_menu_separator`, with `context_menu_shortcut` glyphs
      right-aligned. `inset` indents an item to line up under labels.
    * **submenus** — `context_menu_sub` + `context_menu_sub_trigger` +
      `context_menu_sub_content`; the hook opens them on hover and
      **ArrowRight**, closing on **ArrowLeft** / mouse-out.

  ## Keyboard

  Opening focuses the first item; **ArrowDown** / **ArrowUp** cycle
  items (wrapping), **Home** / **End** bound the list, **Enter** /
  **Space** activate the focused item (dispatching its own click, so
  `phx-click` fires identically for pointer and keyboard), and
  **Escape** closes — submenu first, then the menu. Highlight rides
  real DOM focus (the Radix model), so the shared emerald-selection
  `focus:` styles light items up for both pointer and keys.

  ## Microcopy

  Per the Supabase copywriting guidelines: items use direct verbs
  ("Delete row", "Copy invite link", "Revoke access") — never "Submit"
  or "OK" — and shortcuts state the real binding.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  # The shared item treatment (the source's ContextMenuItem classes) — a
  # helper since HEEx resolves @-references to assigns, not attributes.
  defp item_base_classes do
    [
      "relative flex cursor-pointer select-none items-center rounded-xs px-2 py-1.5 text-xs outline-none",
      "focus:bg-brand-emerald-muted focus:text-content-primary focus:outline-none",
      "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    ]
  end

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the context menu root — required because the colocated
    hook that manages opening, positioning, and keyboard navigation
    anchors on it.
    """
  )

  attr(:menu_class, :string,
    default: nil,
    doc: "Additional classes merged onto the menu panel."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root wrapper.")

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  slot(:trigger,
    required: true,
    doc: "The area that reacts to right-click — any markup."
  )

  slot(:inner_block, doc: "The menu content: items, labels, separators, submenus.")

  def context_menu(assigns) do
    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        menu_classes:
          cn([
            "fixed z-50 min-w-32 overflow-hidden rounded-md border border-surface-border",
            "bg-surface-panel p-1 text-content-primary shadow-md outline-none",
            assigns.menu_class
          ])
      )

    ~H"""
    <div
      id={@id}
      class={cn(["relative inline-flex max-w-full", @class])}
      data-polaris-context-menu
      data-state="closed"
      phx-hook={@hook}
      {@rest}
    >
      <div data-polaris-context-menu-trigger class="contents">
        {render_slot(@trigger)}
      </div>
      <div data-polaris-context-menu-content role="menu" hidden class={@menu_classes}>
        {render_slot(@inner_block)}
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          const content = () => root.querySelector("[data-polaris-context-menu-content]")
          this._open = false

          this._close = () => {
            // Submenus reset whenever the menu closes.
            root.querySelectorAll("[data-polaris-context-menu-sub]").forEach((sub) => {
              this._closeSub(sub)
            })
            const c = content()
            if (c) {
              c.setAttribute("hidden", "")
              c.setAttribute("data-state", "closed")
            }
            root.dataset.state = "closed"
            this._open = false
            if (this._previouslyFocused && typeof this._previouslyFocused.focus === "function") {
              this._previouslyFocused.focus()
            }
            this._previouslyFocused = null
          }

          this._show = (x, y) => {
            const c = content()
            if (!c) return
            this._previouslyFocused = document.activeElement
            c.removeAttribute("hidden")
            c.setAttribute("data-state", "open")
            // Clamp to the viewport, like Radix's collision handling.
            c.style.left = Math.min(x, window.innerWidth - c.offsetWidth - 8) + "px"
            c.style.top = Math.min(y, window.innerHeight - c.offsetHeight - 8) + "px"
            root.dataset.state = "open"
            this._open = true
            this._focusItem(this._items()[0])
          }

          this._items = (scope) =>
            Array.from(
              (scope || content()).querySelectorAll(
                "[data-polaris-context-menu-item], [data-polaris-context-menu-sub-trigger]"
              )
            ).filter((el) => el.dataset.disabled !== "true")

          this._focusItem = (item) => {
            if (item) item.focus()
          }

          this._openSub = (sub) => {
            const sc = sub.querySelector("[data-polaris-context-menu-sub-content]")
            const trigger = sub.querySelector("[data-polaris-context-menu-sub-trigger]")
            root.querySelectorAll("[data-polaris-context-menu-sub]").forEach((other) => {
              if (other !== sub && !sub.contains(other)) this._closeSub(other)
            })
            if (sc) {
              sc.removeAttribute("hidden")
              sc.setAttribute("data-state", "open")
            }
            if (trigger) trigger.setAttribute("data-state", "open")
          }

          this._closeSub = (sub) => {
            const sc = sub ? sub.querySelector("[data-polaris-context-menu-sub-content]") : null
            const trigger = sub ? sub.querySelector("[data-polaris-context-menu-sub-trigger]") : null
            if (sc) {
              sc.setAttribute("hidden", "")
              sc.setAttribute("data-state", "closed")
            }
            if (trigger) trigger.setAttribute("data-state", "closed")
          }

          this._subOf = (el) => el.closest("[data-polaris-context-menu-sub]")

          this._onContextMenu = (event) => {
            event.preventDefault()
            this._show(event.clientX, event.clientY)
          }
          root.addEventListener("contextmenu", this._onContextMenu)

          this._onClick = (event) => {
            if (!this._open) return
            // Any item activation closes the menu (Radix's onSelect);
            // clicks fall through to the item's own phx-click binding.
            const item = event.target.closest(
              "[data-polaris-context-menu-item], [data-polaris-context-menu-checkbox-item], [data-polaris-context-menu-radio-item]"
            )
            if (item && item.dataset.disabled === "true") {
              event.preventDefault()
              return
            }
            if (item || !content().contains(event.target)) {
              this._close()
            }
          }
          document.addEventListener("click", this._onClick, true)

          this._onDocumentClick = (event) => {
            if (this._open && !root.contains(event.target)) {
              this._close()
            }
          }
          document.addEventListener("click", this._onDocumentClick)

          this._onKeydown = (event) => {
            if (!this._open) return
            const items = this._items()
            const focused = document.activeElement
            const isItem = (el) =>
              el && content().contains(el) && el.matches(
                "[data-polaris-context-menu-item], [data-polaris-context-menu-sub-trigger]"
              )
            const activeSub = focused ? this._subOf(focused) : null
            if (event.key === "Escape") {
              event.preventDefault()
              const openSub = root.querySelector("[data-polaris-context-menu-sub-content]:not([hidden])")
              if (openSub) {
                const sub = this._subOf(openSub)
                const trigger = sub && sub.querySelector("[data-polaris-context-menu-sub-trigger]")
                this._closeSub(sub)
                if (trigger) trigger.focus()
              } else {
                this._close()
              }
            } else if (event.key === "ArrowDown" && isItem(focused)) {
              event.preventDefault()
              const index = items.indexOf(focused)
              this._focusItem(items[(index + 1) % items.length] || items[0])
            } else if (event.key === "ArrowUp" && isItem(focused)) {
              event.preventDefault()
              const index = items.indexOf(focused)
              this._focusItem(items[(index - 1 + items.length) % items.length] || items[0])
            } else if (event.key === "Home" && isItem(focused)) {
              event.preventDefault()
              this._focusItem(items[0])
            } else if (event.key === "End" && isItem(focused)) {
              event.preventDefault()
              this._focusItem(items[items.length - 1])
            } else if (event.key === "ArrowRight" && focused && focused.matches("[data-polaris-context-menu-sub-trigger]")) {
              event.preventDefault()
              const sub = this._subOf(focused)
              this._openSub(sub)
              const subItems = this._items(sub)
              this._focusItem(subItems[0])
            } else if (event.key === "ArrowLeft" && activeSub) {
              event.preventDefault()
              const trigger = activeSub.querySelector("[data-polaris-context-menu-sub-trigger]")
              this._closeSub(activeSub)
              if (trigger) trigger.focus()
            } else if ((event.key === "Enter" || event.key === " ") && isItem(focused)) {
              event.preventDefault()
              focused.click()
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)

          // Hover highlights via real focus, the Radix pointermove model.
          this._onPointerMove = (event) => {
            if (!this._open) return
            const item = event.target.closest(
              "[data-polaris-context-menu-item], [data-polaris-context-menu-sub-trigger]"
            )
            if (item && root.contains(item) && item.dataset.disabled !== "true" && item !== document.activeElement) {
              item.focus()
            }
            const subTrigger = event.target.closest("[data-polaris-context-menu-sub-trigger]")
            if (subTrigger) this._openSub(this._subOf(subTrigger))
            const subLeft = event.target.closest("[data-polaris-context-menu-sub-content]")
            if (!subTrigger && !subLeft) {
              root.querySelectorAll("[data-polaris-context-menu-sub]").forEach((sub) => {
                if (!sub.contains(event.target)) this._closeSub(sub)
              })
            }
          }
          document.addEventListener("pointermove", this._onPointerMove)
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("contextmenu", this._onContextMenu)
          document.removeEventListener("click", this._onClick, true)
          document.removeEventListener("click", this._onDocumentClick)
          document.removeEventListener("keydown", this._onKeydown, true)
          document.removeEventListener("pointermove", this._onPointerMove)
        }
      }
    </script>
    """
  end

  @doc """
  The context menu item: a plain action — the source's ContextMenuItem.
  Activation goes through `phx-click` (via `rest`), fired by both
  pointer clicks and Enter. `inset` indents to line up under a label.
  """
  attr(:disabled, :boolean, default: false, doc: "Dims the item and blocks activation.")

  attr(:inset, :boolean,
    default: false,
    doc: "Indent the item (`pl-8`) to align under an inset label."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:inner_block, doc: "The item label — a direct verb (\"Delete row\").")

  def context_menu_item(assigns) do
    ~H"""
    <div
      data-polaris-context-menu-item
      data-disabled={to_string(@disabled)}
      role="menuitem"
      aria-disabled={to_string(@disabled)}
      tabindex="-1"
      class={cn(item_base_classes() ++ [if(@inset, do: "pl-8"), @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The context menu label: a non-interactive group caption — the
  source's ContextMenuLabel (`px-2 py-1.5 text-xs`).
  """
  attr(:inset, :boolean, default: false, doc: "Indent the label (`pl-8`).")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the label.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The caption — short and plural (\"Team\").")

  def context_menu_label(assigns) do
    ~H"""
    <div
      data-polaris-context-menu-label
      class={cn(["px-2 py-1.5 text-xs text-content-primary", if(@inset, do: "pl-8"), @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The context menu separator: the hairline between groups — the
  source's ContextMenuSeparator (`-mx-1 my-1 h-px bg-border`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the separator.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  def context_menu_separator(assigns) do
    ~H"""
    <div
      data-polaris-context-menu-separator
      role="separator"
      class={cn(["-mx-1 my-1 h-px bg-surface-border", @class])}
      {@rest}
    />
    """
  end

  @doc """
  The context menu shortcut: the right-aligned ⌘-string inside an
  item — the source's ContextMenuShortcut
  (`ml-auto text-xs tracking-widest`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the shortcut.")
  attr(:rest, :global, doc: "Forwarded to the `<span>`: `data-*`, …")

  slot(:inner_block, doc: "The shortcut glyphs (\"⌘B\").")

  def context_menu_shortcut(assigns) do
    ~H"""
    <span
      data-polaris-context-menu-shortcut
      class={cn(["ml-auto text-xs tracking-widest text-content-muted", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  The context menu checkbox item: a toggleable action with a leading
  check indicator — the source's ContextMenuCheckboxItem. `checked` is
  server-driven (the Radix controlled `checked` prop); flip it in the
  `phx-click` handler.
  """
  attr(:checked, :boolean, default: false, doc: "Server-driven check state.")
  attr(:disabled, :boolean, default: false, doc: "Dims the item and blocks activation.")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:inner_block, doc: "The item label — state the toggle (\"Show hidden files\").")

  def context_menu_checkbox_item(assigns) do
    ~H"""
    <div
      data-polaris-context-menu-checkbox-item
      data-disabled={to_string(@disabled)}
      role="menuitemcheckbox"
      aria-checked={to_string(@checked)}
      aria-disabled={to_string(@disabled)}
      tabindex="-1"
      class={
        cn([
          "relative flex cursor-pointer select-none items-center rounded-xs py-1.5 pl-8 pr-2 text-xs outline-none",
          "focus:bg-brand-emerald-muted focus:text-content-primary focus:outline-none",
          "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50",
          @class
        ])
      }
      {@rest}
    >
      <span class="absolute left-2 flex h-3.5 w-3.5 items-center justify-center" aria-hidden="true">
        <svg
          :if={@checked}
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="3"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-4"
        >
          <path d="M20 6 9 17l-5-5" />
        </svg>
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The context menu radio item: one choice in a mutually exclusive set —
  the source's ContextMenuRadioItem, with the dot indicator. `checked`
  is server-driven; group siblings under `context_menu_group`.
  """
  attr(:checked, :boolean, default: false, doc: "Server-driven selection state.")
  attr(:disabled, :boolean, default: false, doc: "Dims the item and blocks activation.")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:inner_block, doc: "The choice label.")

  def context_menu_radio_item(assigns) do
    ~H"""
    <div
      data-polaris-context-menu-radio-item
      data-disabled={to_string(@disabled)}
      role="menuitemradio"
      aria-checked={to_string(@checked)}
      aria-disabled={to_string(@disabled)}
      tabindex="-1"
      class={
        cn([
          "relative flex cursor-pointer select-none items-center rounded-xs py-1.5 pl-8 pr-2 text-xs outline-none",
          "focus:bg-brand-emerald-muted focus:text-content-primary focus:outline-none",
          "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50",
          @class
        ])
      }
      {@rest}
    >
      <span class="absolute left-2 flex h-3.5 w-3.5 items-center justify-center" aria-hidden="true">
        <span :if={@checked} class="size-2 rounded-full bg-current" />
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The context menu group: a semantics-only wrapper for a related item
  cluster (e.g. a radio set) — the source's ContextMenuGroup.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The group's items.")

  def context_menu_group(assigns) do
    ~H"""
    <div data-polaris-context-menu-group role="group" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The context menu submenu wrapper: groups a sub trigger with its
  nested content — the source's ContextMenuSub.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the wrapper.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The `context_menu_sub_trigger` and `context_menu_sub_content`.")

  def context_menu_sub(assigns) do
    ~H"""
    <div data-polaris-context-menu-sub class={cn(["relative", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The context menu sub trigger: the item that opens a nested menu on
  hover or **ArrowRight** — the source's ContextMenuSubTrigger, with
  the auto-appended right chevron.
  """
  attr(:disabled, :boolean, default: false, doc: "Dims the trigger and blocks opening.")
  attr(:inset, :boolean, default: false, doc: "Indent the trigger (`pl-8`).")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the trigger.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, doc: "The trigger label.")

  def context_menu_sub_trigger(assigns) do
    ~H"""
    <div
      data-polaris-context-menu-sub-trigger
      data-disabled={to_string(@disabled)}
      data-state="closed"
      role="menuitem"
      aria-haspopup="menu"
      aria-disabled={to_string(@disabled)}
      tabindex="-1"
      class={
        cn(
          item_base_classes() ++
            [
              "data-[state=open]:bg-brand-emerald-muted data-[state=open]:text-content-primary",
              if(@inset, do: "pl-8"),
              @class
            ]
        )
      }
      {@rest}
    >
      {render_slot(@inner_block)}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="ml-auto h-4 w-4"
        aria-hidden="true"
      >
        <path d="m9 18 6-6-6-6" />
      </svg>
    </div>
    """
  end

  @doc """
  The context menu sub content: the nested menu panel — the source's
  ContextMenuSubContent, floated beside its trigger and opened by the
  hook on hover or **ArrowRight**.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the sub panel.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The nested items.")

  def context_menu_sub_content(assigns) do
    ~H"""
    <div
      data-polaris-context-menu-sub-content
      data-state="closed"
      role="menu"
      hidden
      class={
        cn([
          "absolute left-full top-0 z-50 ml-1 min-w-32 overflow-hidden rounded-md border border-surface-border",
          "bg-surface-panel p-1 text-content-primary shadow-md outline-none",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
