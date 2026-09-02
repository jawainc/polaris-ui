defmodule PolarisUI.Components.Switch do
  @moduledoc """
  The Polaris switch: the two-state instant toggle — the port of the
  Supabase design system Switch (`packages/ui`, a shadcn wrapper over
  the Radix Switch).

  ## Anatomy

      <.switch id="desktop-notifications" name="notifications" on_change="toggle-notifications">
        Desktop notifications
      </.switch>

    * **track** — the pill-shaped root: a `role="switch"` button that
      fills with brand emerald when checked (the source's
      `data-[state=checked]:bg-brand`) and falls back to the panel
      surface when unchecked.
    * **thumb** — the translating knob: `pointer-events-none`, dark
      (`bg-content-primary`, the source's `bg-foreground-lighter`) when
      unchecked and white when checked, sliding along the track via
      `data-state` translate utilities read off the track.
    * **label** — the inner block renders into a `<label for>` wired to
      the track, dimming alongside it.
    * **hidden input** — with `name` set, a visually-hidden native
      checkbox carries the value into form submissions, kept in sync by
      the hook (the Radix form-participation pattern).

  ## State model

    Toggling is **client-side**, like Radix: the colocated runtime hook
    owns the state machine — unchecked → checked → unchecked — then
    syncs the hidden input (dispatching bubbling `input`/`change` so
    `phx-change` forms observe the toggle) and optionally mirrors the
    toggle to the server via `on_change` (`%{"state" => "checked" |
    "unchecked", "value" => value}`). The hook re-applies its state
    after LiveView patches, so toggles survive re-renders without a
    round trip. There is **no loading state** — a switch is an instant
    control; gate it with `disabled` while its consequence is in
    flight.

  ## Sizes

    The source's three-track scale (default `medium`):

    | Size | Track | Thumb | Checked travel |
    |------|-------|-------|----------------|
    | `small` | 16px × 28px | 12px | `translate-x-[13px]` |
    | `medium` (default) | 20px × 34px | 16px | `translate-x-[15px]` |
    | `large` | 24px × 44px | 18px | `translate-x-[22px]` |

  ## States

    * **rest / hover** — the unchecked track is the panel surface
      (the source's `bg-control`) brightening to the border surface on
      hover; the checked track is brand emerald with its hover twin
      (the source's `bg-brand` / `bg-brand-600/90`).
    * **focus-ring** — high-visibility emerald ring on `:focus-visible`
      only, with offset from the ground surface.
    * **checked** — `data-state="checked"` / `aria-checked="true"`: the
      emerald track with the white thumb slid right; the thumb eases on
      `transition-transform` and skips the motion under
      `motion-reduce`.
    * **disabled** — native `disabled`, `tabindex="-1"` (the Supabase
      Safari fix), `cursor-not-allowed` at 50% opacity; the label dims
      through the `peer` relationship.

  ## Accessibility

    * The track is a `<button role="switch">` carrying `aria-checked`;
      `Enter`/`Space` toggle (native button behavior) and the paired
      `<label for>` gives it an accessible name — clicking the label
      activates the switch.
    * The thumb is `aria-hidden` decoration; the button is the single
      keyboard/assistive face, and the hidden input stays `sr-only` and
      out of the tab order.
    * Forward `aria-describedby` through the global attributes to wire
      field-level validation.

  ## Microcopy

    Label the setting itself ("Desktop notifications"), never the
    mechanics ("Turn on desktop notifications") — the control already
    shows its state.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @sizes ~w(small medium large)

  # The source's switchRootVariants size scale (switch.tsx).
  defp root_size_classes("small"), do: "h-[16px] w-[28px]"
  defp root_size_classes("medium"), do: "h-[20px] w-[34px]"
  defp root_size_classes("large"), do: "h-[24px] w-[44px]"

  # The source's switchThumbVariants: knob size + per-state translate.
  # The thumb reads the track's data-state (the Radix Thumb mirrors the
  # Root), here via group-data selectors so the hook only syncs the root.
  defp thumb_size_classes("small"),
    do:
      "h-[12px] w-[12px] group-data-[state=checked]:translate-x-[13px] group-data-[state=unchecked]:translate-x-px"

  defp thumb_size_classes("medium"),
    do:
      "h-[16px] w-[16px] group-data-[state=checked]:translate-x-[15px] group-data-[state=unchecked]:translate-x-px"

  defp thumb_size_classes("large"),
    do:
      "h-[18px] w-[18px] group-data-[state=checked]:translate-x-[22px] group-data-[state=unchecked]:translate-x-[3px]"

  @doc """
  Renders the switch.
  """
  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the switch track — required because the colocated hook
    that owns the state anchors on it. The label derives
    `"<id>-label"` for the `aria-labelledby` wiring.
    """
  )

  attr(:name, :string,
    default: nil,
    doc: """
    Form field name — renders the hidden native checkbox that carries the
    value into form submissions (omit for purely interactive toggles).
    """
  )

  attr(:value, :string, default: "on", doc: "Value submitted with the form when checked.")

  attr(:checked, :boolean,
    default: false,
    doc: "Initial checked state (the hook owns toggles from then on)."
  )

  attr(:disabled, :boolean, default: false, doc: "Disables the track and dims the label.")

  attr(:size, :string,
    values: @sizes,
    default: "medium",
    doc: "The source's track scale — `medium` (20px) is the Supabase default."
  )

  attr(:on_change, :string,
    default: nil,
    doc: """
    Optional LiveView event pushed on every toggle with
    `%{"state" => "checked" | "unchecked", "value" => value}`.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the track (e.g. `h-6 w-10`)."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the switch button: `phx-click`, `aria-describedby`,
    `data-*`, …
    """
  )

  slot(:inner_block,
    doc: "Label text — the setting itself (\"Desktop notifications\")."
  )

  def switch(assigns) do
    validate_in!(:size, assigns.size, @sizes)

    state = if(assigns.checked, do: "checked", else: "unchecked")

    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        state: state,
        aria_checked: to_string(assigns.checked),
        has_label: assigns.inner_block != []
      )

    ~H"""
    <div class="flex items-center gap-2" data-polaris-switch>
      <button
        type="button"
        role="switch"
        id={@id}
        aria-checked={@aria_checked}
        aria-labelledby={@has_label && "#{@id}-label"}
        data-polaris-switch-root
        data-state={@state}
        data-value={@value}
        data-change-event={@on_change}
        disabled={@disabled}
        tabindex={if(@disabled, do: "-1", else: "0")}
        class={
          cn([
            "peer group inline-flex shrink-0 cursor-pointer items-center rounded-full border",
            "transition-colors",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "disabled:cursor-not-allowed disabled:opacity-50",
            "data-[state=checked]:bg-brand-emerald data-[state=checked]:hover:bg-brand-emerald-hover",
            "data-[state=unchecked]:bg-surface-panel data-[state=unchecked]:hover:bg-surface-border-hover",
            root_size_classes(@size),
            @class
          ])
        }
        phx-hook={@hook}
        {@rest}
      >
        <span
          data-polaris-switch-thumb
          aria-hidden="true"
          class={
            cn([
              "pointer-events-none block rounded-full bg-content-primary group-data-[state=checked]:bg-white",
              "shadow-lg ring-0 transition-transform motion-reduce:transition-none",
              thumb_size_classes(@size)
            ])
          }
        >
        </span>
      </button>
      <input
        :if={@name}
        type="checkbox"
        name={@name}
        value={@value}
        checked={@checked}
        tabindex="-1"
        class="sr-only"
        data-polaris-switch-input
      />
      <label
        :if={@has_label}
        for={@id}
        id={"#{@id}-label"}
        class="cursor-pointer text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
      >
        {render_slot(@inner_block)}
      </label>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          this._state = this.el.dataset.state || "unchecked"
          this._input = this.el.parentElement.querySelector("[data-polaris-switch-input]")
          this._onClick = () => this._toggle()
          this.el.addEventListener("click", this._onClick)
          this._syncInput()
        },
        updated() {
          // LiveView patches may stomp data-state/aria; re-apply.
          this._apply()
          this._syncInput()
        },
        destroyed() {
          this.el.removeEventListener("click", this._onClick)
        },
        _toggle() {
          // The Radix cycle: checked checks out, unchecked checks in.
          this._state = this._state === "checked" ? "unchecked" : "checked"
          this._apply()
          this._syncInput()
          if (this._input) {
            // Bubble through the hidden input so phx-change forms observe the toggle.
            this._input.dispatchEvent(new Event("input", { bubbles: true }))
            this._input.dispatchEvent(new Event("change", { bubbles: true }))
          }
          const name = this.el.dataset.changeEvent
          if (name && typeof this.pushEvent === "function") {
            this.pushEvent(name, { state: this._state, value: this.el.dataset.value })
          }
        },
        _apply() {
          this.el.dataset.state = this._state
          this.el.setAttribute("aria-checked", this._state === "checked" ? "true" : "false")
        },
        _syncInput() {
          if (!this._input) return
          this._input.checked = this._state === "checked"
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
end
