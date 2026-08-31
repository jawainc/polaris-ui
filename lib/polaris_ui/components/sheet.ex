defmodule PolarisUI.Components.Sheet do
  @moduledoc """
  The Polaris sheet: a panel that slides in from a screen edge over
  the page — the port of the Supabase design system Sheet
  (`packages/ui`, a shadcn wrapper over the Radix Dialog primitive).

  The sheet is the desktop rung of the edge-panel family: use it for
  contextual tasks that benefit from staying anchored to an edge —
  filters, inspectors, quick editors ("Edit profile"). The Supabase
  guidance sticks to `side="right"`; edge-anchored panels on mobile
  belong to the Drawer, and page-pushing navigation sidebars to the
  Sidebar (whose mobile rung *is* a sheet).

  ## Anatomy

      <.sheet
        id="edit-profile"
        open={@show_edit}
        title="Edit profile"
        description="Make changes to your profile here."
        on_close="close-edit"
        side="right"
      >
        <.sheet_section>
          ...inputs...
        </.sheet_section>
        <:footer>
          <.sheet_close on_close="close-edit">Cancel</.sheet_close>
          <.button phx-click="save-profile" variant="primary">Save changes</.button>
        </:footer>
      </.sheet>

    * **overlay** — the dimmed, blurred scrim (`bg-overlay
      backdrop-blur-xs`); clicking it dismisses (drop it entirely with
      `has_overlay={false}`).
    * **panel** — the edge-anchored surface (`bg-surface-panel`,
      `shadow-lg`), bordered on its inner edge. `side` picks the edge
      (`right` the default, then `left`, `top`, `bottom`) and `size`
      sets the panel's extent — `content` sizes to its body, the
      `default` third of the viewport (`lg:w-1/3` / `h-1/3`), `sm` a
      quarter, `lg` half, `xl` five sixths (`w-4/6` on the sides),
      `xxl` (`w-5/6`, sides only) and `full` the whole screen.
    * **header** — `title` (required, wired to `aria-labelledby`) over
      a bottom hairline, plus an optional `description`
      (`text-sm text-content-secondary`, `aria-describedby`).
    * **body** — the inner block, free-form; compose it from
      `sheet_section` bands for the source's `px-5 py-4` rhythm (wrap
      them in `overflow-auto grow` for scrollable bodies).
    * **footer** — right-aligned from `sm:` up, stacked on mobile
      (`flex flex-col-reverse`), over a top border — cancel first,
      action after.
    * **✕** — top-right close (drop it with `show_close={false}`),
      low-opacity until hover, firing `on_close`.

  ## Visibility, motion, and events

  Visibility is server-driven via `open`; the **✕ button**, **Escape**,
  and **overlay clicks** (pushed by the colocated hook) all fire
  `on_close`. The hook slides the panel in from its edge over 300ms —
  the source's `data-[state=open]:slide-in-from-*` enter animation —
  and, like the source's Radix wiring, traps Tab within the panel,
  focuses the first focusable on open, restores focus on close, and
  locks background scroll.

  `modal={false}` renders the source's non-modal variant: no scrim
  dismissal, no focus trap, no scroll lock, no `aria-modal` — the
  sheet stays while the page remains interactive (Escape still
  closes).

  ## Accessibility

    * The panel renders `role="dialog"` with `aria-modal="true"`
      (omitted when non-modal) and `aria-labelledby` wired to the
      title id (`aria-describedby` joins the description when present).

  ## Microcopy

  Per the Supabase copywriting guidelines: the title names the task
  ("Edit profile"), the description states the consequence in one
  plain sentence, and footer buttons use the specific verb — "Save
  changes", "Revoke access" — never "Submit" or "OK".

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @sides ~w(top right bottom left)
  @sizes ~w(content default sm lg xl xxl full)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the sheet root — required because the colocated hook
    that manages dismissal, focus trapping, and the slide-in anchors
    on it. The title/description ids derive from it (`"<id>-title"`).
    """
  )

  attr(:open, :boolean,
    default: false,
    doc: "Server-driven visibility. Toggle it from the `on_close` handler."
  )

  attr(:title, :string,
    required: true,
    doc: "Sheet heading — name the task (\"Edit profile\")."
  )

  attr(:description, :string,
    default: nil,
    doc: "One-sentence guidance under the title, wired to aria-describedby."
  )

  attr(:on_close, :string,
    required: true,
    doc: """
    LiveView event fired by every dismiss path — the ✕ button, Escape,
    and overlay clicks (the latter two via the hook's pushEvent).
    """
  )

  attr(:side, :string,
    values: @sides,
    default: "right",
    doc: "Edge the panel anchors to: `right` (the source default), `left`, `top`, or `bottom`."
  )

  attr(:size, :string,
    values: @sizes,
    default: "default",
    doc: """
    The panel's extent: `content` sizes to the body; `default` a third
    of the viewport; then `sm` (a quarter), `lg` (half), `xl` (five
    sixths / four sixths on the sides), `xxl` (sides only), `full`.
    """
  )

  attr(:modal, :boolean,
    default: true,
    doc: """
    The modal contract: scrim dismissal, focus trap, scroll lock, and
    `aria-modal`. `false` renders the source's non-modal sheet — the
    page stays interactive; Escape still closes.
    """
  )

  attr(:has_overlay, :boolean,
    default: true,
    doc: "Drop the dimmed scrim (e.g. for panels that coexist with the page)."
  )

  attr(:show_close, :boolean,
    default: true,
    doc: "Drop the built-in ✕ button (e.g. for flows that must use the footer)."
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the content panel — where the
    source's SheetContent `className` lands (`flex flex-col gap-0` for
    stacked sections, `w-[400px] sm:w-[540px]` for custom widths).
    """
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, …")

  slot(:inner_block, doc: "The body — free-form; compose it from `sheet_section` bands.")

  slot(:footer,
    doc: """
    Footer actions over a top border — cancel first, action after,
    both specific verbs ("Save changes").
    """
  )

  def sheet(assigns) do
    validate_in!(:side, assigns.side, @sides)
    validate_in!(:size, assigns.size, @sizes)

    has_body? = slot_content?(assigns.inner_block, assigns)
    has_footer? = slot_content?(assigns.footer, assigns)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Sheet",
        state: if(assigns.open, do: "open", else: "closed"),
        has_body?: has_body?,
        has_footer?: has_footer?,
        panel_classes:
          cn([
            "fixed z-50 bg-surface-panel text-content-primary shadow-lg",
            side_classes(assigns.side),
            size_classes(assigns.side, assigns.size),
            assigns.class
          ]),
        header_classes: "px-5 py-4 text-center sm:text-left border-b border-surface-border",
        footer_classes:
          "px-5 py-3 border-t border-surface-border w-full flex flex-col-reverse sm:flex-row sm:justify-end gap-2",
        describedby_id: assigns.description && "#{assigns.id}-description"
      )

    ~H"""
    <div
      id={@id}
      class="contents"
      data-polaris-sheet
      data-state={@state}
      data-side={@side}
      data-modal={to_string(@modal)}
      data-close-event={@on_close}
      phx-hook={@hook}
      {@rest}
    >
      <div
        :if={@open and @has_overlay}
        data-polaris-sheet-overlay
        aria-hidden="true"
        class="fixed inset-0 z-50 bg-overlay backdrop-blur-xs"
      >
      </div>
      <div
        :if={@open}
        data-polaris-sheet-panel
        role="dialog"
        aria-modal={@modal && "true"}
        aria-labelledby={"#{@id}-title"}
        aria-describedby={@describedby_id}
        tabindex="-1"
        class={@panel_classes}
      >
        <div data-polaris-sheet-header class={@header_classes}>
          <h2 id={"#{@id}-title"} data-polaris-sheet-title class="text-lg leading-none">
            {@title}
          </h2>
          <p
            :if={@description}
            id={"#{@id}-description"}
            data-polaris-sheet-description
            class="text-sm text-content-secondary"
          >
            {@description}
          </p>
        </div>
        <div :if={@has_body?} data-polaris-sheet-body>
          {render_slot(@inner_block)}
        </div>
        <div :if={@has_footer?} data-polaris-sheet-footer class={@footer_classes}>
          {render_slot(@footer)}
        </div>
        <button
          :if={@show_close}
          type="button"
          data-polaris-sheet-close
          phx-click={@on_close}
          aria-label="Close"
          class={
            cn([
              "absolute right-4 top-4 rounded-xs p-0.5 opacity-70 transition-opacity",
              "hover:opacity-100 cursor-pointer",
              "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
              "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
              "disabled:pointer-events-none disabled:opacity-50"
            ])
          }
        >
          <svg
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
            <path d="M18 6 6 18" />
            <path d="m6 6 12 12" />
          </svg>
          <span class="sr-only">Close</span>
        </button>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Sheet" runtime>
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
          return this.el.querySelector("[data-polaris-sheet-panel]")
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
          const root = this.el
          const modal = root.dataset.modal !== "false"
          const overlay = root.querySelector("[data-polaris-sheet-overlay]")
          const panel = this._panel()
          if (modal) {
            this._previouslyFocused = document.activeElement
            document.body.style.overflow = "hidden"
          }
          this._onKeydown = (event) => {
            if (event.key === "Escape") {
              event.preventDefault()
              this._close()
            } else if (event.key === "Tab" && modal) {
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
          // The scrim only dismisses on modal sheets — the source's
          // non-modal dialog leaves outside interactions alone.
          if (modal) {
            this._onOverlayClick = (event) => {
              if (event.target === overlay) {
                this._close()
              }
            }
            overlay && overlay.addEventListener("click", this._onOverlayClick)
            const items = this._focusables()
            const target = items[0] || panel
            if (target) {
              target.focus()
            }
          }
          // Entrance: slide in from the anchored edge — the source's
          // data-[state=open]:slide-in-from-* over 300ms.
          if (panel && typeof panel.animate === "function") {
            const side = root.dataset.side || "right"
            const from = { right: "translateX(100%)", left: "translateX(-100%)", bottom: "translateY(100%)", top: "translateY(-100%)" }[side]
            const slide = panel.animate(
              [{ transform: from }, { transform: "none" }],
              { duration: 300, easing: "ease" }
            )
            slide.finished
              .then(() => {
                if (panel) panel.style.transform = ""
              })
              .catch(() => {})
          }
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
          const overlay = this.el.querySelector("[data-polaris-sheet-overlay]")
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

  @doc """
  The sheet section: a `px-5 py-4` band of body content — the source's
  SheetSection. Stack sections inside an `overflow-auto grow` wrapper
  for scrollable bodies.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the section.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, doc: "The section's content.")

  def sheet_section(assigns) do
    ~H"""
    <div data-polaris-sheet-section class={cn(["px-5 py-4", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The sheet close: a button firing the sheet's `on_close` — the
  source's SheetClose. Put it first in the footer with the cancel
  verb.
  """
  attr(:on_close, :string,
    required: true,
    doc: "The sheet's `on_close` event — fired on click."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the button.")
  attr(:rest, :global, doc: "Forwarded to the `<button>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The button label — a direct verb (\"Cancel\").")

  def sheet_close(assigns) do
    ~H"""
    <button
      type="button"
      data-polaris-sheet-close-button
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

  # Edge geometry per side — the source's data-[side] variants, with
  # the inner-edge border that separates the panel from the page.
  defp side_classes("top"), do: "inset-x-0 top-0 w-full border-b border-surface-border"
  defp side_classes("bottom"), do: "inset-x-0 bottom-0 w-full border-t border-surface-border"
  defp side_classes("left"), do: "inset-y-0 left-0 h-full border-r border-surface-border"
  defp side_classes("right"), do: "inset-y-0 right-0 h-full border-l border-surface-border"

  # The source's size compound variants: viewport fractions per axis.
  # Side widths are lg:-prefixed like the source (below the breakpoint
  # the width is content-driven unless `class` pins it).
  defp size_classes("top" = _side, "content"), do: "max-h-screen"
  defp size_classes("bottom" = _side, "content"), do: "max-h-screen"
  defp size_classes(_side, "content"), do: "max-w-full"

  defp size_classes("top" = _side, "default"), do: "h-1/3"
  defp size_classes("bottom" = _side, "default"), do: "h-1/3"
  defp size_classes(_side, "default"), do: "lg:w-1/3"

  defp size_classes("top" = _side, "sm"), do: "h-1/4"
  defp size_classes("bottom" = _side, "sm"), do: "h-1/4"
  defp size_classes(_side, "sm"), do: "lg:w-1/4"

  defp size_classes("top" = _side, "lg"), do: "h-1/2"
  defp size_classes("bottom" = _side, "lg"), do: "h-1/2"
  defp size_classes(_side, "lg"), do: "lg:w-1/2"

  defp size_classes("top" = _side, "xl"), do: "h-5/6"
  defp size_classes("bottom" = _side, "xl"), do: "h-5/6"
  defp size_classes(_side, "xl"), do: "lg:w-4/6"

  defp size_classes(_side, "xxl"), do: "w-5/6"

  defp size_classes("top" = _side, "full"), do: "h-screen"
  defp size_classes("bottom" = _side, "full"), do: "h-screen"
  defp size_classes(_side, "full"), do: "w-screen"

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
