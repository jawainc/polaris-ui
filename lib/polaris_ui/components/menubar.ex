defmodule PolarisUI.Components.Menubar do
  @moduledoc """
  The Polaris menubar: the visually persistent horizontal menu bar of
  desktop applications — the port of the Supabase design system Menubar
  (`packages/ui`, `menubar.tsx`, built on the Radix Menubar
  primitive).

  ## Client-side visibility, server-side actions

  Like the dropdown menu, a menubar opens with zero latency, so the
  colocated runtime hook owns open/close entirely: trigger click
  toggles, hovering another trigger while a menu is open switches to
  it, Escape / click-outside / item activation closes. Item activation
  rides each item's own `phx-click`, exactly like the source's
  `onSelect`.

  ## Anatomy

      <.menubar id="app-menubar">
        <.menubar_menu>
          <.menubar_trigger>File</.menubar_trigger>
          <.menubar_content>
            <.menubar_item phx-click="new-tab">
              New Tab <.menubar_shortcut>⌘T</.menubar_shortcut>
            </.menubar_item>
            <.menubar_item disabled>New Incognito Window</.menubar_item>
            <.menubar_separator />
            <.menubar_sub>
              <.menubar_sub_trigger>Share</.menubar_sub_trigger>
              <.menubar_sub_content>
                <.menubar_item phx-click="share-email">Email link</.menubar_item>
              </.menubar_sub_content>
            </.menubar_sub>
          </.menubar_content>
        </.menubar_menu>
        <.menubar_menu>
          <.menubar_trigger>View</.menubar_trigger>
          <.menubar_content>
            <.menubar_checkbox_item checked={@show_urls} phx-click="toggle-urls">
              Always Show Full URLs
            </.menubar_checkbox_item>
          </.menubar_content>
        </.menubar_menu>
      </.menubar>

    * **root** — the bar itself (`flex h-10 items-center space-x-1
      rounded-md border bg-surface-base p-1`).
    * **menu** — one top-level menu: a `menubar_trigger` button plus
      its `menubar_content` panel.
    * **items** — `menubar_item` (plain action), `menubar_checkbox_item`
      / `menubar_radio_item` (server-driven `checked`), under
      `menubar_label` captions, split by `menubar_separator`, with
      `menubar_shortcut` glyphs right-aligned. `inset` indents an item.
    * **submenus** — `menubar_sub` + `menubar_sub_trigger` (auto-appended
      chevron) + `menubar_sub_content`; the hook opens them on hover and
      **ArrowRight**, closing on **ArrowLeft** / mouse-out.

  ## Keyboard

  The Radix Menubar model: **Enter**/**Space**/**ArrowDown** opens the
  focused trigger's menu; **ArrowLeft**/**ArrowRight** roam between
  top-level triggers (and switch menus while one is open); arrows cycle
  items; **Home**/**End** bound the list; **Enter**/**Space** activate
  the focused item (dispatching its own click, so `phx-click` fires
  identically for pointer and keyboard); typing jumps to matching items
  (typeahead); **Escape** closes. Highlight rides real DOM focus, so
  the shared `focus:` styles light items for both pointer and keys. On
  close, focus returns to the trigger.

  ## Microcopy

  Per the Supabase copywriting guidelines: items use direct verbs
  ("New Tab", "Toggle Fullscreen") — never "Submit" or "OK" — and
  shortcuts state the real binding.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  # The shared item treatment (the source's MenubarItem classes over
  # Polaris tokens) — a helper since HEEx resolves @-references to
  # assigns, not attributes.
  defp item_base_classes do
    [
      "relative flex cursor-default select-none items-center rounded-xs px-2 py-1.5 text-sm outline-none",
      "transition-colors focus:bg-brand-emerald-muted focus:text-content-primary focus:outline-none",
      "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    ]
  end

  # The checkbox/radio treatment (pl-8 room for the indicator).
  defp indicator_item_classes do
    [
      "relative flex cursor-default select-none items-center rounded-xs py-1.5 pl-8 pr-2 text-sm outline-none",
      "transition-colors focus:bg-brand-emerald-muted focus:text-content-primary focus:outline-none",
      "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    ]
  end

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the menubar root — required because the colocated
    hook that manages opening, positioning, and keyboard navigation
    anchors on it.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the bar.")

  attr(:rest, :global, doc: "Forwarded to the bar: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The `menubar_menu`s.")

  def menubar(assigns) do
    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        bar_classes:
          cn([
            "flex h-10 items-center space-x-1 rounded-md border border-surface-border bg-surface-base p-1",
            assigns.class
          ])
      )

    ~H"""
    <div
      id={@id}
      data-polaris-menubar
      class={@bar_classes}
      phx-hook={@hook}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          this._open = null
          this._typeahead = ""
          this._typeaheadAt = 0

          const menus = () => Array.from(root.querySelectorAll("[data-polaris-menubar-menu]"))
          const triggers = () => Array.from(root.querySelectorAll("[data-polaris-menubar-trigger]"))
          const contentOf = (menu) => menu.querySelector("[data-polaris-menubar-content]")
          const triggerOf = (menu) => menu.querySelector("[data-polaris-menubar-trigger]")

          this._items = (scope) =>
            Array.from(
              (scope || root).querySelectorAll(
                "[data-polaris-menubar-item], [data-polaris-menubar-checkbox-item], [data-polaris-menubar-radio-item], [data-polaris-menubar-sub-trigger]"
              )
            ).filter((el) => el.dataset.disabled !== "true")

          this._focusItem = (item) => {
            if (item) item.focus()
          }

          this._closeSub = (sub) => {
            const sc = sub ? sub.querySelector("[data-polaris-menubar-sub-content]") : null
            const trigger = sub ? sub.querySelector("[data-polaris-menubar-sub-trigger]") : null
            if (sc) {
              sc.setAttribute("hidden", "")
              sc.setAttribute("data-state", "closed")
            }
            if (trigger) trigger.setAttribute("data-state", "closed")
          }

          this._closeMenu = (menu) => {
            menu.querySelectorAll("[data-polaris-menubar-sub]").forEach((sub) => this._closeSub(sub))
            const c = contentOf(menu)
            const t = triggerOf(menu)
            if (c) {
              c.setAttribute("hidden", "")
              c.setAttribute("data-state", "closed")
            }
            if (t) {
              t.setAttribute("data-state", "closed")
              t.setAttribute("aria-expanded", "false")
            }
            if (this._open === menu) this._open = null
          }

          this._closeAll = ({ refocus = true } = {}) => {
            menus().forEach((menu) => this._closeMenu(menu))
            if (refocus && this._refocusTrigger) {
              this._refocusTrigger.focus()
              this._refocusTrigger = null
            }
          }

          // Fixed positioning measured from the trigger's viewport rect —
          // the source pins Radix's align=start, alignOffset=-4,
          // sideOffset=8; flip up when the panel spills the viewport.
          this._position = (menu) => {
            const c = contentOf(menu)
            const t = triggerOf(menu)
            if (!c || !t) return
            const rect = t.getBoundingClientRect()
            const sideOffset = 8
            const alignOffset = -4
            c.style.left = rect.left + alignOffset + "px"
            c.style.top = ""
            c.style.bottom = ""
            c.style.right = ""
            c.style.top = rect.bottom + sideOffset + "px"
            const spills = c.getBoundingClientRect().bottom > window.innerHeight
            if (spills) {
              c.style.top = ""
              c.style.bottom = window.innerHeight - rect.top + sideOffset + "px"
            }
          }

          this._animateIn = (c) => {
            if (typeof c.animate !== "function") return
            const openingFromBelow = c.style.bottom !== ""
            const slide = openingFromBelow ? "translateY(0.5rem)" : "translateY(-0.5rem)"
            const zoom = c.animate(
              [
                { opacity: 0, transform: `${slide} scale(0.95)` },
                { opacity: 1, transform: "none" },
              ],
              { duration: 150, easing: "ease-out" }
            )
            zoom.finished.then(() => { c.style.transform = "" }).catch(() => {})
          }

          this._openMenu = (menu, { focusItem = true } = {}) => {
            if (this._open === menu) return
            this._refocusTrigger = triggerOf(menu)
            menus().forEach((other) => {
              if (other !== menu) this._closeMenu(other)
            })
            const c = contentOf(menu)
            const t = triggerOf(menu)
            if (!c) return
            c.removeAttribute("hidden")
            c.setAttribute("data-state", "open")
            t.setAttribute("data-state", "open")
            t.setAttribute("aria-expanded", "true")
            this._open = menu
            this._position(menu)
            this._animateIn(c)
            if (focusItem) this._focusItem(this._items(menu)[0])
          }

          // Trigger clicks toggle; clicking another trigger while open
          // switches menus (delegated, so LiveView morphs never orphan
          // the listener).
          this._onClick = (event) => {
            const t = event.target.closest("[data-polaris-menubar-trigger]")
            if (!t || !root.contains(t)) return
            event.preventDefault()
            const menu = t.closest("[data-polaris-menubar-menu]")
            if (this._open === menu) {
              this._closeAll()
            } else {
              // Radix focuses the first item on click-open, same as
              // keyboard-open; hover-open (below) does not.
              this._openMenu(menu)
            }
          }
          root.addEventListener("click", this._onClick)

          // Radix Menubar: hovering another trigger while a menu is open
          // switches to it (without stealing focus).
          this._onTriggerEnter = (event) => {
            if (!this._open) return
            const t = event.target.closest("[data-polaris-menubar-trigger]")
            if (!t || !root.contains(t)) return
            const menu = t.closest("[data-polaris-menubar-menu]")
            if (menu && menu !== this._open) this._openMenu(menu, { focusItem: false })
          }
          root.addEventListener("pointerenter", this._onTriggerEnter, true)

          this._onDocumentClick = (event) => {
            if (this._open && !root.contains(event.target)) this._closeAll({ refocus: false })
          }
          document.addEventListener("click", this._onDocumentClick)

          // Any item activation closes the whole bar (Radix's onSelect);
          // clicks fall through to the item's own phx-click binding.
          this._onItemActivate = (event) => {
            if (!this._open) return
            const item = event.target.closest(
              "[data-polaris-menubar-item], [data-polaris-menubar-checkbox-item], [data-polaris-menubar-radio-item]"
            )
            if (item && item.dataset.disabled === "true") {
              event.preventDefault()
              event.stopPropagation()
              return
            }
            if (item) this._closeAll()
          }
          document.addEventListener("click", this._onItemActivate, true)

          // Top-level trigger keys: open on Enter/Space/ArrowDown/ArrowUp,
          // roam between triggers on ArrowLeft/ArrowRight (the Radix model).
          this._onTriggerKeydown = (event) => {
            if (this._open) return
            const t = event.target.closest("[data-polaris-menubar-trigger]")
            if (!t || !root.contains(t)) return
            const list = triggers()
            const index = list.indexOf(t)
            if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
              event.preventDefault()
              const dir = event.key === "ArrowRight" ? 1 : -1
              this._focusItem(list[(index + dir + list.length) % list.length])
            } else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
              event.preventDefault()
              const menu = t.closest("[data-polaris-menubar-menu]")
              this._openMenu(menu)
              const items = this._items(menu)
              this._focusItem(event.key === "ArrowUp" ? items[items.length - 1] : items[0])
            } else if (event.key === "Enter" || event.key === " ") {
              event.preventDefault()
              this._openMenu(t.closest("[data-polaris-menubar-menu]"), { focusItem: false })
            }
          }
          root.addEventListener("keydown", this._onTriggerKeydown)

          this._subOf = (el) => el.closest("[data-polaris-menubar-sub]")

          this._openSub = (sub) => {
            const sc = sub.querySelector("[data-polaris-menubar-sub-content]")
            const trigger = sub.querySelector("[data-polaris-menubar-sub-trigger]")
            root.querySelectorAll("[data-polaris-menubar-sub]").forEach((other) => {
              if (other !== sub && !sub.contains(other)) this._closeSub(other)
            })
            if (sc) {
              sc.removeAttribute("hidden")
              sc.setAttribute("data-state", "open")
            }
            if (trigger) trigger.setAttribute("data-state", "open")
          }

          // Menu-open keys: cycle items, switch top-level menus on
          // ArrowLeft/ArrowRight (the Radix Menubar signature), submenus
          // on ArrowRight over a sub-trigger, typeahead, Escape closes.
          this._onKeydown = (event) => {
            if (!this._open) return
            const menu = this._open
            const c = contentOf(menu)
            const focused = document.activeElement
            const isItem = (el) =>
              el && c.contains(el) && el.matches(
                "[data-polaris-menubar-item], [data-polaris-menubar-checkbox-item], [data-polaris-menubar-radio-item], [data-polaris-menubar-sub-trigger]"
              )
            const scopeOf = (el) => (el ? el.closest("[role=menu]") : null)
            const activeSub = focused ? this._subOf(focused) : null
            const list = triggers()
            const menuIndex = menus().indexOf(menu)

            if (event.key === "Escape") {
              event.preventDefault()
              const openSub = menu.querySelector("[data-polaris-menubar-sub-content]:not([hidden])")
              if (openSub && activeSub) {
                const trigger = activeSub.querySelector("[data-polaris-menubar-sub-trigger]")
                this._closeSub(activeSub)
                if (trigger) trigger.focus()
              } else {
                this._closeAll()
              }
            } else if (event.key === "ArrowDown" && isItem(focused)) {
              event.preventDefault()
              const items = this._items(scopeOf(focused) || c)
              const index = items.indexOf(focused)
              this._focusItem(items[(index + 1) % items.length] || items[0])
            } else if (event.key === "ArrowUp" && isItem(focused)) {
              event.preventDefault()
              const items = this._items(scopeOf(focused) || c)
              const index = items.indexOf(focused)
              this._focusItem(items[(index - 1 + items.length) % items.length] || items[0])
            } else if (event.key === "Home" && isItem(focused)) {
              event.preventDefault()
              this._focusItem(this._items(scopeOf(focused) || c)[0])
            } else if (event.key === "End" && isItem(focused)) {
              event.preventDefault()
              const items = this._items(scopeOf(focused) || c)
              this._focusItem(items[items.length - 1])
            } else if (event.key === "ArrowRight" && focused && focused.matches("[data-polaris-menubar-sub-trigger]")) {
              event.preventDefault()
              const sub = this._subOf(focused)
              this._openSub(sub)
              this._focusItem(this._items(sub)[0])
            } else if (event.key === "ArrowRight" && isItem(focused)) {
              // Radix Menubar: ArrowRight on a plain item opens the next
              // top-level menu.
              event.preventDefault()
              const next = menus()[(menuIndex + 1) % menus().length]
              this._openMenu(next)
            } else if (event.key === "ArrowLeft" && activeSub) {
              event.preventDefault()
              const trigger = activeSub.querySelector("[data-polaris-menubar-sub-trigger]")
              this._closeSub(activeSub)
              if (trigger) trigger.focus()
            } else if (event.key === "ArrowLeft" && isItem(focused)) {
              event.preventDefault()
              const prev = menus()[(menuIndex - 1 + menus().length) % menus().length]
              this._openMenu(prev)
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
              const match = this._items(scopeOf(focused) || c).find((item) =>
                (item.textContent || "").trim().toLowerCase().startsWith(this._typeahead)
              )
              if (match) {
                event.preventDefault()
                this._focusItem(match)
              }
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)

          // Hover highlights via real focus, the Radix pointermove model;
          // submenus open on hover over their trigger.
          this._onPointerMove = (event) => {
            if (!this._open) return
            const item = event.target.closest(
              "[data-polaris-menubar-item], [data-polaris-menubar-checkbox-item], [data-polaris-menubar-radio-item], [data-polaris-menubar-sub-trigger]"
            )
            if (item && root.contains(item) && item.dataset.disabled !== "true" && item !== document.activeElement) {
              item.focus()
            }
            const subTrigger = event.target.closest("[data-polaris-menubar-sub-trigger]")
            if (subTrigger) this._openSub(this._subOf(subTrigger))
            const inSub = event.target.closest("[data-polaris-menubar-sub-content]")
            if (!subTrigger && !inSub) {
              root.querySelectorAll("[data-polaris-menubar-sub]").forEach((sub) => {
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
          this.el.removeEventListener("click", this._onClick)
          this.el.removeEventListener("pointerenter", this._onTriggerEnter, true)
          this.el.removeEventListener("keydown", this._onTriggerKeydown)
          document.removeEventListener("click", this._onDocumentClick)
          document.removeEventListener("click", this._onItemActivate, true)
          document.removeEventListener("keydown", this._onKeydown, true)
          document.removeEventListener("pointermove", this._onPointerMove)
        }
      }
    </script>
    """
  end

  @doc """
  One top-level menu: groups a `menubar_trigger` with its
  `menubar_content` — the source's MenubarMenu.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the menu wrapper.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The `menubar_trigger` and `menubar_content`.")

  def menubar_menu(assigns) do
    ~H"""
    <div data-polaris-menubar-menu class={cn(["relative", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The menu trigger: the top-level button — the source's MenubarTrigger
  (`text-sm font-medium`, accent on focus and while open).
  """
  attr(:disabled, :boolean, default: false, doc: "Dims the trigger and blocks opening.")

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the trigger.")

  attr(:rest, :global, doc: "Forwarded to the `<button>`: `phx-click`, `data-*`, …")

  slot(:inner_block, required: true, doc: "The trigger label (\"File\").")

  def menubar_trigger(assigns) do
    ~H"""
    <button
      type="button"
      data-polaris-menubar-trigger
      data-state="closed"
      data-disabled={to_string(@disabled)}
      aria-haspopup="menu"
      aria-expanded="false"
      aria-disabled={to_string(@disabled)}
      class={
        cn([
          "flex cursor-default select-none items-center rounded-xs px-3 py-1.5 text-sm font-medium outline-none",
          "transition-colors focus:bg-brand-emerald-muted focus:text-content-primary focus:outline-none",
          "data-[state=open]:bg-brand-emerald-muted data-[state=open]:text-content-primary",
          "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  The menu panel: the `role="menu"` dropdown under a trigger — the
  source's MenubarContent (min-w-48, the overlay panel, slide-in from
  top), positioned by the hook with the source's pinned Radix offsets.
  """
  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the panel — e.g. `w-56`."
  )

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The items, labels, separators, and submenus.")

  def menubar_content(assigns) do
    ~H"""
    <div
      data-polaris-menubar-content
      data-state="closed"
      role="menu"
      hidden
      class={
        cn([
          "fixed z-50 min-w-48 overflow-hidden rounded-md border border-surface-border",
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

  @doc """
  The menu item: a plain action — the source's MenubarItem. Activation
  goes through `phx-click` (via `rest`), fired by both pointer clicks
  and Enter. `inset` indents to line up under a label.
  """
  attr(:disabled, :boolean, default: false, doc: "Dims the item and blocks activation.")

  attr(:inset, :boolean,
    default: false,
    doc: "Indent the item (`pl-8`) to align under an inset label."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:inner_block, doc: "The item label — a direct verb (\"New Tab\").")

  def menubar_item(assigns) do
    ~H"""
    <div
      data-polaris-menubar-item
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
  The menu label: a non-interactive group caption — the source's
  MenubarLabel (`px-2 py-1.5 text-sm font-semibold`).
  """
  attr(:inset, :boolean, default: false, doc: "Indent the label (`pl-8`).")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the label.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The caption — short and plural (\"Profiles\").")

  def menubar_label(assigns) do
    ~H"""
    <div
      data-polaris-menubar-label
      class={cn(["px-2 py-1.5 text-sm font-semibold", if(@inset, do: "pl-8"), @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The menu separator: the hairline between groups — the source's
  MenubarSeparator (`-mx-1 my-1 h-px`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the separator.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  def menubar_separator(assigns) do
    ~H"""
    <div
      data-polaris-menubar-separator
      role="separator"
      class={cn(["-mx-1 my-1 h-px bg-surface-border", @class])}
      {@rest}
    />
    """
  end

  @doc """
  The menu shortcut: the right-aligned ⌘-string inside an item — the
  source's MenubarShortcut (`ml-auto text-xs tracking-widest`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the shortcut.")
  attr(:rest, :global, doc: "Forwarded to the `<span>`: `data-*`, …")

  slot(:inner_block, doc: "The shortcut glyphs (\"⌘T\").")

  def menubar_shortcut(assigns) do
    ~H"""
    <span
      data-polaris-menubar-shortcut
      class={cn(["ml-auto text-xs tracking-widest text-content-muted", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  The menu checkbox item: a toggleable action with a leading check
  indicator — the source's MenubarCheckboxItem. `checked` is
  server-driven (the Radix controlled `checked` prop); flip it in the
  `phx-click` handler.
  """
  attr(:checked, :boolean, default: false, doc: "Server-driven check state.")
  attr(:disabled, :boolean, default: false, doc: "Dims the item and blocks activation.")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:inner_block, doc: "The item label — state the toggle (\"Always Show Full URLs\").")

  def menubar_checkbox_item(assigns) do
    ~H"""
    <div
      data-polaris-menubar-checkbox-item
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
  The menu radio item: one choice in a mutually exclusive set — the
  source's MenubarRadioItem, with the dot indicator. `checked` is
  server-driven; group siblings under `menubar_radio_group`.
  """
  attr(:checked, :boolean, default: false, doc: "Server-driven selection state.")
  attr(:disabled, :boolean, default: false, doc: "Dims the item and blocks activation.")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `phx-click`, `phx-value-*`, `data-*`, …")

  slot(:inner_block, doc: "The choice label.")

  def menubar_radio_item(assigns) do
    ~H"""
    <div
      data-polaris-menubar-radio-item
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
  The menu radio group: a mutually exclusive set of radio items — the
  source's MenubarRadioGroup (semantics only; the selection lives in
  your server state).
  """
  attr(:value, :string,
    default: nil,
    doc: "The group's current value — informational; drive `checked` from your own state."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The `menubar_radio_item`s.")

  def menubar_radio_group(assigns) do
    ~H"""
    <div
      data-polaris-menubar-radio-group
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
  The menu group: a semantics-only wrapper for a related item cluster —
  the source's MenubarGroup.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, doc: "The group's items.")

  def menubar_group(assigns) do
    ~H"""
    <div data-polaris-menubar-group role="group" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The submenu wrapper: groups a sub trigger with its nested content —
  the source's MenubarSub.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the wrapper.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The `menubar_sub_trigger` and `menubar_sub_content`.")

  def menubar_sub(assigns) do
    ~H"""
    <div data-polaris-menubar-sub class={cn(["relative", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The submenu trigger: the item that opens a nested menu on hover or
  **ArrowRight** — the source's MenubarSubTrigger, with the
  auto-appended right chevron.
  """
  attr(:disabled, :boolean, default: false, doc: "Dims the trigger and blocks opening.")
  attr(:inset, :boolean, default: false, doc: "Indent the trigger (`pl-8`).")
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the trigger.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The trigger label.")

  def menubar_sub_trigger(assigns) do
    ~H"""
    <div
      data-polaris-menubar-sub-trigger
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
  The submenu panel: the nested menu — the source's MenubarSubContent
  (min-w-32, overlay panel), floated beside its trigger and opened by
  the hook on hover or **ArrowRight**.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the sub panel.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The nested items.")

  def menubar_sub_content(assigns) do
    ~H"""
    <div
      data-polaris-menubar-sub-content
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
