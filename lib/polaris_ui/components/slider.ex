defmodule PolarisUI.Components.Slider do
  @moduledoc """
  The Polaris slider: thumbs riding a 4px pill track for picking
  values or ranges — the port of the Supabase design system Slider
  (`packages/ui`, a shadcn wrapper over the Radix Slider primitive).

  ## Anatomy

      <.slider id="price" value={[200, 800]} min={0} max={1000} step={10}
               on_change="price-change" on_commit="price-commit"
               aria-label="Price range" />

    * **root** — `relative flex w-full touch-none select-none
      items-center`; the global attributes (including the label) land
      here.
    * **track** — the 4px pill (`h-1 rounded-full` on a muted border
      tone), clipped so the range follows the pill shape.
    * **range** — the filled span between the first and last thumb
      (`bg-content-secondary`, the source's muted foreground), sized
      with `left`/`right` percentages exactly like Radix.
    * **thumbs** — one 20px disc (`h-5 w-5 rounded-full border-2`)
      per value: foreground fill with a ground-color ring, the house
      focus ring, `transition-colors`. Each renders `role="slider"`
      with the full `aria-valuemin/now/max` contract and a hidden
      range input per thumb when `name` is set, so forms submit
      natively.

  ## Values, ranges, and steps

  `value` is a list — its length is the thumb count, exactly like the
  source: one value picks a point, two pick a range, and a bare
  `<.slider />` inherits the source's quirk of defaulting to the full
  `[min, max]` range. A single number is accepted and normalized.
  Values snap to `step` (Radix's `round((v - min) / step) * step +
  min`, float-safe) and clamp to `min`/`max`.

  ## Drag, keyboard, and events

  One colocated hook owns the interaction, mirroring Radix:

    * **pointer** — pressing the track jumps the *nearest* thumb and
      drags it; thumb travel is live (the thumb, range, and
      `aria-valuenow` update locally, no round-trips), then
      `on_change` **and** `on_commit` push on release.
    * **keyboard** — the focused thumb moves ±1 `step` on the arrows
      (Shift or PageUp/Down: ±10 steps), Home/End jump the first/
      last thumb to the axis ends; every press pushes both events.
    * **disabled** — thumbs drop out of the tab order, dim, and
      ignore pointers.

  Server round-trips happen only on release and keypress — dragging a
  thumb never floods the wire, and LiveView patches re-sync from the
  rendered attributes.

  ## Accessibility

  Each thumb is a `role="slider"` with `aria-valuemin`, `aria-valuenow`,
  `aria-valuemax`, and `aria-orientation`; label the group through the
  root's global attributes (`aria-label="Price range"` or
  `aria-labelledby`). Thumbs are tab stops in value order.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the slider root — required because the colocated hook
    that owns dragging and keyboarding anchors on it. Thumb ids derive
    from it (`"<id>-thumb-0"`).
    """
  )

  attr(
    :value,
    :any,
    default: nil,
    doc: """
    The thumb values, ascending — a list (`[33]`, `[20, 80]`) or a
    single number (`33`). Its length is the thumb count; omit it for
    the source's full-range default (`[min, max]`).
    """
  )

  attr(:min, :float, default: 0.0, doc: "The axis minimum. Integers coerce.")
  attr(:max, :float, default: 100.0, doc: "The axis maximum. Integers coerce.")
  attr(:step, :float, default: 1.0, doc: "The increment thumbs snap to (floats allowed).")

  attr(:disabled, :boolean,
    default: false,
    doc: "Disables every thumb: dimmed, out of the tab order, pointer-dead."
  )

  attr(:name, :string,
    default: nil,
    doc: """
    Form field name — renders one hidden range input per thumb so the
    values submit with the form, like Radix's bubble inputs.
    """
  )

  attr(:on_change, :string,
    default: nil,
    doc: """
    LiveView event pushed whenever a value settles — drag release and
    every keyboard move (`%{value: [numbers]}` payload).
    """
  )

  attr(:on_commit, :string,
    default: nil,
    doc: """
    LiveView event pushed when a drag releases — the Radix
    onValueCommit moment for expensive follow-ups.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root.")

  attr(:rest, :global,
    doc: """
    Forwarded to the root: `aria-label`, `aria-labelledby`, `data-*`, …
    """
  )

  def slider(assigns) do
    values = normalize_values(assigns)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Slider",
        values: values,
        range_style: range_style(values, assigns.min, assigns.max),
        thumbs:
          Enum.with_index(values, fn value, index ->
            %{
              index: index,
              value: value,
              now: format_number(value),
              id: "#{assigns.id}-thumb-#{index}",
              style: thumb_style(value, assigns.min, assigns.max)
            }
          end)
      )

    ~H"""
    <div
      id={@id}
      data-polaris-slider
      data-min={format_number(@min)}
      data-max={format_number(@max)}
      data-step={format_number(@step)}
      data-disabled={to_string(@disabled)}
      data-change-event={@on_change}
      data-commit-event={@on_commit}
      phx-hook={@hook}
      class={
        cn([
          "relative flex w-full touch-none select-none items-center",
          if(@disabled, do: "opacity-50 pointer-events-none"),
          @class
        ])
      }
      aria-disabled={to_string(@disabled)}
      {@rest}
    >
      <span
        data-polaris-slider-track
        class="relative h-1 w-full grow overflow-hidden rounded-full bg-surface-border"
      >
        <span
          data-polaris-slider-range
          class="absolute h-full bg-content-secondary"
          style={@range_style}
          aria-hidden="true"
        />
      </span>
      <span
        :for={{thumb, i} <- Enum.with_index(@thumbs)}
        id={thumb.id}
        data-polaris-slider-thumb
        data-index={i}
        data-value={thumb.now}
        role="slider"
        tabindex={if(@disabled, do: "-1", else: "0")}
        aria-valuemin={format_number(@min)}
        aria-valuenow={thumb.now}
        aria-valuemax={format_number(@max)}
        aria-orientation="horizontal"
        aria-disabled={to_string(@disabled)}
        style={thumb.style}
        class={
          cn([
            "absolute top-1/2 -translate-y-1/2",
            "block h-5 w-5 rounded-full border-2 border-surface-ground bg-content-primary",
            "transition-colors cursor-pointer active:scale-95",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "hover:bg-brand-emerald",
            "disabled:pointer-events-none disabled:opacity-50",
            if(@disabled, do: "cursor-default hover:bg-content-primary")
          ])
        }
      />
      <input
        :if={@name}
        :for={{thumb, _i} <- Enum.with_index(@thumbs)}
        type="range"
        name={@name}
        value={thumb.now}
        min={format_number(@min)}
        max={format_number(@max)}
        step={format_number(@step)}
        tabindex="-1"
        aria-hidden="true"
        class="hidden"
        disabled={@disabled}
      />
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Slider" runtime>
      {
        mounted() {
          this.el.addEventListener("pointerdown", (event) => this._startPointer(event))
          this.el.addEventListener("keydown", (event) => this._onKeydown(event))
        },
        // Radix snaps to the step and clamps to the axis.
        _round(value, decimals) {
          const factor = Math.pow(10, decimals)
          return Math.round(value * factor) / factor
        },
        _config() {
          const data = this.el.dataset
          const min = parseFloat(data.min)
          const max = parseFloat(data.max)
          let step = parseFloat(data.step)
          if (!(step > 0)) step = 1
          const decimals = Math.max(
            this._decimals(step),
            this._decimals(min),
            this._decimals(max)
          )
          return { min: min, max: max, step: step, decimals: decimals }
        },
        _decimals(number) {
          const text = String(number)
          const dot = text.indexOf(".")
          return dot === -1 ? 0 : text.length - dot - 1
        },
        _snap(value) {
          const config = this._config()
          const snapped =
            Math.round((value - config.min) / config.step) * config.step + config.min
          return this._round(Math.min(config.max, Math.max(config.min, snapped)), config.decimals)
        },
        _thumbValues() {
          return Array.from(this.el.querySelectorAll("[data-polaris-slider-thumb]"))
        },
        // Radix moves the thumb nearest the press.
        _nearestThumb(position) {
          const thumbs = this._thumbValues()
          let nearest = thumbs[0]
          let best = Infinity
          thumbs.forEach((thumb) => {
            const center = thumb.offsetLeft + thumb.offsetWidth / 2
            const distance = Math.abs(center - position)
            if (distance < best) {
              best = distance
              nearest = thumb
            }
          })
          return nearest
        },
        _valueFromPosition(position) {
          const config = this._config()
          const track = this.el.querySelector("[data-polaris-slider-track]")
          const bounds = track.getBoundingClientRect()
          const ratio = Math.min(1, Math.max(0, (position - bounds.left) / bounds.width))
          return this._snap(config.min + ratio * (config.max - config.min))
        },
        _startPointer(event) {
          if (this.el.dataset.disabled === "true") return
          if (event.button !== undefined && event.button !== 0) return
          const thumb =
            event.target.closest && event.target.closest("[data-polaris-slider-thumb]")
          const active = thumb || this._nearestThumb(event.clientX)
          if (!active) return
          event.preventDefault()
          const config = this._config()
          const onMove = (moveEvent) => {
            this._apply(active, this._valueFromPosition(moveEvent.clientX))
          }
          const onUp = () => {
            document.removeEventListener("pointermove", onMove)
            document.removeEventListener("pointerup", onUp)
            document.removeEventListener("pointercancel", onUp)
            this._push(this.el.dataset.changeEvent)
            this._push(this.el.dataset.commitEvent)
          }
          document.addEventListener("pointermove", onMove)
          document.addEventListener("pointerup", onUp)
          document.addEventListener("pointercancel", onUp)
          this._apply(active, this._valueFromPosition(event.clientX))
        },
        // Keyboard: arrows ±1 step (Shift/Page ±10), Home/End to the
        // axis ends, exactly the Radix contract.
        _onKeydown(event) {
          if (this.el.dataset.disabled === "true") return
          const thumb = event.target.closest && event.target.closest("[data-polaris-slider-thumb]")
          if (!thumb) return
          const config = this._config()
          const current = parseFloat(thumb.dataset.value)
          const multiplier = event.shiftKey ? 10 : 1
          let handled = true
          let next = null
          switch (event.key) {
            case "ArrowLeft":
            case "ArrowDown":
              next = current - config.step * multiplier
              break
            case "ArrowRight":
            case "ArrowUp":
              next = current + config.step * multiplier
              break
            case "PageDown":
              next = current - config.step * 10
              break
            case "PageUp":
              next = current + config.step * 10
              break
            case "Home":
              next = config.min
              break
            case "End":
              next = config.max
              break
            default:
              handled = false
          }
          if (!handled) return
          event.preventDefault()
          this._apply(thumb, this._snap(next))
          this._push(this.el.dataset.changeEvent)
          this._push(this.el.dataset.commitEvent)
        },
        // Repaint one thumb and the range, like Radix's controlled render.
        _apply(thumb, value) {
          const config = this._config()
          const span = config.max - config.min || 1
          const percent = ((value - config.min) / span) * 100
          // Radix keeps thumbs inside the track at the extremes by
          // offsetting half a thumb-width back per percent traveled.
          const offset = (percent / 100) * -(thumb.offsetWidth / 2)
          thumb.dataset.value = value
          thumb.setAttribute("aria-valuenow", String(value))
          thumb.style.left = `calc(${percent}% + ${offset}px)`
          const percents = this._thumbValues().map((node) => parseFloat(node.dataset.value))
          const singles = percents.length === 1
          const from = singles ? config.min : Math.min.apply(null, percents)
          const to = Math.max.apply(null, percents)
          const range = this.el.querySelector("[data-polaris-slider-range]")
          if (range) {
            range.style.left = `${((from - config.min) / span) * 100}%`
            range.style.right = `${100 - ((to - config.min) / span) * 100}%`
          }
          const input = this.el.querySelectorAll('input[type="range"]')[
            parseInt(thumb.dataset.index, 10)
          ]
          if (input) input.value = value
        },
        _push(name) {
          if (!name || typeof this.pushEvent !== "function") return
          const values = this._thumbValues().map((thumb) => parseFloat(thumb.dataset.value))
          this.pushEvent(name, { value: values })
        }
      }
    </script>
    """
  end

  # The source's value memo: array wins, then a lone number, else the
  # full [min, max] range — the Supabase quirk of a bare <Slider />.
  defp normalize_values(assigns) do
    cond do
      is_list(assigns.value) ->
        assigns.value

      is_number(assigns.value) ->
        [assigns.value]

      true ->
        [assigns.min, assigns.max]
    end
  end

  # The range fills from the axis start to a lone thumb, and spans the
  # first-to-last thumb for ranges — Radix's SliderRange.
  defp range_style([value], min, max) do
    span = (max - min) || 1
    right = 100.0 - clamp_percent((value - min) / span * 100)
    "left: 0%; right: #{format_number(right)}%"
  end

  defp range_style(values, min, max) do
    span = (max - min) || 1
    from = Enum.min(values)
    to = Enum.max(values)

    left = clamp_percent((from - min) / span * 100)
    right = 100.0 - clamp_percent((to - min) / span * 100)

    "left: #{format_number(left)}%; right: #{format_number(right)}%"
  end

  # Radix seats thumbs with half-a-thumb offsets so they stay inside
  # the track at the extremes.
  defp thumb_style(value, min, max) do
    span = (max - min) || 1
    percent = clamp_percent((value - min) / span * 100)
    "left: calc(#{format_number(percent)}% - #{format_number(percent / 10)}px)"
  end

  defp clamp_percent(percent) do
    percent |> max(0.0) |> min(100.0) |> Float.round(2)
  end

  # Whole numbers render without the trailing ".0" — cleaner aria values
  # and transforms.
  defp format_number(n) when is_integer(n), do: to_string(n)

  defp format_number(n) when is_float(n) do
    if n == trunc(n) do
      to_string(trunc(n))
    else
      to_string(Float.round(n, 2))
    end
  end
end
