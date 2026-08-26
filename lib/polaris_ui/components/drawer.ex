defmodule PolarisUI.Components.Drawer do
  @moduledoc """
  The Polaris drawer: an edge-anchored modal panel that slides over the
  page — the port of the Supabase design system Drawer (`packages/ui`,
  built on the [vaul](https://github.com/emilkowalski/vaul) React
  drawer, itself a Radix Dialog).

  The drawer is the mobile-leaning rung of the modality ladder: use it
  for contextual tasks on small screens (the Supabase "responsive
  dialog" pattern renders a Dialog at `md:` up and a Drawer below) and
  for settings-style panels that benefit from drag-to-dismiss. Critical
  confirmations belong to the Alert Dialog, decision forms to the
  Confirmation Modal.

  ## Anatomy

      <.drawer
        id="invite-drawer"
        open={@show_invite}
        title="Invite members"
        description="Add teammates to this organization."
        on_close="close-invite"
      >
        ...inputs...
        <:footer>
          <.drawer_close on_close="close-invite" class="...">Cancel</.drawer_close>
          <.button phx-click="send-invites" variant="primary">Send invites</.button>
        </:footer>
      </.drawer>

    * **overlay** — the dimmed scrim (`fixed inset-0 z-50 bg-overlay`);
      clicking it dismisses.
    * **panel** — the edge-anchored surface. `direction` picks the edge:
      `bottom` (the default, with the signature drag handle), `top`,
      `left`, or `right` (side drawers, `w-3/4 sm:max-w-sm`). Top/bottom
      panels cap at `max-h-[80vh]` and round their leading corners.
    * **handle** — the 100×8px pill on bottom drawers; dragging it (or
      touch-dragging the panel) slides the drawer toward its edge.
    * **header** — `title` (required, wired to `aria-labelledby`) plus
      an optional `description` (`text-sm text-content-secondary`,
      `aria-describedby`), centered on top/bottom drawers like the
      source.
    * **body** — the inner block, free-form.
    * **footer** — `mt-auto` stacked actions (`flex flex-col gap-2 p-4`),
      cancel first, action after.

  ## Visibility, drag, and events

  Visibility is server-driven via `open`; the **overlay click**,
  **Escape**, and **drag-to-dismiss** all push `on_close` (via the
  colocated hook), matching vaul's dismissible default. Dragging past
  25% of the panel's travel — or a fast flick (velocity above vaul's
  0.4 px/ms threshold) — dismisses; anything less springs back with
  vaul's `cubic-bezier(0.32, 0.72, 0, 1)` easing. The panel also slides
  in from its edge on open with the same motion.

  Like the Dialog, the hook traps Tab within the panel, focuses the
  first focusable on open, restores focus to the invoking element on
  close, and locks background scroll.

  ## Accessibility

    * The panel renders `role="dialog"` `aria-modal="true"` with
      `aria-labelledby` wired to the title id (`aria-describedby` joins
      the description when present).

  ## Microcopy

  Per the Supabase copywriting guidelines: the title names the task
  ("Invite members"), the description states the consequence in one
  plain sentence, and footer buttons use the specific verb — "Send
  invites", "Revoke access" — never "Submit" or "OK".

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @directions ~w(top right bottom left)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the drawer root — required because the colocated hook
    that manages dismissal, focus trapping, and drag anchors on it. The
    title/description ids derive from it (`"<id>-title"`).
    """
  )

  attr(:open, :boolean,
    default: false,
    doc: "Server-driven visibility. Toggle it from the `on_close` handler."
  )

  attr(:title, :string,
    required: true,
    doc: "Drawer heading — name the task (\"Invite members\")."
  )

  attr(:description, :string,
    default: nil,
    doc: "One-sentence guidance under the title, wired to aria-describedby."
  )

  attr(:on_close, :string,
    required: true,
    doc: """
    LiveView event fired by every dismiss path — overlay click, Escape,
    drag-to-dismiss (all pushed by the hook).
    """
  )

  attr(:direction, :string,
    values: @directions,
    default: "bottom",
    doc: """
    Edge the panel anchors to: `bottom` (the vaul default, with drag
    handle), `top`, `left`, or `right`.
    """
  )

  attr(:hide_handle, :boolean,
    default: false,
    doc: "Drop the drag handle on bottom drawers (e.g. when the body must own the full surface)."
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the content panel — where the source's
    DrawerContent `className` lands.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, …")

  slot(:inner_block, doc: "The body — free-form.")

  slot(:footer,
    doc: """
    Footer actions pinned to the panel's far edge — cancel first, action
    after, both specific verbs ("Send invites").
    """
  )

  def drawer(assigns) do
    validate_in!(:direction, assigns.direction, @directions)

    has_body? = slot_content?(assigns.inner_block, assigns)
    has_footer? = slot_content?(assigns.footer, assigns)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Drawer",
        state: if(assigns.open, do: "open", else: "closed"),
        has_body?: has_body?,
        has_footer?: has_footer?,
        show_handle?: assigns.direction == "bottom" and not assigns.hide_handle,
        panel_classes:
          cn([
            "fixed z-50 flex h-auto flex-col bg-surface-panel text-content-primary",
            "shadow-lg outline-none",
            direction_classes(assigns.direction),
            assigns.class
          ]),
        header_classes:
          cn([
            "flex flex-col gap-0.5 p-4 md:gap-1.5 md:text-left",
            if(assigns.direction in ~w(bottom top), do: "text-center")
          ]),
        footer_classes: "mt-auto flex flex-col gap-2 p-4",
        describedby_id: assigns.description && "#{assigns.id}-description"
      )

    ~H"""
    <div
      id={@id}
      class="contents"
      data-polaris-drawer
      data-state={@state}
      data-direction={@direction}
      data-close-event={@on_close}
      phx-hook={@hook}
      {@rest}
    >
      <div
        :if={@open}
        data-polaris-drawer-overlay
        aria-hidden="true"
        class="fixed inset-0 z-50 bg-overlay"
      >
      </div>
      <div
        :if={@open}
        data-polaris-drawer-panel
        role="dialog"
        aria-modal="true"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={@describedby_id}
        tabindex="-1"
        class={@panel_classes}
      >
        <div
          :if={@show_handle?}
          data-polaris-drawer-handle
          aria-hidden="true"
          class="mx-auto mt-4 h-2 w-[100px] shrink-0 cursor-grab rounded-full bg-surface-border touch-none"
        >
        </div>
        <div data-polaris-drawer-header class={@header_classes}>
          <h2
            id={"#{@id}-title"}
            data-polaris-drawer-title
            class="text-base leading-none font-semibold"
          >
            {@title}
          </h2>
          <p
            :if={@description}
            id={"#{@id}-description"}
            data-polaris-drawer-description
            class="text-sm text-content-secondary"
          >
            {@description}
          </p>
        </div>
        <div :if={@has_body?} data-polaris-drawer-body>
          {render_slot(@inner_block)}
        </div>
        <div :if={@has_footer?} data-polaris-drawer-footer class={@footer_classes}>
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Drawer" runtime>
      {
        mounted() {
          this._active = false
          this._sync()
        },
        updated() {
          this._sync()
        },
        destroyed() {
          this._release()
        },
        _sync() {
          const open = this.el.dataset.state === "open"
          if (open && !this._active) {
            this._trap()
          } else if (!open && this._active) {
            this._release()
          }
        },
        _panel() {
          return this.el.querySelector("[data-polaris-drawer-panel]")
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
          this._active = true
          this._previouslyFocused = document.activeElement
          document.body.style.overflow = "hidden"
          const root = this.el
          const overlay = root.querySelector("[data-polaris-drawer-overlay]")
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
          this._setupDrag()
          // Entrance: slide in from the anchored edge with vaul's easing.
          if (panel && typeof panel.animate === "function") {
            const direction = root.dataset.direction || "bottom"
            const from = { bottom: "translateY(100%)", top: "translateY(-100%)", right: "translateX(100%)", left: "translateX(-100%)" }[direction]
            const slide = panel.animate(
              [{ transform: from }, { transform: "none" }],
              { duration: 350, easing: "cubic-bezier(0.32, 0.72, 0, 1)" }
            )
            slide.finished
              .then(() => {
                if (panel) panel.style.transform = ""
              })
              .catch(() => {})
          }
          const items = this._focusables()
          const target = items[0] || panel
          if (target) {
            target.focus()
          }
        },
        // vaul's drag-to-dismiss: pull the panel toward its edge; past
        // 25% of its travel or on a fast flick (velocity > 0.4 px/ms)
        // dismiss, otherwise spring back.
        _setupDrag() {
          const root = this.el
          const panel = this._panel()
          const handle = root.querySelector("[data-polaris-drawer-handle]")
          if (!panel) {
            return
          }
          const direction = root.dataset.direction || "bottom"
          const axis = direction === "left" || direction === "right" ? "x" : "y"
          // Positive travel moves the panel toward its own edge.
          const sign = { bottom: 1, top: -1, right: 1, left: -1 }[direction]
          this._onDragPointerDown = (event) => {
            const fromHandle = handle && handle.contains(event.target)
            // The handle drags with any pointer; the panel body only
            // with touch, and never from inside scrollable content.
            if (!fromHandle) {
              if (event.pointerType !== "touch") return
              const scrollable = event.target.closest && event.target.closest("[data-polaris-drawer-body]")
              if (scrollable && scrollable.scrollHeight > scrollable.clientHeight) return
            }
            const start = axis === "y" ? event.clientY : event.clientX
            let travel = 0
            let lastAt = performance.now()
            let lastPos = start
            let velocity = 0
            panel.style.transition = "none"
            const size = axis === "y" ? panel.offsetHeight : panel.offsetWidth
            const onMove = (moveEvent) => {
              const pos = axis === "y" ? moveEvent.clientY : moveEvent.clientX
              const now = performance.now()
              if (now > lastAt) {
                velocity = Math.abs((pos - lastPos) / (now - lastAt))
                lastAt = now
                lastPos = pos
              }
              travel = Math.max(0, (pos - start) * sign)
              const transform = axis === "y" ? `translateY(${travel * sign}px)` : `translateX(${travel * sign}px)`
              panel.style.transform = transform
            }
            const onUp = () => {
              document.removeEventListener("pointermove", onMove)
              document.removeEventListener("pointerup", onUp)
              document.removeEventListener("pointercancel", onUp)
              panel.style.transition = ""
              if (travel / size > 0.25 || velocity > 0.4) {
                this._dismiss(direction, axis, sign)
              } else {
                this._springBack(panel, axis, sign, travel)
              }
            }
            document.addEventListener("pointermove", onMove)
            document.addEventListener("pointerup", onUp)
            document.addEventListener("pointercancel", onUp)
          }
          panel.addEventListener("pointerdown", this._onDragPointerDown)
        },
        _dismiss(direction, axis, sign) {
          const panel = this._panel()
          if (!panel || typeof panel.animate !== "function") {
            this._close()
            return
          }
          const to = axis === "y" ? `translateY(${sign * 110}%)` : `translateX(${sign * 110}%)`
          const slide = panel.animate(
            [{ transform: panel.style.transform || "none" }, { transform: to }],
            { duration: 300, easing: "cubic-bezier(0.32, 0.72, 0, 1)" }
          )
          slide.finished.then(() => this._close()).catch(() => this._close())
        },
        _springBack(panel, axis, sign, travel) {
          if (typeof panel.animate !== "function") {
            panel.style.transform = ""
            return
          }
          const from = axis === "y" ? `translateY(${travel * sign}px)` : `translateX(${travel * sign}px)`
          const back = panel.animate(
            [{ transform: from }, { transform: "none" }],
            { duration: 350, easing: "cubic-bezier(0.32, 0.72, 0, 1)" }
          )
          back.finished
            .then(() => {
              panel.style.transform = ""
            })
            .catch(() => {
              panel.style.transform = ""
            })
        },
        _close() {
          const name = this.el.dataset.closeEvent
          if (name && typeof this.pushEvent === "function") {
            this.pushEvent(name)
          }
        },
        _release() {
          if (!this._active) {
            return
          }
          this._active = false
          document.removeEventListener("keydown", this._onKeydown, true)
          const root = this.el
          const overlay = root && root.querySelector("[data-polaris-drawer-overlay]")
          overlay && overlay.removeEventListener("click", this._onOverlayClick)
          const panel = this._panel()
          panel && panel.removeEventListener("pointerdown", this._onDragPointerDown)
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

  @doc """
  The drawer close: a button firing the drawer's `on_close` — the
  source's DrawerClose. Put it first in the footer with the cancel
  verb.
  """
  attr(:on_close, :string,
    required: true,
    doc: "The drawer's `on_close` event — fired on click."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the button.")
  attr(:rest, :global, doc: "Forwarded to the `<button>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The button label — a direct verb (\"Cancel\").")

  def drawer_close(assigns) do
    ~H"""
    <button
      type="button"
      data-polaris-drawer-close
      phx-click={@on_close}
      class={
        cn([
          "inline-flex items-center justify-center rounded-xs px-4 py-2 text-sm",
          "text-content-primary border border-surface-border bg-surface-panel",
          "hover:bg-surface-panel-hover hover:border-surface-border-hover cursor-pointer",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
          "disabled:pointer-events-none disabled:opacity-50",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  # Panel geometry per direction — the source's data-[vaul-drawer-direction]
  # variants, resolved server-side instead (the direction is known at render).
  defp direction_classes("bottom"),
    do: "inset-x-0 bottom-0 mt-24 max-h-[80vh] rounded-t-lg border-t border-surface-border"

  defp direction_classes("top"),
    do: "inset-x-0 top-0 mb-24 max-h-[80vh] rounded-b-lg border-b border-surface-border"

  defp direction_classes("right"),
    do: "inset-y-0 right-0 w-3/4 border-l border-surface-border sm:max-w-sm"

  defp direction_classes("left"),
    do: "inset-y-0 left-0 w-3/4 border-r border-surface-border sm:max-w-sm"

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
