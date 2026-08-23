defmodule PolarisUI.Components.MetricCard do
  @moduledoc """
  The Polaris metric card: a compact dashboard card pairing a labeled
  metric value with an optional differential and sparkline — the port
  of the Supabase design system compound fragment
  `ui-patterns/MetricCard`.

  ## The context → group-data port

  The React fragment threads `isLoading` / `isDisabled` from the root
  `MetricCard` down to `MetricCardValue`, `MetricCardDifferential`,
  and `MetricCardSparkline` through a React context, and each consumer
  swaps itself for a `Skeleton` in JS. This port keeps the same
  compound API but swaps **in CSS**: the root carries
  `data-loading`/`data-disabled` (the string `"true"`/`"false"`) plus
  the Tailwind `group` class, and every subcomponent renders *both*
  its skeleton and its content, toggled with `group-data-*` variants:

      skeleton → hidden group-data-[loading=true]:block
      content  → group-data-[loading=true]:hidden

  Zero JavaScript, and the swap survives LiveView patches untouched —
  flipping `loading` on the server is a one-attribute diff.

  ## Anatomy

      <.metric_card id-less root — loading/disabled drive the swap>
        <.metric_card_header href="https://...">
          <.metric_card_icon><svg … /></.metric_card_icon>
          <.metric_card_label id="users" tooltip="…">Active users</.metric_card_label>
        </.metric_card_header>
        <.metric_card_content>
          <.metric_card_value>12,480</.metric_card_value>
          <.metric_card_differential variant="positive">+4.2%</.metric_card_differential>
        </.metric_card_content>
        <.metric_card_sparkline id="users-spark" data={@series} />
      </.metric_card>

    * **root** — the card chrome: panel fill on a border, brightening
      to `bg-surface-panel-hover` on hover (the fragment's
      `group-hover:bg-surface-200`), plus the `group` +
      `data-loading`/`data-disabled` swap anchors and `aria-busy`
      while loading.
    * **header** — the label row (typically icon + label) with an
      optional chevron affordance on the right that links out when
      `href` is set, or is a plain titled `<span>` when only
      `link_tooltip` is given (the fragment renders the non-link
      variant when the whole card is already wrapped in a link —
      nesting anchors is invalid HTML, so omit `href` there).
    * **label** — the metric name in `text-sm`; an optional `tooltip`
      composes `<.info_tooltip>` (hover/focus panel) next to the
      name — see its moduledoc for the microcopy rules.
    * **content** — the value area, `flex-col` (default) or
      `flex-row` with `orientation="horizontal"`.
    * **value** — `text-xl tabular-nums` plus its `w-32 h-7`
      skeleton.
    * **differential** — the period-over-period delta, colored by
      `variant` (`positive` → emerald, `negative` → danger, default →
      secondary) plus its `w-16 h-5` skeleton.
    * **sparkline** — a server-rendered step-area SVG of the metric
      over time (see below).

  ## Sparkline

  The fragment draws a recharts step `Area` under a linear gradient.
  The port computes the geometry server-side into a `viewBox="0 0
  100 100"` SVG stretched with `preserveAspectRatio="none"`:

    * **step path** — `M x0,y0` then, per point, `L x_i,y_{i-1}
      L x_i,y_i` (recharts' `type="step"`: horizontal run, then
      vertical drop) — recharts steps *after* the point; this port
      steps *before* it, the one-pixel visual difference at the
      final sample.
    * **area** — the step path closed to the baseline, filled with a
      `linearGradient` on the brand CSS variable (`var(--color-
      brand-emerald)`, never raw hex) at `fill-opacity="0.1"`,
      mirroring the fragment's gradient-filled `fillOpacity={0.1}`
      `Area`.
    * **hover** — the recharts tooltip becomes one transparent
      `<rect>` hit area per point carrying a native `<title>`
      ("Aug 22, 10am: 4,321" — the fragment's `MMM D, h a` timestamp
      plus the group-thousands value). Port simplification: browser
      tooltips instead of the styled panel, so no hook is needed.
    * the gradient id derives as `"<id>-gradient"`, so the required
      `id` must be unique per instance.

  ## States

    * **loading** — the root's `data-loading="true"` swaps in each
      subcomponent's skeleton (value `w-32 h-7`, differential `w-16
      h-5`, sparkline full-width `h-14`) and sets `aria-busy`.
    * **disabled** — `data-disabled="true"` plus
      `pointer-events-none opacity-50` on the root (the fragment's
      `isDisabled`); drive the semantics from your LiveView.
    * **hover** — the panel fill brightens; the header chevron
      brightens from muted to secondary.
    * **empty** — `metric_card_sparkline` with `data: []` renders no
      chart, just the skeleton slot (the fragment returns `null`).

  ## Microcopy

  Labels are metric names — "Active users", "Storage used" — and the
  label tooltip explains the measurement window in one sentence:
  "The number of active users over the last 24 hours". The chevron's
  accessible name and sr-only text are both "More information".

  Zero JS by design: even the sparkline tooltips are native `<title>`
  elements, so this component ships no hook.
  """

  use PolarisUI.Component

  import PolarisUI.Components.InfoTooltip, only: [info_tooltip: 1]

  @orientations ~w(horizontal vertical)
  @differential_variants ~w(positive negative default)

  attr(:loading, :boolean,
    default: false,
    doc: """
    Swaps every subcomponent for its skeleton via the root's
    `data-loading` attribute (CSS-only) and sets `aria-busy`.
    """
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Locks the card with `pointer-events-none opacity-50` and `data-disabled`."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the card root — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the card root: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The metric card's subcomponents.")

  def metric_card(assigns) do
    assigns =
      assign(
        assigns,
        :root_classes,
        cn([
          "group flex flex-col rounded-lg border border-surface-border bg-surface-panel transition-colors hover:bg-surface-panel-hover",
          if(assigns.disabled, do: "pointer-events-none opacity-50"),
          assigns.class
        ])
      )

    ~H"""
    <div
      data-polaris-metric-card
      data-loading={to_string(@loading)}
      data-disabled={to_string(@disabled)}
      aria-busy={to_string(@loading)}
      class={@root_classes}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:href, :string,
    default: nil,
    doc: """
    Renders the header chevron as a link to this URL. Omit it (while
    keeping `link_tooltip`) when the whole card is already wrapped in
    a link — nested anchors are invalid HTML and clicks fall through
    to the wrapping link, exactly like the fragment.
    """
  )

  attr(:link_tooltip, :string,
    default: nil,
    doc: "Tooltip text for the chevron affordance; supplying it (or `href`) shows the chevron."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the header row."
  )

  attr(:rest, :global, doc: "Forwarded to the header row: `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The header's left side — typically `<.metric_card_icon>` + `<.metric_card_label>`."
  )

  def metric_card_header(assigns) do
    ~H"""
    <div
      data-polaris-metric-card-header
      class={
        cn(["relative flex flex-row items-center justify-between gap-2 border-b-0 p-4 pb-0", @class])
      }
      {@rest}
    >
      <div class="flex flex-row items-center gap-2">
        {render_slot(@inner_block)}
      </div>
      <a
        :if={@href}
        href={@href}
        title={@link_tooltip}
        aria-label="More information"
        class="absolute right-3 flex items-center rounded-xs text-content-muted transition-colors hover:text-content-secondary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"
        data-polaris-metric-card-link
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-3.5"
          aria-hidden="true"
        >
          <path d="m9 18 6-6-6-6" />
        </svg>
        <span class="sr-only">More information</span>
      </a>
      <span
        :if={is_nil(@href) and @link_tooltip}
        title={@link_tooltip}
        class="absolute right-3 flex items-center rounded-xs text-content-muted transition-colors hover:text-content-secondary"
        data-polaris-metric-card-link
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-3.5"
          aria-hidden="true"
        >
          <path d="m9 18 6-6-6-6" />
        </svg>
        <span class="sr-only">More information</span>
      </span>
    </div>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the icon wrapper.")

  attr(:rest, :global, doc: "Forwarded to the icon wrapper: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The metric's glyph (an inline SVG icon).")

  def metric_card_icon(assigns) do
    ~H"""
    <div data-polaris-metric-card-icon class={cn(["text-content-secondary", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:id, :string,
    default: nil,
    doc: """
    Unique id for the label — required only when `tooltip` is set (the
    composed `<.info_tooltip>` derives its id as `"<id>-tooltip"`).
    """
  )

  attr(:tooltip, :string,
    default: nil,
    doc: """
    Explanatory text composed into an `<.info_tooltip>` next to the
    label (one sentence, why not what). Raises without an `id`.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the label row.")

  attr(:rest, :global, doc: "Forwarded to the label row: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The metric name — e.g. \"Active users\".")

  def metric_card_label(assigns) do
    if assigns.tooltip && is_nil(assigns.id) do
      raise ArgumentError,
            "metric_card_label requires a unique id when tooltip is set — " <>
              "the composed <.info_tooltip> derives its id as \"<id>-tooltip\""
    end

    ~H"""
    <div
      data-polaris-metric-card-label
      class={cn(["flex items-center gap-2 text-sm text-content-secondary", @class])}
      {@rest}
    >
      <span>{render_slot(@inner_block)}</span>
      <.info_tooltip :if={@tooltip} id={"#{@id}-tooltip"} label="More information">
        {@tooltip}
      </.info_tooltip>
    </div>
    """
  end

  attr(:orientation, :string,
    values: @orientations,
    default: "vertical",
    doc: "`vertical` stacks the content (`flex-col`); `horizontal` lays it out in a row."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the content area.")

  attr(:rest, :global, doc: "Forwarded to the content area: `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The content — typically `<.metric_card_value>` and `<.metric_card_differential>`."
  )

  def metric_card_content(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)

    assigns =
      assign(
        assigns,
        :content_classes,
        cn([
          "flex flex-1 items-start gap-1 overflow-hidden border-b-0 p-4 pt-0",
          if(assigns.orientation == "horizontal", do: "flex-row", else: "flex-col"),
          assigns.class
        ])
      )

    ~H"""
    <div data-polaris-metric-card-content class={@content_classes} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the value text (not its skeleton)."
  )

  attr(:rest, :global, doc: "Forwarded to the value `<span>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The metric value — e.g. \"12,480\".")

  def metric_card_value(assigns) do
    ~H"""
    <div data-polaris-metric-card-value>
      <span
        data-polaris-metric-card-skeleton
        class="hidden h-7 w-32 animate-pulse rounded-sm bg-surface-panel-hover group-data-[loading=true]:block"
      ></span>
      <span
        class={cn(["text-xl font-normal tabular-nums group-data-[loading=true]:hidden", @class])}
        {@rest}
      >
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  attr(:variant, :string,
    values: @differential_variants,
    default: "default",
    doc: "`positive` → emerald, `negative` → danger, `default` → secondary text."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the differential text (not its skeleton)."
  )

  attr(:rest, :global, doc: "Forwarded to the differential `<span>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The delta — e.g. \"+4.2%\".")

  def metric_card_differential(assigns) do
    validate_in!(:variant, assigns.variant, @differential_variants)

    assigns =
      assign(
        assigns,
        :differential_classes,
        cn([
          "text-sm tabular-nums group-data-[loading=true]:hidden",
          differential_color(assigns.variant),
          assigns.class
        ])
      )

    ~H"""
    <div data-polaris-metric-card-differential>
      <span
        data-polaris-metric-card-skeleton
        class="hidden h-5 w-16 animate-pulse rounded-sm bg-surface-panel-hover group-data-[loading=true]:block"
      ></span>
      <span class={@differential_classes} {@rest}>
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  attr(:id, :string,
    required: true,
    doc: """
    Unique id per sparkline instance — the SVG gradient derives as
    `"<id>-gradient"` and must not collide with another sparkline's.
    """
  )

  attr(:data, :list,
    default: [],
    doc: """
    Point maps — `[%{value: 4321, timestamp: "2026-08-22T10:00:00Z"}]`.
    `value` may be an integer, float, or numeric string (normalized,
    defaulting to 0); atom or string keys.
    """
  )

  attr(:data_key, :any,
    default: :value,
    doc: "The key holding each point's value — atom or string (default `:value`)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the chart wrapper.")

  attr(:rest, :global, doc: "Forwarded to the chart wrapper: `data-*`, `phx-*`, …")

  def metric_card_sparkline(assigns) do
    points = spark_points(assigns.data, assigns.data_key)
    step_d = step_path(points)

    assigns =
      assigns
      |> assign(
        points: points,
        step_d: step_d,
        area_d: area_path(step_d),
        rects: hit_rects(points)
      )

    ~H"""
    <div data-polaris-metric-card-sparkline data-polaris-metric-card-sparkline-skeleton>
      <span class="hidden h-14 w-full animate-pulse bg-surface-panel-hover group-data-[loading=true]:block"></span>
      <div
        :if={@points != []}
        class={cn(["relative h-16 w-full group-data-[loading=true]:hidden", @class])}
        {@rest}
      >
        <svg
          viewBox="0 0 100 100"
          preserveAspectRatio="none"
          class="h-full w-full"
          data-polaris-metric-card-sparkline-svg
          aria-hidden="true"
        >
          <defs>
            <linearGradient id={"#{@id}-gradient"} x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stop-color="var(--color-brand-emerald)" stop-opacity="0.8" />
              <stop offset="95%" stop-color="var(--color-brand-emerald)" stop-opacity="0" />
            </linearGradient>
          </defs>
          <path d={@area_d} fill={"url(##{@id}-gradient)"} fill-opacity="0.1"></path>
          <path
            d={@step_d}
            fill="none"
            stroke="var(--color-brand-emerald)"
            stroke-width="1.5"
            vector-effect="non-scaling-stroke"
          >
          </path>
          <rect
            :for={rect <- @rects}
            x={rect.x}
            y="0"
            width={rect.width}
            height="100"
            fill="transparent"
          >
            <title>{rect.title}</title>
          </rect>
        </svg>
      </div>
    </div>
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

  defp differential_color("positive"), do: "text-brand-emerald"
  defp differential_color("negative"), do: "text-danger"
  defp differential_color("default"), do: "text-content-secondary"

  ## Sparkline geometry

  # Evenly spaced x (0..100), y inverted so the largest value peaks at
  # the top (max guarded to 1 so flat-zero series never divide by 0).
  defp spark_points(data, data_key) do
    values = Enum.map(data, &to_number(point_value(&1, data_key)))
    n = length(values)
    step = 100 / max(n - 1, 1)
    max_value = values |> Enum.max(fn -> 0 end) |> max(1)

    data
    |> Enum.with_index()
    |> Enum.map(fn {point, i} ->
      value = Enum.at(values, i)

      %{
        x: i * step,
        y: 100 - value / max_value * 100,
        value: value,
        timestamp: point |> point_value(:timestamp) |> timestamp_string()
      }
    end)
  end

  # recharts `type="step"`: run horizontally at the previous y, then
  # drop/rise vertically to the new y.
  defp step_path([]), do: ""

  defp step_path([first | rest]) do
    {d, _last} =
      Enum.reduce(
        rest,
        {"M #{fmt_num(first.x)},#{fmt_num(first.y)}", first},
        fn point, {acc, prev} ->
          {
            "#{acc} L #{fmt_num(point.x)},#{fmt_num(prev.y)} L #{fmt_num(point.x)},#{fmt_num(point.y)}",
            point
          }
        end
      )

    d
  end

  # The step line closed along the baseline.
  defp area_path(step_d), do: step_d <> " L 100,100 L 0,100 Z"

  # One transparent hit rect per point (halved at the edges so the
  # first and last stay inside the viewBox), carrying the native
  # <title> tooltip: "<MMM D, h a timestamp>: <grouped value>" — the
  # fragment's SparklineTooltip copy.
  defp hit_rects(points) do
    n = length(points)
    step = 100 / max(n - 1, 1)

    points
    |> Enum.with_index()
    |> Enum.map(fn {point, i} ->
      {x, width} =
        cond do
          i == 0 -> {0.0, step / 2}
          i == n - 1 -> {100 - step / 2, step / 2}
          true -> {point.x - step / 2, step}
        end

      %{
        x: fmt_num(x),
        width: fmt_num(width),
        title: "#{format_spark_timestamp(point.timestamp)}: #{format_number(point.value)}"
      }
    end)
  end

  # The fragment's SparklineTooltip formatTimestamp: dayjs 'MMM D'
  # (unpadded day) plus an unpadded 12-hour clock with lowercase
  # meridiem — "Aug 22, 10am".
  defp format_spark_timestamp(timestamp) do
    case parse_datetime(timestamp) do
      nil ->
        timestamp

      datetime ->
        hour = rem(datetime.hour, 12)
        display_hour = if hour == 0, do: 12, else: hour

        "#{Calendar.strftime(datetime, "%b")} #{datetime.day}, #{display_hour}#{meridiem(datetime.hour)}"
    end
  end

  defp meridiem(hour) when hour < 12, do: "am"
  defp meridiem(_hour), do: "pm"

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        DateTime.to_naive(datetime)

      _ ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, naive} -> naive
          _ -> nil
        end
    end
  end

  defp parse_datetime(_), do: nil

  # Group-thousands like the fragment's
  # value.toLocaleString({ maximumFractionDigits: 0 }) — "4,321".
  defp format_number(value) when is_integer(value),
    do: value |> Integer.to_string() |> group_thousands()

  defp format_number(value) when is_float(value),
    do: value |> round() |> Integer.to_string() |> group_thousands()

  defp format_number(value), do: to_string(value)

  defp group_thousands(string),
    do: Regex.replace(~r/(\d)(?=(\d{3})+$)/, string, "\\1,")

  # Two-decimal, zero-trimmed numbers so path/rect geometry stays
  # readable ("50" not "50.0", "13.58" not "13.579999999999998").
  defp fmt_num(value) when is_integer(value), do: Integer.to_string(value)

  defp fmt_num(value) when is_float(value) do
    value
    |> :erlang.float_to_binary(decimals: 2)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  ## Normalization

  # Atom- or string-keyed fetch (data_key may arrive as either).
  defp point_value(map, key) when is_map(map) do
    case Map.get(map, key) do
      nil -> Map.get(map, to_string(key))
      value -> value
    end
  end

  defp point_value(_other, _key), do: nil

  defp to_number(value) when is_integer(value), do: value
  defp to_number(value) when is_float(value), do: value

  defp to_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        int

      _ ->
        case Float.parse(value) do
          {float, ""} -> float
          _ -> 0
        end
    end
  end

  defp to_number(_), do: 0

  defp timestamp_string(value) when is_binary(value), do: value
  defp timestamp_string(nil), do: ""
  defp timestamp_string(value), do: to_string(value)
end
