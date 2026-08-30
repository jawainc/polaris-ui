defmodule PolarisUI.Components.Progress do
  @moduledoc """
  The Polaris progress bar: an indicator showing the completion progress
  of a task — the port of the Supabase design system Progress
  (`packages/ui`, a shadcn wrapper over the Radix Progress primitive).

  ## Anatomy

      <.progress value={66} />

    * **track** — the 4px pill (`h-1 w-full overflow-hidden rounded-full`)
      on a muted surface tone (the source's `bg-surface-300`).
    * **indicator** — the bright fill (`bg-foreground` →
      `bg-content-primary`) translating across the track: the source
      drives it with `transform: translateX(-\#{100 - value}%)`, which
      this port computes server-side from `value`/`max`, with
      `transition-all` smoothing value changes.

  ## Determinate vs indeterminate

  With `value`, the bar is **determinate**: pass the live completion
  percentage from your server state (uploads, migrations, quota usage)
  and the cross-fading indicator animates between renders — the loading
  state is the component itself, like the source's demo ticking 13 → 66.

  With `value` left `nil`, duration is unknown: the bar renders the
  Radix `data-state="indeterminate"` contract with the fill parked
  off-track and `aria-valuenow` omitted. With `indeterminate`, the
  indicator becomes a half-width segment sweeping the track on the
  `progress-indeterminate` keyframes (added to `PolarisUI.Tokens`) —
  the loading state for work that ticks without a percentage.

  ## Accessibility

  The track is the `role="progressbar"` face: `aria-valuemin`/`aria-valuemax`
  derive from `max` and `aria-valuenow` from `value` (omitted when
  unknown, per the ARIA pattern). Forward `aria-labelledby` (or
  `aria-label`) through the global attributes to name the task — the
  Radix `getValueLabel` formatting has no static equivalent, so pass
  `aria-valuetext="3 of 5 tables"` for human-readable progress.

  No colocated hook is required: the fill is a pure server-rendered
  transform, so progress updates ride ordinary LiveView patches.
  """

  use PolarisUI.Component

  attr(
    :value,
    :float,
    default: nil,
    doc: """
    Current completion (0 to `max`) — the percentage the fill covers.
    Integers coerce. Omit for an unknown-duration bar (renders empty
    unless `indeterminate`).
    """
  )

  attr(:max, :float,
    default: 100.0,
    doc: "The value that means 100% complete (e.g. `60` for seconds elapsed of a minute)."
  )

  attr(
    :indeterminate,
    :boolean,
    default: false,
    doc: "Sweep a half-width segment across the track — for work with no known duration."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the track (`w-[60%]`, `h-2`, …)."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the track: `aria-label`, `aria-labelledby`,
    `aria-valuetext`, `data-*`, …
    """
  )

  def progress(assigns) do
    # Radix marks value-less progress "indeterminate"; the sweep animation
    # itself only runs when asked for explicitly.
    unknown_duration = is_nil(assigns.value) or assigns.indeterminate
    sweeping = assigns.indeterminate

    percent =
      if is_nil(assigns.value) do
        0.0
      else
        assigns.value
        |> Kernel./(if(assigns.max == 0, do: 1, else: assigns.max))
        |> Kernel.*(100.0)
        |> max(0.0)
        |> min(100.0)
        |> Float.round(2)
      end

    assigns =
      assign(assigns,
        state: if(unknown_duration, do: "indeterminate", else: "determinate"),
        max_label: format_number(assigns.max),
        now: if(is_nil(assigns.value), do: nil, else: assigns.value),
        indicator_classes:
          cn([
            "h-full w-full flex-1 bg-content-primary transition-all",
            # The sweep only reads with a partial segment under it.
            if(sweeping, do: "w-1/2 animate-progress-indeterminate")
          ]),
        indicator_style:
          cond do
            sweeping -> nil
            is_nil(assigns.value) -> "transform: translateX(-100%)"
            true -> "transform: translateX(-#{format_number(100.0 - percent)}%)"
          end
      )

    ~H"""
    <div
      role="progressbar"
      aria-valuemin="0"
      aria-valuemax={@max_label}
      aria-valuenow={@now && format_number(@now)}
      data-polaris-progress
      data-state={@state}
      data-value={@now && format_number(@now)}
      class={
        cn([
          "relative h-1 w-full overflow-hidden rounded-full bg-surface-border",
          @class
        ])
      }
      {@rest}
    >
      <div
        data-polaris-progress-indicator
        class={@indicator_classes}
        style={@indicator_style}
        aria-hidden="true"
      />
    </div>
    """
  end

  # Whole numbers render without the trailing ".0" — cleaner aria values
  # and transforms (translateX(-34%), not translateX(-34.0%)).
  defp format_number(n) when is_integer(n), do: to_string(n)

  defp format_number(n) when is_float(n) do
    if n == trunc(n) do
      to_string(trunc(n))
    else
      to_string(Float.round(n, 2))
    end
  end
end
