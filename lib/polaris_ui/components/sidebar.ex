defmodule PolarisUI.Components.Sidebar do
  @moduledoc """
  The Polaris sidebar: the composable app-navigation family — the port
  of the Supabase design system Sidebar (`packages/ui`, the shadcn
  sidebar: provider + collapsible rail + menu primitives).

  A full application chrome. Compose it inside the provider, with the
  inset as the sidebar's next sibling:

      <.sidebar_provider id="app-shell">
        <.sidebar id="app-sidebar" open={@sidebar_open} on_toggle="toggle-sidebar">
          <.sidebar_header>…logo…</.sidebar_header>
          <.sidebar_content>
            <.sidebar_group>
              <.sidebar_group_label>Platform</.sidebar_group_label>
              <.sidebar_group_content>
                <.sidebar_menu>
                  <.sidebar_menu_item>
                    <.sidebar_menu_button active={@page == "tables"} tooltip="Tables"
                                          phx-click="go-tables">
                      <svg …/><span>Tables</span>
                    </.sidebar_menu_button>
                  </.sidebar_menu_item>
                  …
                </.sidebar_menu>
              </.sidebar_group_content>
            </.sidebar_group>
          </.sidebar_content>
          <.sidebar_footer>…user…</.sidebar_footer>
          <.sidebar_rail on_toggle="toggle-sidebar" />
        </.sidebar>
        <.sidebar_inset>
          <header><.sidebar_trigger on_toggle="toggle-sidebar" /> …</header>
          {@inner_block}
        </.sidebar_inset>
      </.sidebar_provider>

  ## Anatomy

    * **provider** — the flex wrapper that owns the width variables
      (`--sidebar-width: 13rem`, `--sidebar-width-icon: 3rem`, the
      Supabase widths — pass `width`/`width_icon` to widen) and paints
      itself the sidebar surface when any child sidebar is the `inset`
      variant.
    * **sidebar** — the rail itself. `side` (`left` the default,
      `right`), `variant` (`sidebar` the default, `floating` with a
      rounded border and shadow, `inset` where the content area
      becomes the rounded card), and `collapsible` — `offcanvas` (the
      default: slides fully away), `icon` (collapses to the 3rem icon
      rail with tooltips), or `none` (static, always expanded).
    * **header / content / footer** — the column bands; `content`
      scrolls (`min-h-0 flex-1 overflow-auto`, locked when
      icon-collapsed).
    * **groups** — `sidebar_group` > `sidebar_group_label` >
      `sidebar_group_content` stacks the menus; `sidebar_group_action`
      pins an icon button to the label's row.
    * **menu** — `sidebar_menu` > `sidebar_menu_item` >
      `sidebar_menu_button` (with `active`, `tooltip`, the `sm`/
      `default`/`lg` size scale, and `variant="outline"`), plus
      `sidebar_menu_action` (an inline icon action),
      `sidebar_menu_badge` (counts), `sidebar_menu_skeleton`
      (loading), and the `sidebar_menu_sub`/`_item`/`_button` subtree
      for nested pages.
    * **trigger** — the PanelLeft ghost button that toggles the rail;
      **rail** — the invisible edge strip that toggles on click;
      **inset** — the `<main>` that flows beside the sidebar and
      rounds when the sidebar is `variant="inset"`.
    * **separator / input** — the hairline and the compact search
      field for menu tops.

  ## State, persistence, and the mobile rung

  State is server-owned (`open`), riding the DOM exactly like the
  source: `data-state="expanded|collapsed"`, plus
  `data-collapsible`/`data-variant`/`data-side` on the sidebar root —
  every descendant (and `sidebar_inset`, through peer selectors)
  restyles from those attributes alone, so toggling is one LiveView
  patch. The colocated hook persists every state change to the
  `sidebar:state` cookie (7 days, the source's exact contract) —
  restore it server-side on load:

      def sidebar_open?(cookies), do: cookies["sidebar:state"] != "false"

  Below `md` the desktop tree hides and the mobile rung takes over: a
  sheet (`open_mobile`) sliding in from the same `side` at the 18rem
  mobile width, with scrim dismissal and Escape pushing
  `on_close_mobile`. `shortcut` opts into the ⌘/Ctrl+B toggle the
  upstream docs promise but the Supabase source ships disabled —
  enable it per-layout.

  ## Accessibility

    * The trigger and rail are real buttons with "Toggle Sidebar"
      labels; menu buttons keep the focus ring, and disabled states
      dim without eating pointer affordances.
    * The mobile sheet is a labelled modal dialog (`aria-label`
      "Sidebar") with focus trapped while open.
    * Icon-collapsed menu buttons carry the `tooltip` text as a native
      title — visible exactly when the label is not.
  """

  use PolarisUI.Component

  @sides ~w(left right)
  @variants ~w(sidebar floating inset)
  @collapsibles ~w(offcanvas icon none)
  @button_variants ~w(default outline)
  @button_sizes ~w(sm default lg)
  @sub_sizes ~w(sm md)

  @cookie_max_age 60 * 60 * 24 * 7

  # ─────────────────────────────────────────────────────────────
  # Provider
  # ─────────────────────────────────────────────────────────────

  attr(:id, :string, required: true, doc: "Unique id for the shell wrapper.")

  attr(:width, :string,
    default: "13rem",
    doc: "The expanded sidebar width (the Supabase `SIDEBAR_WIDTH`), as a CSS length."
  )

  attr(:width_icon, :string,
    default: "3rem",
    doc: "The icon-collapsed width (the Supabase `SIDEBAR_WIDTH_ICON`), as a CSS length."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the wrapper.")
  attr(:rest, :global, doc: "Forwarded to the wrapper `<div>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The sidebar and its inset content.")

  def sidebar_provider(assigns) do
    ~H"""
    <div
      id={@id}
      class={
        cn([
          "group/sidebar-wrapper flex min-h-svh w-full",
          "has-[[data-variant=inset]]:bg-surface-base",
          @class
        ])
      }
      style={"--sidebar-width: #{@width}; --sidebar-width-icon: #{@width_icon};"}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────
  # Sidebar root
  # ─────────────────────────────────────────────────────────────

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the sidebar root — the colocated hook (cookie
    persistence, ⌘/Ctrl+B, the mobile sheet) anchors on it.
    """
  )

  attr(:open, :boolean,
    default: true,
    doc: "Server-driven desktop state. Restore it from the `sidebar:state` cookie on load."
  )

  attr(:open_mobile, :boolean,
    default: false,
    doc: "Server-driven mobile-sheet visibility (`md:` down)."
  )

  attr(:on_toggle, :string,
    required: true,
    doc: """
    LiveView event pushed by the trigger, rail, and (when `shortcut`)
    ⌘/Ctrl+B — toggle `open` (or `open_mobile`) in its handler.
    """
  )

  attr(:on_close_mobile, :string,
    default: nil,
    doc: "Dismiss event for the mobile sheet — defaults to `on_toggle`."
  )

  attr(:shortcut, :boolean,
    default: false,
    doc: """
    Opt into the ⌘/Ctrl+B toggle. Off by default, matching the
    Supabase source (which ships the upstream shortcut commented out).
    """
  )

  attr(:side, :string, values: @sides, default: "left", doc: "Edge the rail hugs: `left` or `right`.")

  attr(:variant, :string,
    values: @variants,
    default: "sidebar",
    doc: "`sidebar` (flush, the default), `floating` (rounded + shadowed), or `inset`."
  )

  attr(:collapsible, :string,
    values: @collapsibles,
    default: "offcanvas",
    doc: "`offcanvas` (slides fully away), `icon` (collapses to the icon rail), or `none`."
  )

  attr(:overflowing, :boolean,
    default: false,
    doc: "The Supabase `overflowing` mode: reserve a 3rem stub and overlay instead of pushing."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the inner container.")
  attr(:rest, :global, doc: "Forwarded to the inner container `<div>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "Header / content / footer bands.")

  def sidebar(assigns) do
    validate_in!(:side, assigns.side, @sides)
    validate_in!(:variant, assigns.variant, @variants)
    validate_in!(:collapsible, assigns.collapsible, @collapsibles)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Sidebar",
        state: if(assigns.open, do: "expanded", else: "collapsed"),
        collapsed_collapsible: if(assigns.open, do: "", else: assigns.collapsible),
        close_mobile: assigns.on_close_mobile || assigns.on_toggle,
        cookie_max_age: @cookie_max_age
      )

    # collapsible="none" renders the static rail and never a mobile sheet.
    if assigns.collapsible == "none" do
      ~H"""
      <div
        id={@id}
        class={
          cn([
            "flex h-full w-(--sidebar-width) flex-col bg-surface-base text-content-primary",
            @class
          ])
        }
        data-sidebar="sidebar"
        {@rest}
      >
        {render_slot(@inner_block)}
      </div>
      """
    else
      renders_sidebar_tree(assigns)
    end
  end

  defp renders_sidebar_tree(assigns) do
    ~H"""
    <div
      id={@id}
      data-polaris-sidebar
      data-state={@state}
      data-collapsible={@collapsed_collapsible}
      data-variant={@variant}
      data-side={@side}
      data-mobile-open={to_string(@open_mobile)}
      data-toggle-event={@on_toggle}
      data-close-mobile-event={@close_mobile}
      data-shortcut={to_string(@shortcut)}
      data-cookie-max-age={@cookie_max_age}
      phx-hook={@hook}
      class={cn([if(@overflowing, do: "w-12"), "relative group peer hidden md:block shrink-0 text-content-primary"])}
    >
      <%!-- The gap div reserves layout space for the absolutely
           positioned panel; its width animates with the collapse. --%>
      <div
        class={
          cn([
            if(@overflowing, do: "absolute top-0", else: "relative"),
            "duration-100 h-full w-(--sidebar-width) bg-transparent transition-[width] ease-linear",
            "group-data-[collapsible=offcanvas]:w-0",
            "group-data-[side=right]:rotate-180",
            if(@variant in ~w(floating inset),
              do: "group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+1rem)]",
              else: "group-data-[collapsible=icon]:w-(--sidebar-width-icon)"
            )
          ])
        }
      >
      </div>
      <%!-- The panel itself — absolutely positioned (the Supabase
           source drops `fixed` so the sidebar scrolls with the
           wrapper), sliding out via negative offsets on collapse. --%>
      <div
        class={
          cn([
            "absolute top-0 h-full duration-100 inset-y-0 z-10 hidden",
            "w-(--sidebar-width) transition-[left,right,width] ease-linear md:flex",
            if(@side == "left",
              do: "left-0 group-data-[collapsible=offcanvas]:-left-(--sidebar-width)",
              else: "right-0 group-data-[collapsible=offcanvas]:-right-(--sidebar-width)"
            ),
            if(@variant in ~w(floating inset),
              do:
                "p-2 group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+1rem+2px)]",
              else:
                "group-data-[collapsible=icon]:w-(--sidebar-width-icon) group-data-[side=left]:border-r group-data-[side=right]:border-l border-surface-border"
            ),
            @class
          ])
        }
        {@rest}
      >
        <div
          data-sidebar="sidebar"
          class={
            cn([
              "flex h-full w-full flex-col bg-surface-base",
              "group-data-[variant=floating]:rounded-lg group-data-[variant=floating]:border",
              "group-data-[variant=floating]:border-surface-border group-data-[variant=floating]:shadow-sm"
            ])
          }
        >
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    <%!-- Mobile rung: below md the desktop tree hides and this sheet
         takes over — the source's Sheet at the 18rem mobile width. --%>
    <div :if={@open_mobile} class="contents md:hidden" data-polaris-sidebar-mobile={@id}>
      <div data-polaris-sidebar-mobile-overlay aria-hidden="true" class="fixed inset-0 z-50 bg-overlay">
      </div>
      <div
        data-polaris-sidebar-mobile-panel
        role="dialog"
        aria-modal="true"
        aria-label="Sidebar"
        tabindex="-1"
        class={
          cn([
            "fixed inset-y-0 z-50 flex w-[18rem] flex-col bg-surface-base p-0 text-content-primary shadow-lg",
            if(@side == "left", do: "left-0 border-r", else: "right-0 border-l"),
            "border-surface-border"
          ])
        }
      >
        <div class="flex h-full w-full flex-col">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Sidebar" runtime>
      {
        mounted() {
          this._active = false
          this._sync()
          this._onShortcut = (event) => {
            if (event.key.toLowerCase() === "b" && (event.metaKey || event.ctrlKey)) {
              event.preventDefault()
              this._push(this.el.dataset.toggleEvent)
            }
          }
          if (this.el.dataset.shortcut === "true") {
            document.addEventListener("keydown", this._onShortcut)
          }
        },
        updated() {
          this._sync()
        },
        destroyed() {
          this._release()
          document.removeEventListener("keydown", this._onShortcut)
        },
        _sync() {
          // Persist every state change to the source's cookie contract:
          // sidebar:state, path=/, 7-day max-age.
          const open = this.el.dataset.state === "expanded"
          const maxAge = this.el.dataset.cookieMaxAge || "604800"
          document.cookie = `sidebar:state=${open}; path=/; max-age=${maxAge}`
          const mobileOpen = this.el.dataset.mobileOpen === "true"
          if (mobileOpen && !this._active) {
            this._trap()
          } else if (!mobileOpen && this._active) {
            this._release()
          }
        },
        _panel() {
          return document.querySelector(`[data-polaris-sidebar-mobile="${this.el.id}"] [data-polaris-sidebar-mobile-panel]`)
        },
        _mobileRoot() {
          return document.querySelector(`[data-polaris-sidebar-mobile="${this.el.id}"]`)
        },
        _focusables() {
          const panel = this._panel()
          if (!panel) {
            return []
          }
          return Array.from(
            panel.querySelectorAll(
              'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
            )
          ).filter((el) => el.offsetParent !== null)
        },
        _trap() {
          const mobile = this._mobileRoot()
          if (!mobile) return
          this._active = true
          this._previouslyFocused = document.activeElement
          document.body.style.overflow = "hidden"
          const overlay = mobile.querySelector("[data-polaris-sidebar-mobile-overlay]")
          const panel = this._panel()
          this._onKeydown = (event) => {
            if (event.key === "Escape") {
              event.preventDefault()
              this._close()
            } else if (event.key === "Tab") {
              const items = this._focusables()
              if (items.length === 0) {
                event.preventDefault()
                return
              }
              const first = items[0]
              const last = items[items.length - 1]
              if (event.shiftKey && document.activeElement === first) {
                event.preventDefault()
                last.focus()
              } else if (!event.shiftKey && document.activeElement === last) {
                event.preventDefault()
                first.focus()
              } else if (!panel.contains(document.activeElement)) {
                event.preventDefault()
                first.focus()
              }
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)
          this._onOverlayClick = (event) => {
            if (event.target === overlay) {
              this._close()
            }
          }
          overlay && overlay.addEventListener("click", this._onOverlayClick)
          // Entrance: slide in from the anchored edge, like the sheet.
          if (panel && typeof panel.animate === "function") {
            const from = this.el.dataset.side === "right" ? "translateX(100%)" : "translateX(-100%)"
            const slide = panel.animate(
              [{ transform: from }, { transform: "none" }],
              { duration: 300, easing: "ease" }
            )
            slide.finished.catch(() => {})
          }
          const items = this._focusables()
          const target = items[0] || panel
          if (target) {
            target.focus()
          }
        },
        _push(name) {
          if (name && typeof this.pushEvent === "function") {
            this.pushEvent(name)
          }
        },
        _close() {
          this._push(this.el.dataset.closeMobileEvent)
        },
        _release() {
          if (!this._active) {
            return
          }
          this._active = false
          document.removeEventListener("keydown", this._onKeydown, true)
          const mobile = this._mobileRoot()
          const overlay = mobile && mobile.querySelector("[data-polaris-sidebar-mobile-overlay]")
          overlay && overlay.removeEventListener("click", this._onOverlayClick)
          document.body.style.overflow = ""
          if (this._previouslyFocused && typeof this._previouslyFocused.focus === "function") {
            this._previouslyFocused.focus()
          }
          this._previouslyFocused = null
        }
      }
    </script>
    """
  end

  # ─────────────────────────────────────────────────────────────
  # Trigger / Rail / Inset
  # ─────────────────────────────────────────────────────────────

  @doc """
  The toggle button — the source's PanelLeft ghost button. Put it in
  the inset's header.
  """
  attr(:on_toggle, :string, required: true, doc: "The sidebar's `on_toggle` event — fired on click.")

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the button.")
  attr(:rest, :global, doc: "Forwarded to the `<button>`: `data-*`, …")

  slot(:inner_block, doc: "Replaces the PanelLeft glyph entirely.")

  def sidebar_trigger(assigns) do
    ~H"""
    <button
      type="button"
      data-sidebar="trigger"
      phx-click={@on_toggle}
      class={
        cn([
          "inline-flex size-7 shrink-0 cursor-pointer items-center justify-center rounded-md",
          "text-content-primary transition-colors hover:bg-content-primary/10",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
          "disabled:pointer-events-none disabled:opacity-50",
          @class
        ])
      }
      {@rest}
    >
      <svg
        :if={not slot_content?(@inner_block, assigns)}
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="size-4"
        aria-hidden="true"
      >
        <rect width="18" height="18" x="3" y="3" rx="2" />
        <path d="M9 3v18" />
      </svg>
      {render_slot(@inner_block)}
      <span class="sr-only">Toggle Sidebar</span>
    </button>
    """
  end

  @doc """
  The invisible toggle strip riding the sidebar's inner edge — click
  (or grab, per the cursor) to collapse. Mouse-only by design, like
  the source (`tabindex=-1`).
  """
  attr(:on_toggle, :string, required: true, doc: "The sidebar's `on_toggle` event — fired on click.")

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the rail.")
  attr(:rest, :global, doc: "Forwarded to the `<button>`: `data-*`, …")

  def sidebar_rail(assigns) do
    ~H"""
    <button
      type="button"
      data-sidebar="rail"
      aria-label="Toggle Sidebar"
      title="Toggle Sidebar"
      tabindex="-1"
      phx-click={@on_toggle}
      class={
        cn([
          "absolute inset-y-0 z-20 hidden w-4 -translate-x-1/2 transition-all ease-linear",
          "after:absolute after:inset-y-0 after:left-1/2 after:w-[2px] hover:after:bg-surface-border",
          "group-data-[side=left]:-right-4 group-data-[side=right]:left-0 sm:flex",
          "group-data-[side=left]:cursor-w-resize group-data-[side=right]:cursor-e-resize",
          "[[data-side=left][data-state=collapsed]_&]:cursor-e-resize",
          "[[data-side=right][data-state=collapsed]_&]:cursor-w-resize",
          "group-data-[collapsible=offcanvas]:translate-x-0 group-data-[collapsible=offcanvas]:after:left-full",
          "group-data-[collapsible=offcanvas]:hover:bg-surface-base",
          "[[data-side=left][data-collapsible=offcanvas]_&]:-right-2",
          "[[data-side=right][data-collapsible=offcanvas]_&]:-left-2",
          @class
        ])
      }
      {@rest}
    >
    </button>
    """
  end

  @doc """
  The content area flowing beside the sidebar — a `<main>`. Render it
  as the sidebar's next sibling inside the provider; under
  `variant="inset"` it becomes the rounded, shadowed card.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the main.")
  attr(:rest, :global, doc: "Forwarded to the `<main>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The page content.")

  def sidebar_inset(assigns) do
    ~H"""
    <main
      class={
        cn([
          "relative flex min-h-svh flex-1 flex-col bg-surface-ground",
          "peer-data-[variant=inset]:min-h-[calc(100svh-1rem)]",
          "md:peer-data-[variant=inset]:m-2 md:peer-data-[variant=inset]:ml-0",
          "md:peer-data-[state=collapsed]:peer-data-[variant=inset]:ml-2",
          "md:peer-data-[variant=inset]:rounded-xl md:peer-data-[variant=inset]:shadow-sm",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </main>
    """
  end

  # ─────────────────────────────────────────────────────────────
  # Bands: header / content / footer
  # ─────────────────────────────────────────────────────────────

  @doc "The top band — logo, workspace switcher."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`.")

  slot(:inner_block, required: true, doc: "The band's content.")

  def sidebar_header(assigns) do
    ~H"""
    <div data-sidebar="header" class={cn(["flex flex-col gap-2 p-2", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "The scrollable middle band — stack groups here."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`.")

  slot(:inner_block, required: true, doc: "The band's content.")

  def sidebar_content(assigns) do
    ~H"""
    <div
      data-sidebar="content"
      class={
        cn([
          "flex min-h-0 flex-1 flex-col gap-2 overflow-auto",
          "group-data-[collapsible=icon]:overflow-hidden",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "The bottom band — user card, sign out."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`.")

  slot(:inner_block, required: true, doc: "The band's content.")

  def sidebar_footer(assigns) do
    ~H"""
    <div data-sidebar="footer" class={cn(["flex flex-col gap-2 p-2", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "The hairline between bands or groups."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`.")

  def sidebar_separator(assigns) do
    ~H"""
    <div
      data-sidebar="separator"
      class={cn(["mx-2 h-px w-auto bg-surface-border", @class])}
      {@rest}
    />
    """
  end

  @doc "The compact search field for menu tops."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<input>`: `type`, `placeholder`, `name`, …")

  def sidebar_input(assigns) do
    ~H"""
    <input
      type="text"
      data-sidebar="input"
      class={
        cn([
          "h-8 w-full rounded-md border border-surface-border bg-surface-ground px-2.5 text-sm",
          "text-content-primary placeholder:text-content-muted",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "disabled:cursor-not-allowed disabled:opacity-50",
          @class
        ])
      }
      {@rest}
    />
    """
  end

  # ─────────────────────────────────────────────────────────────
  # Groups
  # ─────────────────────────────────────────────────────────────

  @doc "A labeled cluster of menus."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`.")

  slot(:inner_block, required: true, doc: "Label + content.")

  def sidebar_group(assigns) do
    ~H"""
    <div data-sidebar="group" class={cn(["relative flex w-full min-w-0 flex-col p-2", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The group's heading. Collapses away in icon mode (the source's
  negative-margin + fade).
  """
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`.")

  slot(:inner_block, required: true, doc: "The label text.")

  def sidebar_group_label(assigns) do
    ~H"""
    <div
      data-sidebar="group-label"
      class={
        cn([
          "flex h-8 shrink-0 items-center rounded-md px-2 text-xs font-medium",
          "text-content-secondary outline-none transition-[margin,opacity] duration-100 ease-linear",
          "focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "[&>svg]:size-5 [&>svg]:shrink-0",
          "group-data-[collapsible=icon]:-mt-8 group-data-[collapsible=icon]:opacity-0",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "An icon action pinned to the label's row (\"Add project\", …)."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<button>`: `phx-click`, `data-*`, …")

  slot(:inner_block, required: true, doc: "The action glyph.")

  def sidebar_group_action(assigns) do
    ~H"""
    <button
      type="button"
      data-sidebar="group-action"
      class={
        cn([
          "absolute right-3 top-3.5 flex aspect-square w-5 items-center justify-center rounded-md p-0",
          "text-content-primary outline-none transition-transform cursor-pointer",
          "hover:bg-surface-panel-hover/50 focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "[&>svg]:size-5 [&>svg]:shrink-0",
          "after:absolute after:-inset-2 after:md:hidden",
          "group-data-[collapsible=icon]:hidden",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc "The group's body — holds the menu."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`.")

  slot(:inner_block, required: true, doc: "The menus.")

  def sidebar_group_content(assigns) do
    ~H"""
    <div data-sidebar="group-content" class={cn(["w-full text-sm", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────
  # Menus
  # ─────────────────────────────────────────────────────────────

  @doc "The list of menu items."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<ul>`.")

  slot(:inner_block, required: true, doc: "The items.")

  def sidebar_menu(assigns) do
    ~H"""
    <ul data-sidebar="menu" class={cn(["flex w-full min-w-0 flex-col gap-1", @class])} {@rest}>
      {render_slot(@inner_block)}
    </ul>
    """
  end

  @doc "One menu row — the named group its button, action, and badge key off."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<li>`.")

  slot(:inner_block, required: true, doc: "The button, action, badge, submenu.")

  def sidebar_menu_item(assigns) do
    ~H"""
    <li data-sidebar="menu-item" class={cn(["group/menu-item relative", @class])} {@rest}>
      {render_slot(@inner_block)}
    </li>
    """
  end

  @doc """
  The menu row's button. Icon + `<span>` label in the inner block —
  the span truncates, and in icon mode only the 20px icon survives.

  `tooltip` labels the row when icon-collapsed (a native title, shown
  exactly when the label is hidden). `href` renders a link instead of
  a button (navigation); everything else — `phx-click` for liveview
  events — rides the global attributes.
  """
  attr(:active, :boolean, default: false, doc: "Marks the current page — fills and bolds the row.")
  attr(:variant, :string, values: @button_variants, default: "default", doc: "`default` or `outline`.")
  attr(:size, :string, values: @button_sizes, default: "default", doc: "`sm`, `default`, or `lg`.")
  attr(:has_icon, :boolean, default: true, doc: "Turn off when the row has no icon — skips the icon-mode square.")
  attr(:loading, :boolean, default: false, doc: "Suppress the disabled dim while the row's data loads.")
  attr(:tooltip, :string, default: nil, doc: "The icon-collapsed label (also the native title).")
  attr(:href, :string, default: nil, doc: "Render an `<a>` navigating to `href` instead of a button.")
  attr(:disabled, :boolean, default: false, doc: "Dims and dead-ends the row.")
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<button>`/`<a>`: `phx-click`, `data-*`, …")

  slot(:inner_block, required: true, doc: "Icon + `<span>`label.")

  def sidebar_menu_button(assigns) do
    validate_in!(:variant, assigns.variant, @button_variants)
    validate_in!(:size, assigns.size, @button_sizes)

    button_classes =
      cn([
        # The source's cva base.
        "peer/menu-button flex w-full items-center gap-2 overflow-hidden rounded-md",
        "py-2 px-1.5 text-left text-sm outline-none ring-brand-emerald",
        "transition-[width,height,padding] cursor-pointer",
        "hover:bg-surface-panel-hover/50 hover:text-content-primary",
        "focus-visible:ring-2 active:bg-surface-panel-hover/50 active:text-content-primary",
        "disabled:pointer-events-none disabled:opacity-50",
        "group-has-[[data-sidebar=menu-action]]/menu-item:pr-8",
        "text-content-muted data-[active=true]:text-content-primary",
        "data-[active=true]:bg-surface-panel-hover data-[active=true]:font-medium",
        "[&>span:last-child]:truncate [&>svg]:size-5 [&>svg]:shrink-0",
        # Variants.
        variant_classes(assigns.variant),
        # Sizes.
        size_classes(assigns.size),
        # hasIcon: the icon-mode square.
        if(assigns.has_icon,
          do:
            "group-data-[collapsible=icon]:size-8! group-data-[collapsible=icon]:pl-1.5! group-data-[collapsible=icon]:pr-2!"
        ),
        # Loading keeps the disabled dim off.
        if(assigns.loading, do: "disabled:opacity-100"),
        assigns.class
      ])

    assigns =
      assign(assigns,
        button_classes: button_classes,
        data:
          Map.new(
            sidebar_menu_button_data(assigns) ++
              [{"data-sidebar", "menu-button"}]
          )
      )

    ~H"""
    <button
      :if={is_nil(@href)}
      type="button"
      class={@button_classes}
      disabled={@disabled}
      title={@tooltip}
      {@data}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    <a :if={@href} href={@href} class={@button_classes} aria-disabled={@disabled && "true"} title={@tooltip} {@data} {@rest}>
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc "An icon action inside the row (\"Delete project\", …), right-pinned."
  attr(:show_on_hover, :boolean,
    default: false,
    doc: "Reveal on row hover/focus instead of always showing."
  )

  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<button>`: `phx-click`, …")

  slot(:inner_block, required: true, doc: "The action glyph.")

  def sidebar_menu_action(assigns) do
    ~H"""
    <button
      type="button"
      data-sidebar="menu-action"
      class={
        cn([
          "absolute right-1 top-1.5 flex aspect-square w-5 items-center justify-center rounded-md p-0",
          "text-content-primary outline-none transition-transform cursor-pointer",
          "hover:bg-surface-panel-hover/50 focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "peer-hover/menu-button:text-content-primary",
          "[&>svg]:size-5 [&>svg]:shrink-0",
          "after:absolute after:-inset-2 after:md:hidden",
          "peer-data-[size=sm]/menu-button:top-1",
          "peer-data-[size=default]/menu-button:top-1.5",
          "peer-data-[size=lg]/menu-button:top-2.5",
          "group-data-[collapsible=icon]:hidden",
          if(assigns.show_on_hover,
            do:
              "md:opacity-0 group-focus-within/menu-item:opacity-100 group-hover/menu-item:opacity-100 peer-data-[active=true]/menu-button:text-content-primary"
          ),
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc "A right-pinned count (\"12\") — display only."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`.")

  slot(:inner_block, required: true, doc: "The badge content.")

  def sidebar_menu_badge(assigns) do
    ~H"""
    <div
      data-sidebar="menu-badge"
      class={
        cn([
          "pointer-events-none absolute right-1 flex h-5 min-w-5 select-none items-center justify-center rounded-md px-1",
          "text-xs font-medium tabular-nums text-content-primary",
          "peer-hover/menu-button:text-content-primary peer-data-[active=true]/menu-button:text-content-primary",
          "peer-data-[size=sm]/menu-button:top-1",
          "peer-data-[size=default]/menu-button:top-1.5",
          "peer-data-[size=lg]/menu-button:top-2.5",
          "group-data-[collapsible=icon]:hidden",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "The loading ghost of a menu row — a shimmering icon + text bar."
  attr(:show_icon, :boolean, default: false, doc: "Ghost the leading icon square too.")
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`.")

  def sidebar_menu_skeleton(assigns) do
    # The source's memoized random width: 50–90%.
    width = :rand.uniform(41) + 49

    assigns =
      assign(assigns,
        width_style: "--skeleton-width: #{width}%;"
      )

    ~H"""
    <div
      data-sidebar="menu-skeleton"
      class={cn(["flex h-8 items-center gap-2 rounded-md px-2", @class])}
      {@rest}
    >
      <div
        :if={@show_icon}
        data-sidebar="menu-skeleton-icon"
        class="size-4 animate-pulse rounded-md bg-surface-muted"
        aria-hidden="true"
      >
      </div>
      <div
        data-sidebar="menu-skeleton-text"
        class="h-4 max-w-(--skeleton-width) flex-1 animate-pulse rounded-md bg-surface-muted"
        style={@width_style}
        aria-hidden="true"
      >
      </div>
    </div>
    """
  end

  @doc "The nested page list under a menu item."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<ul>`.")

  slot(:inner_block, required: true, doc: "The sub items.")

  def sidebar_menu_sub(assigns) do
    ~H"""
    <ul
      data-sidebar="menu-sub"
      class={
        cn([
          "mx-3.5 flex min-w-0 translate-x-px flex-col gap-1 border-l border-surface-border px-2.5 py-0.5",
          "group-data-[collapsible=icon]:hidden",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </ul>
    """
  end

  @doc "One nested row."
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the `<li>`.")

  slot(:inner_block, required: true, doc: "The sub button.")

  def sidebar_menu_sub_item(assigns) do
    ~H"""
    <li class={@class} {@rest}>
      {render_slot(@inner_block)}
    </li>
    """
  end

  @doc """
  The nested row's link — an `<a>` by default (`href`), or a button
  when only `phx-click` is given.
  """
  attr(:size, :string, values: @sub_sizes, default: "md", doc: "`sm` or `md`.")
  attr(:active, :boolean, default: false, doc: "Marks the current nested page.")
  attr(:href, :string, default: nil, doc: "Navigation target — renders the source's default `<a>`.")
  attr(:class, :string, default: nil, doc: "Additional classes.")
  attr(:rest, :global, doc: "Forwarded to the element: `phx-click`, `data-*`, …")

  slot(:inner_block, required: true, doc: "Icon + `<span>`label.")

  def sidebar_menu_sub_button(assigns) do
    validate_in!(:size, assigns.size, @sub_sizes)

    classes =
      cn([
        "flex h-6 min-w-0 -translate-x-px items-center gap-2 overflow-hidden rounded-md px-2",
        "text-content-primary outline-none ring-brand-emerald",
        "hover:bg-surface-panel-hover/50 hover:text-content-primary focus-visible:ring-2",
        "active:bg-surface-panel-hover/50 active:text-content-primary",
        "disabled:pointer-events-none disabled:opacity-50",
        "data-[active=true]:bg-surface-panel-hover data-[active=true]:text-content-primary",
        "[&>span:last-child]:truncate [&>svg]:size-5 [&>svg]:shrink-0",
        if(assigns.size == "sm", do: "text-xs", else: "text-sm"),
        "group-data-[collapsible=icon]:hidden",
        assigns.class
      ])

    assigns = assign(assigns, classes: classes)

    ~H"""
    <a :if={@href} href={@href} data-sidebar="menu-sub-button" data-size={@size} data-active={to_string(@active)} class={@classes} {@rest}>
      {render_slot(@inner_block)}
    </a>
    <button
      :if={is_nil(@href)}
      type="button"
      data-sidebar="menu-sub-button"
      data-size={@size}
      data-active={to_string(@active)}
      class={@classes}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  # The cva data contract: size, active, has-icon ride as attributes.
  defp sidebar_menu_button_data(assigns) do
    [
      {"data-size", assigns.size},
      {"data-active", to_string(assigns.active)},
      {"data-has-icon", to_string(assigns.has_icon)}
    ]
  end

  defp variant_classes("default"), do: nil

  defp variant_classes("outline") do
    [
      "bg-surface-ground",
      "shadow-[0_0_0_1px_var(--color-surface-border)]",
      "hover:shadow-[0_0_0_1px_var(--color-surface-panel-hover)]"
    ]
  end

  defp size_classes("default"), do: "h-8 text-sm"
  defp size_classes("sm"), do: "h-7 text-xs"
  defp size_classes("lg"), do: "h-12 text-sm group-data-[collapsible=icon]:p-0!"

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
