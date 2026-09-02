defmodule PolarisUI.Components.Toggle do
  @moduledoc """
  The Polaris toggle: a standalone two-state trigger — the port of the
  Supabase design system Toggle (`packages/ui`, a shadcn wrapper over
  the Radix Toggle): an `aria-pressed` button that flips an immediate,
  reversible setting such as bold text or a live filter.

  ## Anatomy

      <.toggle id="bold" value="bold" on_change="toggle-bold">
        Bold
      </.toggle>

    A single `<button type="button" aria-pressed>` carrying
    `data-state="on" | "off"` — the source's `toggleVariants` class
    contract: a ghost button (transparent at rest, muted wash on hover
    and when on) with an optional outline variant, on the shared size
    scale. The inner block is the toggle's content (text, an icon, or
    both — the base carries `gap-1`).

  ## State model

    Pressing is **client-side**, like Radix: the colocated runtime hook
    owns the state machine — off → on → off — mirroring `data-state`
    and `aria-pressed`, and optionally pushing `on_change`
    (`%{"state" => "on" | "off", "value" => value}`) to the server. The
    hook re-applies its state after LiveView patches, so presses
    survive re-renders without a round trip.

    The Radix Toggle has **no form participation by design** — there is
    no hidden input. It is an instant, reversible control whose state
    should live in your UI state (or be pushed via `on_change`), not in
    a form payload. Use `switch` or `checkbox` inside forms. There is
    also **no loading state** — a toggle is instant; gate it with
    `disabled` while the consequence is in flight.

  ## Variants

    * **default** — the ghost: `bg-transparent` at rest with the muted
      hover wash (`hover:bg-surface-muted`, the source's `hover:bg-muted`),
      flipping to `bg-surface-muted` / `text-content-primary` when on
      (the source's `bg-accent` / `text-foreground`).
    * **outline** — the same ghost with a `border-surface-border` frame
      (the source's `border-control`) that brightens to
      `border-surface-border-hover` when on for high-contrast "pressed"
      feedback.

  ## Sizes

    The source's shared scale (default `default`):

    | Size | Height | Padding | Text |
    |------|--------|---------|------|
    | `tiny` | 26px | `px-2.5` | `text-xs` |
    | `default` | 40px (`h-10`) | `px-3` | `text-sm` |
    | `sm` | 34px | `px-2.5` | `text-sm` |
    | `lg` | 44px (`h-11`) | `px-5` | `text-sm` |

  ## Accessibility

    * The button carries `aria-pressed="true" | "false"` — the toggle
      semantic assistive tech announces as "pressed"/"not pressed";
      `Enter`/`Space` press it (native button behavior). The classes
      mirror `data-[state=on]` under `aria-[pressed=true]` too, so the
      paint follows the attribute alone (the source's `aria-checked:`
      parity).
    * Give icon-only toggles an accessible name via `aria-label`
      through the global attributes.
    * Disabled toggles drop their pointer events and dim to 50% — they
      stay out of the tab order natively.

  ## Microcopy

    Label the immediate effect with a concise adjective or verb
    ("Bold", "Mute") — never a sentence. Group related toggles with
    `toggle_group` instead of suffixing labels with "on/off".

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @variants ~w(default outline)
  @sizes ~w(tiny default sm lg)

  # The source's toggleVariants base, expanded: the focus-ring utility
  # becomes the shared emerald ring and `text-foreground-light` /
  # `bg-accent` map to the Polaris palette.
  defp base_classes do
    [
      "inline-flex items-center justify-center gap-1 rounded-md text-sm font-medium",
      "transition-colors text-content-secondary hover:text-content-primary hover:bg-surface-muted",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
      "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
      "disabled:pointer-events-none disabled:opacity-50",
      "px-3 py-1 h-auto"
    ]
  end

  # The source's variant classes; both keep the transparent rest fill
  # (the base's hover wash and on-state treatments are shared), outline
  # adds the frame and brightens it when on.
  defp variant_classes("default") do
    [
      "bg-transparent",
      "data-[state=on]:bg-surface-muted data-[state=on]:text-content-primary",
      "aria-[pressed=true]:bg-surface-muted aria-[pressed=true]:text-content-primary"
    ]
  end

  defp variant_classes("outline") do
    [
      "bg-transparent border border-surface-border",
      "data-[state=on]:bg-surface-muted data-[state=on]:text-content-primary",
      "data-[state=on]:border-surface-border-hover",
      "aria-[pressed=true]:bg-surface-muted aria-[pressed=true]:text-content-primary",
      "aria-[pressed=true]:border-surface-border-hover"
    ]
  end

  # The source's size scale (toggle.tsx), overriding the base h-auto/px-3.
  defp size_classes("tiny"), do: "h-[26px] px-2.5 text-xs"
  defp size_classes("default"), do: "h-10 px-3"
  defp size_classes("sm"), do: "h-[34px] px-2.5"
  defp size_classes("lg"), do: "h-11 px-5"

  @doc """
  Renders the toggle.
  """
  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the toggle button — required because the colocated hook
    that owns the pressed state anchors on it.
    """
  )

  attr(:value, :string,
    default: "on",
    doc: "The value mirrored into the `on_change` payload."
  )

  attr(:pressed, :boolean,
    default: false,
    doc: "Initial pressed state (the hook owns presses from then on)."
  )

  attr(:variant, :string,
    values: @variants,
    default: "default",
    doc: "The source's two treatments — the ghost `default` or the framed `outline`."
  )

  attr(:size, :string,
    values: @sizes,
    default: "default",
    doc: "The source's shared size scale — `default` (h-10) is the Supabase default."
  )

  attr(:disabled, :boolean, default: false, doc: "Blocks presses and dims the toggle.")

  attr(:on_change, :string,
    default: nil,
    doc: """
    Optional LiveView event pushed on every press with
    `%{"state" => "on" | "off", "value" => value}`.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the button (e.g. `h-9`)."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the button: `aria-label`, `aria-describedby`,
    `phx-click`, `data-*`, …
    """
  )

  slot(:inner_block,
    required: true,
    doc: "The toggle's content — a concise label, an icon, or both."
  )

  def toggle(assigns) do
    validate_in!(:variant, assigns.variant, @variants)
    validate_in!(:size, assigns.size, @sizes)

    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        state: if(assigns.pressed, do: "on", else: "off"),
        aria_pressed: to_string(assigns.pressed)
      )

    ~H"""
    <button
      type="button"
      id={@id}
      aria-pressed={@aria_pressed}
      data-polaris-toggle
      data-state={@state}
      data-value={@value}
      data-change-event={@on_change}
      disabled={@disabled}
      tabindex={if(@disabled, do: "-1", else: "0")}
      class={cn([base_classes(), variant_classes(@variant), size_classes(@size), @class])}
      phx-hook={@hook}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          this._state = this.el.dataset.state || "off"
          this._onClick = () => this._toggle()
          this.el.addEventListener("click", this._onClick)
        },
        updated() {
          // LiveView patches may stomp data-state/aria; re-apply.
          this._apply()
        },
        destroyed() {
          this.el.removeEventListener("click", this._onClick)
        },
        _toggle() {
          // The Radix cycle: on switches off, off switches on.
          this._state = this._state === "on" ? "off" : "on"
          this._apply()
          const name = this.el.dataset.changeEvent
          if (name && typeof this.pushEvent === "function") {
            this.pushEvent(name, { state: this._state, value: this.el.dataset.value })
          }
        },
        _apply() {
          this.el.dataset.state = this._state
          this.el.setAttribute("aria-pressed", this._state === "on" ? "true" : "false")
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
