defmodule PolarisUI.Components.DropdownMenu do
  @moduledoc """
  The Polaris dropdown menu: a menu of actions anchored to a trigger
  button — the port of the Supabase design system Dropdown Menu
  (`packages/ui`, built on the Radix DropdownMenu primitive).

  ## Client-side visibility, server-side actions

  Like the context menu, a dropdown opens with zero latency, so the
  colocated hook owns open/close entirely: trigger click toggles,
  Escape / click-outside / item activation closes. Item activation
  itself rides each item's own `phx-click`, exactly like the source's
  `onSelect`. The source forces `modal={false}` (the Radix default is
  modal) — the menu is non-modal: the page stays interactive and focus
  is never trapped, only moved into the menu while open.

  ## Anatomy

      <.dropdown_menu id="account-menu">
        <:trigger>
          <.button variant="default">Open</.button>
        </:trigger>
        <.dropdown_menu_label>My account</.dropdown_menu_label>
        <.dropdown_menu_separator />
        <.dropdown_menu_item phx-click="open-profile">
          Profile
          <.dropdown_menu_shortcut>⇧⌘P</.dropdown_menu_shortcut>
        </.dropdown_menu_item>
        <.dropdown_menu_item phx-click="open-billing">Billing</.dropdown_menu_item>
        <.dropdown_menu_separator />
        <.dropdown_menu_checkbox_item checked={@show_status_bar} phx-click="toggle-status-bar">
          Status bar
        </.dropdown_menu_checkbox_item>
        <.dropdown_menu_sub>
          <.dropdown_menu_sub_trigger>Invite users</.dropdown_menu_sub_trigger>
          <.dropdown_menu_sub_content>
            <.dropdown_menu_item phx-click="invite-email">Invite by email</.dropdown_menu_item>
          </.dropdown_menu_sub_content>
        </.dropdown_menu_sub>
        <.dropdown_menu_separator />
        <.dropdown_menu_item phx-click="log-out" class="text-danger">Log out</.dropdown_menu_item>
      </.dropdown_menu>

    * **trigger slot** — the button that toggles the menu; any markup
      (the source's `DropdownMenuTrigger asChild`). The hook syncs
      `aria-haspopup="menu"` and `aria-expanded` onto its first
      focusable element.
    * **menu** — the `role="menu"` panel (`z-50 min-w-32 w-64
      rounded-md border bg-surface-panel p-1 shadow-md`), always in the
      DOM (`hidden` until opened), positioned beside the trigger by the
      hook.
    * **items** — `dropdown_menu_item` (plain action),
      `dropdown_menu_checkbox_item` / `dropdown_menu_radio_item`
      (server-driven `checked`, like the Radix controlled props), under
      `dropdown_menu_label` captions, split by
      `dropdown_menu_separator`, with `dropdown_menu_shortcut` glyphs
      right-aligned. `inset` indents an item to line up under labels.
    * **submenus** — `dropdown_menu_sub` + `dropdown_menu_sub_trigger`
      (auto-appended chevron) + `dropdown_menu_sub_content`; the hook
      opens them on hover and **ArrowRight**, closing on **ArrowLeft**
      / mouse-out.

  ## Positioning

  `side` (`top`/`right`/`bottom`/`left`, default `bottom`) picks the
  edge of the trigger, `align` (`start`/`center`/`end`) the cross-axis
  position, and `side_offset` (the source sets Radix's 4px default)
  the gap. The hook measures the trigger and positions the panel,
  flipping to the opposite side when the viewport runs out of room
  (the Radix collision behavior, simplified). `same_width` pins the
  panel to the trigger's width for select-style menus.

  ## Keyboard

  Trigger focus + **ArrowDown**/**ArrowUp** opens the menu (moving to
  the first/last item); opening focuses the first item; arrows cycle,
  **Home**/**End** bound the list, **Enter**/**Space** activate the
  focused item (dispatching its own click, so `phx-click` fires
  identically for pointer and keyboard), typing jumps to matching
  items (typeahead), and **Escape** closes — submenu first, then the
  menu. On close, focus returns to the trigger (the Radix
  `onCloseAutoFocus` default). Highlight rides real DOM focus, so the
  shared selection `focus:` styles light items for both pointer and
  keys.

  ## Microcopy

  Per the Supabase copywriting guidelines: items use direct verbs
  ("Delete project", "Revoke access", "Copy invite link") — never
  "Submit" or "OK" — and shortcuts state the real binding.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @sides ~w(top right bottom left)
  @alignments ~w(start center end)

  # The shared item treatment (the source's DropdownMenuItem classes) —
  # a helper since HEEx resolves @-references to assigns, not attributes.
  defp item_base_classes do
    [
      "relative flex cursor-pointer select-none items-center rounded-xs px-2 py-1.5 text-xs outline-none",
      "transition-colors focus:bg-brand-emerald-muted focus:text-content-primary focus:outline-none",
      "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    ]
  end

  # The checkbox/radio treatment (pl-8 room for the indicator).
  defp indicator_item_classes do
    [
      "relative flex cursor-pointer select-none items-center rounded-xs py-1.5 pl-8 pr-2 text-xs outline-none",
      "transition-colors focus:bg-brand-emerald-muted focus:text-content-primary focus:outline-none",
      "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    ]
  end

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the dropdown menu root — required because the
    colocated hook that manages opening, positioning, and keyboard
    navigation anchors on it.
    """
  )

  attr(:side, :string,
    values: @sides,
    default: "bottom",
    doc: "Edge of the trigger the menu anchors to. The hook flips it when the viewport runs out."
  )

  attr(:align, :string,
    values: @alignments,
    default: "center",
    doc: "Cross-axis position of the menu relative to the trigger."
  )

  attr(:side_offset, :integer,
    default: 4,
    doc: "Gap between trigger and menu in pixels — the source pins Radix's `sideOffset` default."
  )

  attr(:same_width, :boolean,
    default: false,
    doc: "Pin the menu to the trigger's width (select-style menus)."
  )

  attr(:menu_class, :string,
    default: nil,
    doc: "Additional classes merged onto the menu panel — e.g. `w-56`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root wrapper.")

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  slot(:trigger,
    required: true,
    doc: "The button that toggles the menu — any markup."
  )

  slot(:inner_block, doc: "The menu content: items, labels, separators, submenus.")

  def dropdown_menu(assigns) do
    validate_in!(:side, assigns.side, @sides)
    validate_in!(:align, assigns.align, @alignments)

    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        menu_classes:
          cn([
            "fixed z-50 min-w-32 w-64 overflow-hidden rounded-md border border-surface-border",
            "bg-surface-panel p-1 text-content-primary shadow-md outline-none",
            assigns.menu_class
          ])
      )

    ~H"""
    <div
      id={@id}
      class={cn(["relative inline-flex max-w-full", @class])}
      data-polaris-dropdown-menu
      data-state="closed"
      data-side={@side}
      data-align={@align}
      data-side-offset={to_string(@side_offset)}
      data-same-width={to_string(@same_width)}
      phx-hook={@hook}
      {@rest}
    >
      <span data-polaris-dropdown-menu-trigger class="inline-flex max-w-full">
        {render_slot(@trigger)}
      </span>
      <div data-polaris-dropdown-menu-content role="menu" hidden class={@menu_classes}>
        {render_slot(@inner_block)}
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          const content = () => root.querySelector("[data-polaris-dropdown-menu-content]")
          const triggerWrap = () => root.querySelector("[data-polaris-dropdown-menu-trigger]")
          this._open = false
          this._typeahead = ""
          this._typeaheadAt = 0

          // The trigger's first focusable carries the Radix aria contract.
          this._triggerButton = () => {
            const wrap = triggerWrap()
            if (!wrap) return null
            return (
              wrap.querySelector("button, [href], input, [tabindex]:not([tabindex='-1'])") ||
              wrap.firstElementChild
            )
          }

          this._syncTriggerAria = () => {
            const button = this._triggerButton()
            if (!button || typeof button.setAttribute !== "function") return
            button.setAttribute("aria-haspopup", "menu")
            button.setAttribute("aria-expanded", this._open ? "true" : "false")
          }

          this._close = () => {
            // Submenus reset whenever the menu closes.
            root.querySelectorAll("[data-polaris-dropdown-menu-sub]").forEach((sub) => {
              this._closeSub(sub)
            })
            const c = content()
            if (c) {
              c.setAttribute("hidden", "")
              c.setAttribute("data-state", "closed")
            }
            root.dataset.state = "closed"
            this._open = false
            this._syncTriggerAria()
            const button = this._triggerButton()
            if (this._previouslyFocused && typeof this._previouslyFocused.focus === "function") {
              this._previouslyFocused.focus()
            } else if (button && typeof button.focus === "function") {
              button.focus()
            }
            this._previouslyFocused = null
          }

          this._show = () => {
            const c = content()
            if (!c) return
            this._previouslyFocused = document.activeElement
            c.removeAttribute("hidden")
            c.setAttribute("data-state", "open")
            root.dataset.state = "open"
            this._open = true
            this._syncTriggerAria()
            this._position()
            this._animateIn(c)
            this._focusItem(this._items()[0])
          }

          // Fixed positioning measured from the trigger's viewport rect —
          // side/align/offset with a viewport flip, like Radix.
          this._position = () => {
            const c = content()
            const wrap = triggerWrap()
            if (!c || !wrap) return
            const side = root.dataset.side || "bottom"
            const align = root.dataset.align || "center"
            const offset = parseInt(root.dataset.sideOffset || "4", 10)
            if (root.dataset.sameWidth === "true") {
              c.style.minWidth = wrap.offsetWidth + "px"
            }
            const rect = wrap.getBoundingClientRect()
            const place = (side) => {
              c.style.top = ""
              c.style.bottom = ""
              c.style.left = ""
              c.style.right = ""
              if (side === "bottom") {
                c.style.top = rect.bottom + offset + "px"
              } else if (side === "top") {
                c.style.bottom = window.innerHeight - rect.top + offset + "px"
              } else if (side === "right") {
                c.style.left = rect.right + offset + "px"
              } else {
                c.style.right = window.innerWidth - rect.left + offset + "px"
              }
              if (side === "bottom" || side === "top") {
                if (align === "start") {
                  c.style.left = rect.left + "px"
                } else if (align === "end") {
                  c.style.left = rect.right - c.offsetWidth + "px"
                } else {
                  c.style.left = rect.left + rect.width / 2 + "px"
                  c.style.transform = "translateX(-50%)"
                }
              } else {
                if (align === "start") {
                  c.style.top = rect.top + "px"
                } else if (align === "end") {
                  c.style.top = rect.bottom - c.offsetHeight + "px"
                } else {
                  c.style.top = rect.top + rect.height / 2 + "px"
                  c.style.transform = "translateY(-50%)"
                }
              }
            }
            place(side)
            // Flip when the panel spills past the viewport (the Radix
            // collision behavior, simplified).
            const box = c.getBoundingClientRect()
            const spills = side === "bottom"
              ? box.bottom > window.innerHeight
              : side === "top"
                ? box.top < 0
                : side === "right"
                  ? box.right > window.innerWidth
                  : box.left < 0
            if (spills) {
              const flipped = { bottom: "top", top: "bottom", right: "left", left: "right" }[side]
              place(flipped)
            }
          }

          this._animateIn = (c) => {
            if (typeof c.animate !== "function") return
            const side = root.dataset.side || "bottom"
            const slide = {
              bottom: "translateY(-0.5rem)",
              top: "translateY(0.5rem)",
              right: "translateX(-0.5rem)",
              left: "translateX(0.5rem)",
            }[side]
            const zoom = c.animate(
              [
                { opacity: 0, transform: `${slide} scale(0.95)` },
                { opacity: 1, transform: "none" },
              ],
              { duration: 150, easing: "ease-out" }
            )
            zoom.finished
              .then(() => {
                c.style.transform = ""
              })
              .catch(() => {})
          }

          this._items = (scope) =>
            Array.from(
              (scope || content()).querySelectorAll(
                "[data-polaris-dropdown-menu-item], [data-polaris-dropdown-menu-checkbox-item], [data-polaris-dropdown-menu-radio-item], [data-polaris-dropdown-menu-sub-trigger]"
              )
            ).filter((el) => el.dataset.disabled !== "true")

          this._focusItem = (item) => {
            if (item) item.focus()
          }

          this._openSub = (sub) => {
            const sc = sub.querySelector("[data-polaris-dropdown-menu-sub-content]")
            const trigger = sub.querySelector("[data-polaris-dropdown-menu-sub-trigger]")
            root.querySelectorAll("[data-polaris-dropdown-menu-sub]").forEach((other) => {
              if (other !== sub && !sub.contains(other)) this._closeSub(other)
            })
            if (sc) {
              sc.removeAttribute("hidden")
              sc.setAttribute("data-state", "open")
            }
            if (trigger) trigger.setAttribute("data-state", "open")
          }

          this._closeSub = (sub) => {
            const sc = sub ? sub.querySelector("[data-polaris-dropdown-menu-sub-content]") : null
            const trigger = sub ? sub.querySelector("[data-polaris-dropdown-menu-sub-trigger]") : null
            if (sc) {
              sc.setAttribute("hidden", "")
              sc.setAttribute("data-state", "closed")
            }
            if (trigger) trigger.setAttribute("data-state", "closed")
          }

          this._subOf = (el) => el.closest("[data-polaris-dropdown-menu-sub]")

          // Toggle on any click inside the trigger wrapper (delegated, so
          // LiveView morphs never orphan the listener).
          this._onClick = (event) => {
            const wrap = triggerWrap()
            if (wrap && wrap.contains(event.target)) {
              event.preventDefault()
              if (this._open) {
                this._close()
              } else {
                this._show()
              }
            }
          }
          root.addEventListener("click", this._onClick)

          this._onDocumentClick = (event) => {
            if (this._open && !root.contains(event.target)) {
              this._close()
            }
          }
          document.addEventListener("click", this._onDocumentClick)

          // Any item activation closes the menu (Radix's onSelect);
          // clicks fall through to the item's own phx-click binding.
          this._onItemActivate = (event) => {
            if (!this._open) return
            const item = event.target.closest(
              "[data-polaris-dropdown-menu-item], [data-polaris-dropdown-menu-checkbox-item], [data-polaris-dropdown-menu-radio-item]"
            )
            if (item && item.dataset.disabled === "true") {
              event.preventDefault()
              event.stopPropagation()
              return
            }
            if (item) {
              this._close()
            }
          }
          document.addEventListener("click", this._onItemActivate, true)

          this._onTriggerKeydown = (event) => {
            const button = this._triggerButton()
            if (this._open || !button || event.target !== button && !button.contains(event.target)) return
            if (event.key === "ArrowDown" || event.key === "ArrowUp") {
              event.preventDefault()
              this._show()
              const items = this._items()
              this._focusItem(event.key === "ArrowUp" ? items[items.length - 1] : items[0])
            }
          }
          root.addEventListener("keydown", this._onTriggerKeydown)

          this._onKeydown = (event) => {
            if (!this._open) return
            const items = this._items()
            const focused = document.activeElement
            const c = content()
            const isItem = (el) =>
              el && c.contains(el) && el.matches(
                "[data-polaris-dropdown-menu-item], [data-polaris-dropdown-menu-checkbox-item], [data-polaris-dropdown-menu-radio-item], [data-polaris-dropdown-menu-sub-trigger]"
              )
            const activeSub = focused ? this._subOf(focused) : null
            if (event.key === "Escape") {
              event.preventDefault()
              const openSub = root.querySelector("[data-polaris-dropdown-menu-sub-content]:not([hidden])")
              if (openSub) {
                const sub = this._subOf(openSub)
                const trigger = sub && sub.querySelector("[data-polaris-dropdown-menu-sub-trigger]")
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
            } else if (event.key === "ArrowRight" && focused && focused.matches("[data-polaris-dropdown-menu-sub-trigger]")) {
              event.preventDefault()
              const sub = this._subOf(focused)
              this._openSub(sub)
              const subItems = this._items(sub)
              this._focusItem(subItems[0])
            } else if (event.key === "ArrowLeft" && activeSub) {
              event.preventDefault()
              const trigger = activeSub.querySelector("[data-polaris-dropdown-menu-sub-trigger]")
              this._closeSub(activeSub)
              if (trigger) trigger.focus()
            } else if ((event.key === "Enter" || event.key === " ") && isItem(focused)) {
              event.preventDefault()
              focused.click()
            } else if (event.key.length === 1 && !event.metaKey && !event.ctrlKey && !event.altKey) {
              // Typeahead: jump to the item whose label starts with the
              // buffered characters.
              const now = performance.now()
              if (now - this._typeaheadAt > 500) this._typeahead = ""
              this._typeaheadAt = now
              this._typeahead += event.key.toLowerCase()
              const match = items.find((item) =>
                (item.textContent || "").trim().toLowerCase().startsWith(this._typeahead)
              )
              if (match) {
                event.preventDefault()
                this._focusItem(match)
              }
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)

          // Hover highlights via real focus, the Radix pointermove model.
          this._onPointerMove = (event) => {
            if (!this._open) return
            const item = event.target.closest(
              "[data-polaris-dropdown-menu-item], [data-polaris-dropdown-menu-checkbox-item], [data-polaris-dropdown-menu-radio-item], [data-polaris-dropdown-menu-sub-trigger]"
            )
            if (item && root.contains(item) && item.dataset.disabled !== "true" && item !== document.activeElement) {
              item.focus()
            }
            const subTrigger = event.target.closest("[data-polaris-dropdown-menu-sub-trigger]")
            if (subTrigger) this._openSub(this._subOf(subTrigger))
            const subLeft = event.target.closest("[data-polaris-dropdown-menu-sub-content]")
            if (!subTrigger && !subLeft) {
              root.querySelectorAll("[data-polaris-dropdown-menu-sub]").forEach((sub) => {
                if (!sub.contains(event.target)) this._closeSub(sub)
              })
            }
          }
          document.addEventListener("pointermove", this._onPointerMove)

          this._syncTriggerAria()
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onClick)
          document.removeEventListener("click", this._onDocumentClick)
          document.removeEventListener("click", this._onItemActivate, true)
          this.el.removeEventListener("keydown", this._onTriggerKeydown)
          document.removeEventListener("keydown", this._onKeydown, true)
          document.removeEventListener("pointermove", this._onPointerMove)
        }
      }
    </script>
    """
  end

  @doc """
  The dropdown menu item: a plain action — the source's
  DropdownMenuItem. Activation goes through `phx-click` (via `rest`),
  fired by both pointer clicks and Enter. `inset` indents to line up
  under a label.
  """
  attr(:disabled, :boolean, default: false, doc: "Dims the item and blocks activation.")

  attr(:inset, :boolean,
    default: false,
    doc: "Indent the item (`pl-8`) to align under an inset label."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:inner_block, doc: "The item label — a direct verb (\"Delete project\").")

  def dropdown_menu_item(assigns) do
    ~H"""
    <div
      data-polaris-dropdown-menu-item
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
  The dropdown menu label: a non-interactive group caption — the
  source's DropdownMenuLabel (`px-2 py-1.5 text-xs text-foreground-lighter`).
  """
  attr(:inset, :boolean, default: false, doc: "Indent the label (`pl-8`).")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the label.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The caption — short and plural (\"Team\").")

  def dropdown_menu_label(assigns) do
    ~H"""
    <div
      data-polaris-dropdown-menu-label
      class={cn(["px-2 py-1.5 text-xs text-content-muted", if(@inset, do: "pl-8"), @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The dropdown menu separator: the hairline between groups — the
  source's DropdownMenuSeparator (`-mx-1 my-1 h-px bg-border-overlay`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the separator.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  def dropdown_menu_separator(assigns) do
    ~H"""
    <div
      data-polaris-dropdown-menu-separator
      role="separator"
      class={cn(["-mx-1 my-1 h-px bg-surface-border", @class])}
      {@rest}
    />
    """
  end

  @doc """
  The dropdown menu shortcut: the right-aligned ⌘-string inside an
  item — the source's DropdownMenuShortcut
  (`ml-auto text-xs tracking-widest opacity-60`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the shortcut.")
  attr(:rest, :global, doc: "Forwarded to the `<span>`: `data-*`, …")

  slot(:inner_block, doc: "The shortcut glyphs (\"⇧⌘P\").")

  def dropdown_menu_shortcut(assigns) do
    ~H"""
    <span
      data-polaris-dropdown-menu-shortcut
      class={cn(["ml-auto text-xs tracking-widest text-content-muted opacity-60", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  The dropdown menu checkbox item: a toggleable action with a leading
  check indicator — the source's DropdownMenuCheckboxItem. `checked`
  is server-driven (the Radix controlled `checked` prop); flip it in
  the `phx-click` handler.
  """
  attr(:checked, :boolean, default: false, doc: "Server-driven check state.")
  attr(:disabled, :boolean, default: false, doc: "Dims the item and blocks activation.")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:inner_block, doc: "The item label — state the toggle (\"Show status bar\").")

  def dropdown_menu_checkbox_item(assigns) do
    ~H"""
    <div
      data-polaris-dropdown-menu-checkbox-item
      data-disabled={to_string(@disabled)}
      role="menuitemcheckbox"
      aria-checked={to_string(@checked)}
      aria-disabled={to_string(@disabled)}
      tabindex="-1"
      class={cn(indicator_item_classes() ++ [@class])}
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
  The dropdown menu radio item: one choice in a mutually exclusive set
  — the source's DropdownMenuRadioItem, with the dot indicator.
  `checked` is server-driven; group siblings under
  `dropdown_menu_radio_group`.
  """
  attr(:checked, :boolean, default: false, doc: "Server-driven selection state.")
  attr(:disabled, :boolean, default: false, doc: "Dims the item and blocks activation.")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:inner_block, doc: "The choice label.")

  def dropdown_menu_radio_item(assigns) do
    ~H"""
    <div
      data-polaris-dropdown-menu-radio-item
      data-disabled={to_string(@disabled)}
      role="menuitemradio"
      aria-checked={to_string(@checked)}
      aria-disabled={to_string(@disabled)}
      tabindex="-1"
      class={cn(indicator_item_classes() ++ [@class])}
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
  The dropdown menu radio group: a mutually exclusive set of radio
  items — the source's DropdownMenuRadioGroup (semantics only; the
  selection lives in your server state).
  """
  attr(:value, :string,
    default: nil,
    doc: "The group's current value — informational; drive `checked` from your own state."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The `dropdown_menu_radio_item`s.")

  def dropdown_menu_radio_group(assigns) do
    ~H"""
    <div
      data-polaris-dropdown-menu-radio-group
      role="group"
      data-value={@value}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The dropdown menu group: a semantics-only wrapper for a related item
  cluster — the source's DropdownMenuGroup.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The group's items.")

  def dropdown_menu_group(assigns) do
    ~H"""
    <div data-polaris-dropdown-menu-group role="group" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The dropdown menu submenu wrapper: groups a sub trigger with its
  nested content — the source's DropdownMenuSub.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the wrapper.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The `dropdown_menu_sub_trigger` and `dropdown_menu_sub_content`.")

  def dropdown_menu_sub(assigns) do
    ~H"""
    <div data-polaris-dropdown-menu-sub class={cn(["relative", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The dropdown menu sub trigger: the item that opens a nested menu on
  hover or **ArrowRight** — the source's DropdownMenuSubTrigger, with
  the auto-appended right chevron.
  """
  attr(:disabled, :boolean, default: false, doc: "Dims the trigger and blocks opening.")
  attr(:inset, :boolean, default: false, doc: "Indent the trigger (`pl-8`).")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the trigger.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, doc: "The trigger label.")

  def dropdown_menu_sub_trigger(assigns) do
    ~H"""
    <div
      data-polaris-dropdown-menu-sub-trigger
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
        class="ml-auto size-3 shrink-0 text-content-muted"
        aria-hidden="true"
      >
        <path d="m9 18 6-6-6-6" />
      </svg>
    </div>
    """
  end

  @doc """
  The dropdown menu sub content: the nested menu panel — the source's
  DropdownMenuSubContent, floated beside its trigger and opened by the
  hook on hover or **ArrowRight**.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the sub panel.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The nested items.")

  def dropdown_menu_sub_content(assigns) do
    ~H"""
    <div
      data-polaris-dropdown-menu-sub-content
      data-state="closed"
      role="menu"
      hidden
      class={
        cn([
          "absolute left-full top-0 z-50 ml-1 min-w-32 overflow-hidden rounded-md border border-surface-border",
          "bg-surface-panel p-1 text-content-primary shadow-lg outline-none",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
