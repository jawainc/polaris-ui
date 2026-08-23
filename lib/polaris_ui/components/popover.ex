defmodule PolarisUI.Components.Popover do
  @moduledoc """
  The Polaris popover: a floating panel anchored to a trigger — the port
  of the Supabase design system Popover (`packages/ui`, built on the
  Radix Popover primitive), and the anchoring primitive the Supabase
  Combobox and Date Picker compose from.

  ## Server-driven visibility

  Radix owns `open` client-side; in LiveView visibility belongs on the
  server, so `open` is an assign and every client-side transition —
  trigger click, Escape, click-outside — pushes `on_open_change` with
  `%{"open" => "true" | "false"}`. Your `handle_event/3` flips the
  assign and the re-render does the rest:

      def handle_event("toggle-share", %{"open" => open}, socket) do
        {:noreply, assign(socket, show_share: open == "true")}
      end

  ## Anatomy

      <.popover id="share" open={@show_share} on_open_change="toggle-share">
        <:trigger>
          <.button size="small">Share project</.button>
        </:trigger>
        <:content>
          <p class="text-sm text-content-secondary">Anyone with the link can view.</p>
        </:content>
      </.popover>

    * **root** — a `relative inline-flex` wrapper carrying the hook and
      the whole config as data attributes.
    * **trigger slot** — any clickable element; clicks inside it toggle
      the popover (the hook listens on the wrapper, so LiveView morphs
      never orphan the listener).
    * **content** — rendered only while `open`: the Supabase panel
      (`z-50 w-72 rounded-md border bg-surface-panel p-4 shadow-md`),
      absolutely positioned by the hook.

  ## Positioning

  `side` (`top`/`right`/`bottom`/`left`, default `bottom`) picks the
  edge, `align` (`start`/`center`/`end`) the cross-axis position, and
  `side_offset` (default 4px) the gap — mirroring the Radix props the
  source forwards. The hook measures the trigger and positions the
  panel, flipping to the opposite side when the viewport runs out of
  room (the Radix collision behavior, simplified). `same_width` pins
  the panel to the trigger's width — the source's
  `sameWidthAsTrigger` CSS-module trick — for dropdown-style menus.

  ## Keyboard

  The trigger keeps its native tab order; Escape closes (pushed by the
  hook). Tab moves through the content's focusables — popovers are
  non-modal by design, unlike the Dialog.

  For a panel inside a modal that must trap focus, use the Dialog; for
  hover-hint content, the Info Tooltip.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @sides ~w(top right bottom left)
  @alignments ~w(start center end)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the popover root — required because the colocated hook
    that manages toggling and positioning anchors on it.
    """
  )

  attr(:open, :boolean,
    default: false,
    doc: "Server-driven visibility. Toggle it from the `on_open_change` handler."
  )

  attr(:on_open_change, :string,
    required: true,
    doc: """
    LiveView event pushed on every client-side transition — trigger
    click, Escape, click-outside — with payload `%{"open" => "true" |
    "false"}`.
    """
  )

  attr(:side, :string,
    values: @sides,
    default: "bottom",
    doc: "Edge of the trigger the panel anchors to. The hook flips it when the viewport runs out."
  )

  attr(:align, :string,
    values: @alignments,
    default: "center",
    doc: "Cross-axis position of the panel relative to the trigger."
  )

  attr(:side_offset, :integer,
    default: 4,
    doc: "Gap between trigger and panel in pixels."
  )

  attr(:same_width, :boolean,
    default: false,
    doc: "Pin the panel to the trigger's width (the source's `sameWidthAsTrigger`)."
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the content panel — where the source's
    PopoverContent `className` lands (`p-0`, custom widths, …).
    """
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  slot(:trigger,
    required: true,
    doc: "The clickable element that toggles the popover — any markup; clicks toggle."
  )

  slot(:content, required: true, doc: "The floating panel's body.")

  def popover(assigns) do
    validate_in!(:side, assigns.side, @sides)
    validate_in!(:align, assigns.align, @alignments)

    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        state: if(assigns.open, do: "open", else: "closed"),
        content_classes:
          cn([
            "absolute z-50 w-72 rounded-md border border-surface-border",
            "bg-surface-panel p-4 text-content-primary shadow-md outline-none",
            assigns.class
          ])
      )

    ~H"""
    <div
      id={@id}
      class="relative inline-flex max-w-full"
      data-polaris-popover
      data-state={@state}
      data-open-event={@on_open_change}
      data-side={@side}
      data-align={@align}
      data-side-offset={to_string(@side_offset)}
      data-same-width={to_string(@same_width)}
      phx-hook={@hook}
      {@rest}
    >
      <span data-polaris-popover-trigger class="inline-flex max-w-full">
        {render_slot(@trigger)}
      </span>
      <div
        :if={@open}
        data-polaris-popover-content
        role="dialog"
        class={@content_classes}
      >
        {render_slot(@content)}
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          this._open = root.dataset.state === "open"

          this._push = (open) => {
            const name = root.dataset.openEvent
            if (name && typeof this.pushEvent === "function") {
              this.pushEvent(name, { open: open })
            }
          }

          this._trigger = () => root.querySelector("[data-polaris-popover-trigger]")

          this._content = () => root.querySelector("[data-polaris-popover-content]")

          // Toggle on any click inside the trigger wrapper (delegated, so
          // LiveView morphs never orphan the listener).
          this._onClick = (event) => {
            const trigger = this._trigger()
            if (trigger && trigger.contains(event.target)) {
              event.preventDefault()
              this._push(!this._open)
            }
          }
          root.addEventListener("click", this._onClick)

          this._onKeydown = (event) => {
            if (event.key === "Escape" && this._open) {
              event.preventDefault()
              this._push(false)
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)

          this._onDocumentClick = (event) => {
            if (this._open && !root.contains(event.target)) {
              this._push(false)
            }
          }
          document.addEventListener("click", this._onDocumentClick)

          if (this._open) {
            this._position()
          }
        },
        updated() {
          this._open = this.el.dataset.state === "open"
          if (this._open) {
            this._position()
          }
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onClick)
          document.removeEventListener("keydown", this._onKeydown, true)
          document.removeEventListener("click", this._onDocumentClick)
        },
        // Absolute positioning inside the relative root, measured from the
        // trigger — side/align/offset with a viewport flip, like Radix.
        _position() {
          const root = this.el
          const content = this._content()
          const trigger = this._trigger()
          if (!content || !trigger) {
            return
          }
          const side = root.dataset.side || "bottom"
          const align = root.dataset.align || "center"
          const offset = parseInt(root.dataset.sideOffset || "4", 10)
          content.style.visibility = "hidden"
          content.style.top = ""
          content.style.bottom = ""
          content.style.left = ""
          content.style.right = ""
          content.style.transform = ""
          if (root.dataset.sameWidth === "true") {
            content.style.width = trigger.offsetWidth + "px"
          }
          const place = (side) => {
            const t = trigger.offsetLeft
            const tt = trigger.offsetTop
            if (side === "bottom") {
              content.style.top = tt + trigger.offsetHeight + offset + "px"
            } else if (side === "top") {
              content.style.bottom = root.offsetHeight - tt + offset + "px"
            } else if (side === "right") {
              content.style.left = t + trigger.offsetWidth + offset + "px"
            } else {
              content.style.right = root.offsetWidth - t + offset + "px"
            }
            if (side === "bottom" || side === "top") {
              if (align === "start") {
                content.style.left = t + "px"
              } else if (align === "end") {
                content.style.left = t + trigger.offsetWidth - content.offsetWidth + "px"
              } else {
                content.style.left = t + trigger.offsetWidth / 2 + "px"
                content.style.transform = "translateX(-50%)"
              }
            } else {
              if (align === "start") {
                content.style.top = tt + "px"
              } else if (align === "end") {
                content.style.top = tt + trigger.offsetHeight - content.offsetHeight + "px"
              } else {
                content.style.top = tt + trigger.offsetHeight / 2 + "px"
                content.style.transform = "translateY(-50%)"
              }
            }
          }
          place(side)
          // Flip when the panel spills past the viewport and the opposite
          // side has more room (the Radix collision behavior, simplified).
          const rect = content.getBoundingClientRect()
          const spills = side === "bottom"
            ? rect.bottom > window.innerHeight
            : side === "top"
              ? rect.top < 0
              : side === "right"
                ? rect.right > window.innerWidth
                : rect.left < 0
          if (spills) {
            const flipped = { bottom: "top", top: "bottom", right: "left", left: "right" }[side]
            place(flipped)
          }
          content.style.visibility = ""
        }
      }
    </script>
    """
  end

  @doc """
  The popover separator: a full-width hairline for splitting panel
  sections — the source's PopoverSeparator (`w-full h-px`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the separator.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  def popover_separator(assigns) do
    ~H"""
    <div data-polaris-popover-separator class={cn(["w-full h-px bg-surface-border", @class])} {@rest} />
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
