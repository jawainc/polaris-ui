defmodule PolarisUI.Components.InfoTooltip do
  @moduledoc """
  The Polaris info tooltip: a bare 16px info-circle icon button that
  reveals a small explanatory panel on hover and keyboard focus — the
  port of the Supabase design system fragment
  `ui-patterns/info-tooltip` (a Radix Tooltip wired to a fixed trigger).

  Use it to answer the question a label raises but can't hold — the
  clarifier next to a form label, the term that needs one sentence of
  context. It is *not* for interactive content; that's a popover.

  ## Anatomy

      <.info_tooltip id="pool-tooltip" side="top">
        Maximum number of concurrent connections
      </.info_tooltip>

    * **trigger** — a real `<button type="button">` carrying only the
      filled info glyph (muted at rest, brightening while open and on
      hover) plus the shared focus ring. The button does nothing on
      click — tooltips open on hover/focus, not on activation.
    * **panel** — the text in a bordered, rounded panel on the base
      surface: `text-xs`, `px-3 py-1.5`, `shadow-md`, capped at a
      readable `max-w-[280px]` measure (the widest the Supabase pricing
      page uses), placed 4px off the trigger on `side`/`align`.

  ## Behavior

    * opens on **hover and focus** with no delay (the Supabase design
      site runs `delayDuration: 0` globally, so instant-open is the
      reference behavior);
    * stays open while the pointer rests on the panel content (the
      hoverable-content default);
    * closes on pointer leave, focus leave, and **Escape**;
    * a LiveView patch never snaps an open tooltip shut — the hook
      re-applies the client state after updates.

  ## Microcopy

  Per the Supabase copywriting guidelines: **one sentence maximum**,
  explaining *why* not *what* — "Restricts access based on user
  policies", never "Row Level Security restricts access based on user
  policies. When enabled, …". Sentence case.

  ## Accessibility

    * The panel renders `role="tooltip"` and the trigger carries
      `aria-describedby` pointing at it, so the text is announced when
      the trigger gains focus.
    * The trigger gets an accessible name via `label` (default
      "More info" — the fragment itself ships none, but the design
      system's own manual pattern uses `aria-label="More info"`).
    * The glyph is `aria-hidden` decoration.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @sides ~w(top right bottom left)
  @alignments ~w(start center end)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the tooltip root — required because the colocated hook
    that manages open/close state anchors on it. The panel id derives as
    `"<id>-content"` (wired to the trigger's `aria-describedby`).
    """
  )

  attr(:side, :string,
    values: @sides,
    default: "top",
    doc: "Panel placement around the trigger (the fragment default is `top`)."
  )

  attr(:align, :string,
    values: @alignments,
    default: "center",
    doc: "Cross-axis alignment of the panel against the trigger."
  )

  attr(:label, :string,
    default: "More info",
    doc: "Accessible name for the icon-only trigger (aria-label)."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the panel — caller classes win via `cn/1`."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the trigger `<button>`: `phx-click`, `phx-*`, `tabindex`,
    `data-*`, …
    """
  )

  slot(:inner_block, required: true, doc: "The tooltip text — one sentence, why not what.")

  def info_tooltip(assigns) do
    validate_in!(:side, assigns.side, @sides)
    validate_in!(:align, assigns.align, @alignments)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Tip",
        # The wrapper owns absolute placement (and therefore the z-index);
        # the panel owns the chrome and the enter animation, so the
        # centering translate and the slide translate never collide.
        position_classes: cn(["absolute z-50", side_classes(assigns.side, assigns.align)]),
        panel_classes:
          cn([
            "block w-max max-w-[280px] overflow-hidden rounded-md border border-surface-border",
            "bg-surface-base px-3 py-1.5 text-xs text-content-primary shadow-md",
            "invisible opacity-0 transition-[opacity,translate,visibility] duration-150 ease-out",
            enter_translate(assigns.side),
            "group-data-[state=open]/tooltip:visible",
            "group-data-[state=open]/tooltip:opacity-100",
            open_translate(assigns.side),
            assigns.class
          ]),
        trigger_classes:
          cn([
            "flex rounded-xs text-content-muted transition-colors hover:text-content-secondary",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "group-data-[state=open]/tooltip:text-content-secondary"
          ])
      )

    ~H"""
    <span
      id={@id}
      class="group/tooltip relative inline-flex"
      data-state="closed"
      data-side={@side}
      data-polaris-info-tooltip
      phx-hook={@hook}
    >
      <button
        type="button"
        class={@trigger_classes}
        aria-label={@label}
        aria-describedby={"#{@id}-content"}
        data-state="closed"
        data-polaris-info-tooltip-trigger
        {@rest}
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 16 16"
          fill="currentColor"
          class="size-4 transition-colors"
          aria-hidden="true"
        >
          <path
            fill-rule="evenodd"
            clip-rule="evenodd"
            d="M15 8A7 7 0 1 1 1 8a7 7 0 0 1 14 0ZM9 5a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM6.75 8a.75.75 0 0 0 0 1.5h.75v1.75a.75.75 0 0 0 1.5 0v-2.5A.75.75 0 0 0 8.25 8h-1.5Z"
          />
        </svg>
      </button>
      <span class={@position_classes} role="presentation">
        <span
          id={"#{@id}-content"}
          role="tooltip"
          class={@panel_classes}
          data-side={@side}
          data-polaris-info-tooltip-content
        >
          {render_slot(@inner_block)}
        </span>
      </span>
    </span>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Tip" runtime>
      {
        mounted() {
          const root = this.el
          this._open = root.dataset.state === "open"
          this._setOpen = (open) => {
            this._open = open
            root.dataset.state = open ? "open" : "closed"
            root.querySelectorAll("[data-polaris-info-tooltip-trigger], [data-polaris-info-tooltip-content]").forEach((el) => {
              el.dataset.state = open ? "open" : "closed"
            })
          }
          // Instant open (the design site runs delayDuration: 0) on hover and focus.
          this._onEnter = () => this._setOpen(true)
          this._onLeave = () => this._setOpen(false)
          this._onFocusOut = (event) => {
            if (!root.contains(event.relatedTarget)) {
              this._setOpen(false)
            }
          }
          this._onKeydown = (event) => {
            if (event.key === "Escape" && this._open) {
              this._setOpen(false)
            }
          }
          root.addEventListener("mouseenter", this._onEnter)
          root.addEventListener("mouseleave", this._onLeave)
          root.addEventListener("focusin", this._onEnter)
          root.addEventListener("focusout", this._onFocusOut)
          document.addEventListener("keydown", this._onKeydown)
        },
        updated() {
          // A LiveView patch resets the server-rendered data-state;
          // restore the client's current state so open tooltips stay open.
          if (this._setOpen) {
            this._setOpen(this._open)
          }
        },
        destroyed() {
          const root = this.el
          if (!root) {
            return
          }
          root.removeEventListener("mouseenter", this._onEnter)
          root.removeEventListener("mouseleave", this._onLeave)
          root.removeEventListener("focusin", this._onEnter)
          root.removeEventListener("focusout", this._onFocusOut)
          document.removeEventListener("keydown", this._onKeydown)
        }
      }
    </script>
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

  # Absolute placement 4px (one spacing unit) off the trigger per side,
  # with cross-axis alignment — the Radix sideOffset={4} / align defaults.
  defp side_classes("top", "start"), do: "bottom-full left-0 mb-1"
  defp side_classes("top", "center"), do: "bottom-full left-1/2 mb-1 -translate-x-1/2"
  defp side_classes("top", "end"), do: "bottom-full right-0 mb-1"

  defp side_classes("bottom", "start"), do: "top-full left-0 mt-1"
  defp side_classes("bottom", "center"), do: "top-full left-1/2 mt-1 -translate-x-1/2"
  defp side_classes("bottom", "end"), do: "top-full right-0 mt-1"

  defp side_classes("left", "start"), do: "right-full top-0 mr-1"
  defp side_classes("left", "center"), do: "right-full top-1/2 mr-1 -translate-y-1/2"
  defp side_classes("left", "end"), do: "bottom-0 right-full mr-1"

  defp side_classes("right", "start"), do: "left-full top-0 ml-1"
  defp side_classes("right", "center"), do: "left-full top-1/2 ml-1 -translate-y-1/2"
  defp side_classes("right", "end"), do: "bottom-0 left-full ml-1"

  # The panel slides 4px in from the active side while fading in — the
  # `data-[side=*]:slide-in-from-*` of the Supabase primitive. The axis is
  # side-specific so the closed and open translates stay on one axis and
  # `cn/1` never drops the reset.
  defp enter_translate("top"), do: "translate-y-1"
  defp enter_translate("bottom"), do: "-translate-y-1"
  defp enter_translate("left"), do: "translate-x-1"
  defp enter_translate("right"), do: "-translate-x-1"

  defp open_translate("top"), do: "group-data-[state=open]/tooltip:translate-y-0"
  defp open_translate("bottom"), do: "group-data-[state=open]/tooltip:translate-y-0"
  defp open_translate("left"), do: "group-data-[state=open]/tooltip:translate-x-0"
  defp open_translate("right"), do: "group-data-[state=open]/tooltip:translate-x-0"
end
