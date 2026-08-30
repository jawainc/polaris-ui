defmodule PolarisUI.Components.NavigationMenu do
  @moduledoc """
  The Polaris navigation menu: the header navigation bar with
  hover/click mega-menu panels — the port of the Supabase design system
  NavigationMenu (`packages/ui`, the shadcn port of the Radix
  NavigationMenu primitive).

  ## Anatomy

      <.navigation_menu id="site-nav">
        <.navigation_menu_list>
          <.navigation_menu_item>
            <.navigation_menu_trigger>Getting started</.navigation_menu_trigger>
            <.navigation_menu_content>
              <ul class="grid gap-3 p-6 md:w-[400px] lg:grid-cols-[.75fr_1fr]">
                <li>
                  <.navigation_menu_link href="/docs">Introduction</.navigation_menu_link>
                </li>
              </ul>
            </.navigation_menu_content>
          </.navigation_menu_item>
          <.navigation_menu_item>
            <.navigation_menu_link href="/docs" >Documentation</.navigation_menu_link>
          </.navigation_menu_item>
        </.navigation_menu_list>
      </.navigation_menu>

    * **root** — the `<nav>` landmark (`relative z-10 flex flex-1 items-center
      justify-center`) carrying the hook and, below the list, the shared
      **indicator** — the little diamond that appears under the open
      trigger (the source's NavigationMenuIndicator, `top-[60%]` rotated
      square).
    * **list** — `group flex flex-1 list-none items-center justify-center
      space-x-1`.
    * **trigger** — the `h-10` button with the auto-appended chevron
      rotating 180° while open (`group-data-[state=open]:rotate-180`).
    * **content** — the panel; in the source it portals into the shared
      NavigationMenuViewport, in this port the colocated runtime hook
      positions it `fixed`, centered under the bar with the viewport's
      own panel treatment (border, panel surface, `shadow-lg`,
      `origin-top-center`) — LiveView patches keep contents inside their
      items, so the React portal dance is unnecessary.
    * **link** — a plain navigation anchor carrying the trigger
      treatment (the source's `navigationMenuTriggerStyle`).

  ## Behavior

  Like the source, opening is **client-side** for zero latency: clicks
  toggle, hovering a trigger opens after a short delay, and hovering
  another trigger while open switches instantly (the Radix Menubar-style
  hover-switch). **Escape**, clicking/focusing outside, and leaving the
  bar (and its panel) with the pointer close it. Switching panels slides
  the new content in from the direction of its trigger — the source's
  `data-motion=from-start/from-end` slide, driven by the hook.

  ## Keyboard

  **ArrowLeft**/**ArrowRight** roam between triggers (switching menus
  while one is open, like the source); **ArrowDown** opens the focused
  trigger's panel and moves focus into it; **Enter**/**Space** toggle on
  the button natively; **Tab** flows trigger → panel links → next
  trigger, since panels stay in the item's DOM; **Escape** closes and
  refocuses the trigger.

  ## Responsive pattern

  The source's `renderViewport={false}` + manual viewport +
  horizontal-scroll composition maps to wrapping the list yourself:

      <.navigation_menu id="nav" class="max-w-[500px] rounded-md border border-surface-border">
        <div class="overflow-x-auto">
          <.navigation_menu_list class="w-full p-3">…</.navigation_menu_list>
        </div>
      </.navigation_menu>

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the nav root — required because the colocated hook
    that manages opening, positioning, and switching anchors on it.
    """
  )

  attr(:label, :string,
    default: nil,
    doc: "Accessible name for the `<nav>` landmark (falls back to `aria-label` via `rest`)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<nav>`.")
  attr(:rest, :global, doc: "Forwarded to the `<nav>`: `aria-label`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "One `navigation_menu_list`.")

  def navigation_menu(assigns) do
    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        nav_classes: cn(["relative z-10 flex flex-1 items-center justify-center", assigns.class])
      )

    ~H"""
    <nav
      id={@id}
      aria-label={@label}
      data-polaris-navigation-menu
      class={@nav_classes}
      phx-hook={@hook}
      {@rest}
    >
      {render_slot(@inner_block)}
      <div
        data-polaris-navigation-menu-indicator
        data-state="hidden"
        aria-hidden="true"
        class={
          cn([
            "absolute top-full z-1 flex h-1.5 items-end justify-center",
            "transition-opacity duration-100",
            "data-[state=hidden]:opacity-0 data-[state=visible]:opacity-100"
          ])
        }
      >
        <div class="relative top-[60%] h-2 w-2 rotate-45 rounded-tl-sm bg-surface-border shadow-md" />
      </div>
    </nav>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          this._open = null
          this._openTimer = null
          this._closeTimer = null
          this._pointer = { x: 0, y: 0 }

          const items = () => Array.from(root.querySelectorAll("[data-polaris-navigation-menu-item]"))
          const triggers = () => Array.from(root.querySelectorAll("[data-polaris-navigation-menu-trigger]"))
          const triggerOf = (item) => item.querySelector("[data-polaris-navigation-menu-trigger]")
          const contentOf = (item) => item.querySelector("[data-polaris-navigation-menu-content]")
          const indicator = () => root.querySelector("[data-polaris-navigation-menu-indicator]")

          this._items = items
          this._triggers = triggers

          // Center the panel under the bar with the viewport's look,
          // clamped into the viewport with 8px margins.
          this._position = (item) => {
            const c = contentOf(item)
            const t = triggerOf(item)
            const ind = indicator()
            if (!c) return
            c.style.visibility = "hidden"
            const rootRect = root.getBoundingClientRect()
            c.style.top = rootRect.bottom + 6 + "px"
            const w = c.offsetWidth
            let left = rootRect.left + rootRect.width / 2 - w / 2
            left = Math.max(8, Math.min(left, window.innerWidth - w - 8))
            c.style.left = left + "px"
            c.style.visibility = ""
            if (t && ind) {
              const r = t.getBoundingClientRect()
              ind.style.left = r.left + r.width / 2 - rootRect.left - 4 + "px"
            }
          }

          // The source's motion language: fade + scale from the bar on
          // first open (the viewport's zoom-in), slide from the trigger's
          // direction when switching (from-start / from-end).
          this._animate = (c, fromDirection) => {
            if (typeof c.animate !== "function") return
            const from =
              fromDirection === 0
                ? "translateY(-0.25rem) scale(0.98)"
                : fromDirection > 0
                  ? "translateX(0.75rem)"
                  : "translateX(-0.75rem)"
            c.animate(
              [{ opacity: 0, transform: from }, { opacity: 1, transform: "none" }],
              { duration: fromDirection === 0 ? 150 : 100, easing: "ease-out" }
            )
          }

          this._syncDom = () => {
            items().forEach((item) => {
              const t = triggerOf(item)
              const c = contentOf(item)
              const open = item === this._open
              if (t) {
                t.setAttribute("data-state", open ? "open" : "closed")
                t.setAttribute("aria-expanded", open ? "true" : "false")
              }
              if (c) {
                if (open) c.removeAttribute("hidden")
                else c.setAttribute("hidden", "")
                c.setAttribute("data-state", open ? "open" : "closed")
              }
            })
            const ind = indicator()
            if (ind) ind.setAttribute("data-state", this._open ? "visible" : "hidden")
          }

          this._openItem = (item) => {
            if (!item || this._open === item) return
            const prevIndex = this._open ? items().indexOf(this._open) : -1
            const nextIndex = items().indexOf(item)
            this._open = item
            this._syncDom()
            this._position(item)
            this._animate(contentOf(item), prevIndex < 0 ? 0 : nextIndex > prevIndex ? 1 : -1)
          }

          this._close = ({ refocus = false } = {}) => {
            if (!this._open) return
            const t = triggerOf(this._open)
            this._open = null
            this._syncDom()
            if (refocus && t) t.focus()
          }

          this._cancelTimers = () => {
            if (this._openTimer) clearTimeout(this._openTimer)
            if (this._closeTimer) clearTimeout(this._closeTimer)
            this._openTimer = this._closeTimer = null
          }

          // Clicks toggle (delegated, so LiveView morphs never orphan it).
          this._onClick = (event) => {
            const t = event.target.closest("[data-polaris-navigation-menu-trigger]")
            if (!t || !root.contains(t)) return
            event.preventDefault()
            const item = t.closest("[data-polaris-navigation-menu-item]")
            this._cancelTimers()
            if (this._open === item) this._close()
            else this._openItem(item)
          }
          root.addEventListener("click", this._onClick)

          // Hover opens after a short delay; an open menu switches
          // instantly (the Radix hover-switch). Hovering anything else
          // inside the bar or the open panel cancels pending closes —
          // pointerover bubbles from the fixed-positioned panel too,
          // since it stays a DOM descendant of its item.
          this._onTriggerEnter = (event) => {
            const t = event.target.closest("[data-polaris-navigation-menu-trigger]")
            if (!t || !root.contains(t)) {
              this._cancelTimers()
              return
            }
            this._cancelTimers()
            const item = t.closest("[data-polaris-navigation-menu-item]")
            if (this._open && this._open !== item) {
              this._openItem(item)
            } else if (!this._open) {
              this._openTimer = setTimeout(() => this._openItem(item), 100)
            }
          }
          root.addEventListener("pointerover", this._onTriggerEnter)

          // Leaving the bar (and its panel) closes after a grace
          // period, unless the pointer has re-entered either.
          this._overNav = () => {
            const el = document.elementFromPoint(this._pointer.x, this._pointer.y)
            return el && root.contains(el)
          }
          this._onRootLeave = () => {
            this._cancelTimers()
            this._closeTimer = setTimeout(() => {
              if (!this._overNav()) this._close()
            }, 300)
          }
          root.addEventListener("pointerleave", this._onRootLeave)

          this._onPointerMove = (event) => {
            this._pointer.x = event.clientX
            this._pointer.y = event.clientY
          }
          document.addEventListener("pointermove", this._onPointerMove)

          this._onDocumentClick = (event) => {
            if (this._open && !root.contains(event.target)) this._close()
          }
          document.addEventListener("click", this._onDocumentClick)

          this._onFocusIn = (event) => {
            if (this._open && !root.contains(event.target)) this._close()
          }
          document.addEventListener("focusin", this._onFocusIn)

          // Triggers roam on ArrowLeft/Right (switching open menus);
          // ArrowDown opens and moves focus into the panel; Escape closes.
          this._onKeydown = (event) => {
            const t = event.target.closest("[data-polaris-navigation-menu-trigger]")
            if (!t || !root.contains(t)) {
              if (event.key === "Escape" && this._open) {
                event.preventDefault()
                this._close({ refocus: true })
              }
              return
            }
            const list = triggers()
            const index = list.indexOf(t)
            if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
              event.preventDefault()
              const dir = event.key === "ArrowRight" ? 1 : -1
              const next = list[(index + dir + list.length) % list.length]
              next.focus()
              if (this._open) {
                this._openItem(next.closest("[data-polaris-navigation-menu-item]"))
              }
            } else if (event.key === "ArrowDown") {
              event.preventDefault()
              const item = t.closest("[data-polaris-navigation-menu-item]")
              this._openItem(item)
              const c = contentOf(item)
              if (c) {
                const focusable = c.querySelector("a, button")
                if (focusable) focusable.focus()
              }
            } else if (event.key === "Escape" && this._open) {
              event.preventDefault()
              this._close({ refocus: true })
            }
          }
          root.addEventListener("keydown", this._onKeydown)

          window.addEventListener("resize", this._onResize = () => {
            if (this._open) this._position(this._open)
          })
        },
        updated() {
          // LiveView patches may stomp data-state/hidden; re-apply.
          this._syncDom()
          if (this._open) this._position(this._open)
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this._cancelTimers()
          this.el.removeEventListener("click", this._onClick)
          this.el.removeEventListener("pointerover", this._onTriggerEnter)
          this.el.removeEventListener("pointerleave", this._onRootLeave)
          this.el.removeEventListener("keydown", this._onKeydown)
          document.removeEventListener("pointermove", this._onPointerMove)
          document.removeEventListener("click", this._onDocumentClick)
          document.removeEventListener("focusin", this._onFocusIn)
          window.removeEventListener("resize", this._onResize)
        }
      }
    </script>
    """
  end

  @doc """
  The navigation list — the source's NavigationMenuList (`group flex
  flex-1 list-none items-center justify-center space-x-1`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<ul>`.")
  attr(:rest, :global, doc: "Forwarded to the `<ul>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "The `navigation_menu_item`s.")

  def navigation_menu_list(assigns) do
    ~H"""
    <ul
      data-polaris-navigation-menu-list
      class={cn(["group flex flex-1 list-none items-center justify-center space-x-1", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </ul>
    """
  end

  @doc """
  One navigation entry — the source's NavigationMenuItem: wraps a
  `navigation_menu_trigger` + `navigation_menu_content` pair, or a bare
  `navigation_menu_link`.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<li>`.")
  attr(:rest, :global, doc: "Forwarded to the `<li>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "The trigger + content, or a link.")

  def navigation_menu_item(assigns) do
    ~H"""
    <li data-polaris-navigation-menu-item class={cn(["relative", @class])} {@rest}>
      {render_slot(@inner_block)}
    </li>
    """
  end

  @doc """
  The menu trigger: the top-level button with its auto-appended chevron
  — the source's NavigationMenuTrigger (`navigationMenuTriggerStyle`:
  `h-10 py-2 px-4`, accent on hover/focus and while open, chevron
  rotating 180° on `data-state=open`).
  """
  attr(:disabled, :boolean, default: false, doc: "Dims the trigger and blocks opening.")

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the trigger (the demos compose button variants here)."
  )

  attr(:rest, :global, doc: "Forwarded to the `<button>`: `phx-click`, `data-*`, …")

  slot(:inner_block, required: true, doc: "The trigger label (\"Getting started\").")

  def navigation_menu_trigger(assigns) do
    ~H"""
    <button
      type="button"
      data-polaris-navigation-menu-trigger
      data-state="closed"
      aria-haspopup="true"
      aria-expanded="false"
      data-disabled={to_string(@disabled)}
      aria-disabled={to_string(@disabled)}
      disabled={@disabled}
      class={cn(trigger_classes() ++ [@class])}
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
        aria-hidden="true"
        class="relative top-px ml-1 h-3 w-3 transition duration-200 group-data-[state=open]:rotate-180"
      >
        <path d="m6 9 6 6 6-6" />
      </svg>
    </button>
    """
  end

  @doc """
  The menu panel: the mega-menu content — the source's
  NavigationMenuContent, here a hidden panel the hook unhides and
  positions centered under the bar with the viewport's panel treatment.
  Size it with `class` (`md:w-[400px]`, grids, …).
  """
  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the panel — widths, grids, padding."
  )

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The panel body — links, lists, promos.")

  def navigation_menu_content(assigns) do
    ~H"""
    <div
      data-polaris-navigation-menu-content
      data-state="closed"
      hidden
      class={
        cn([
          "fixed z-50 w-max max-w-[calc(100vw-2rem)] origin-top-center overflow-hidden",
          "rounded-md border border-surface-border bg-surface-panel text-content-primary",
          "shadow-lg outline-none",
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
  The navigation link: a plain anchor carrying the trigger treatment —
  the source's NavigationMenuLink (its demos compose
  `navigationMenuTriggerStyle`), for items without a panel.
  """
  attr(:href, :string,
    default: nil,
    doc: "Link target — omit for a placeholder `<a>` driven by `phx-click`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the link.")
  attr(:rest, :global, doc: "Forwarded to the `<a>`: `phx-click`, `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "The link label.")

  def navigation_menu_link(assigns) do
    ~H"""
    <a
      href={@href}
      data-polaris-navigation-menu-link
      class={cn(trigger_classes() ++ [@class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  # The source's navigationMenuTriggerStyle cva over Polaris tokens:
  # accent surfaces on hover/focus and while open (the demos compose
  # button variants on top via `class`).
  defp trigger_classes do
    [
      "group inline-flex w-max items-center justify-center rounded-md text-sm font-medium",
      "h-10 px-4 py-2 transition-colors",
      "bg-surface-base text-content-primary hover:bg-surface-panel-hover hover:text-content-primary",
      "focus:outline-none focus:bg-surface-panel-hover focus:text-content-primary",
      "data-[state=open]:bg-surface-panel-hover/50 data-[state=open]:text-content-primary",
      "disabled:pointer-events-none disabled:opacity-50"
    ]
  end
end
