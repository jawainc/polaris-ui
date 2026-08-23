defmodule PolarisUI.Components.LogsBarChart do
  @moduledoc """
  The Polaris logs bar chart: a compact stacked-bar timeline of log
  volume — error, warning, and ok counts per time bucket — the port of
  the Supabase design system fragment `ui-patterns/LogsBarChart`.

  The React fragment renders a recharts stacked `BarChart` with
  hover-focus dimming, a chart tooltip, and click-to-filter. LiveView
  owns the data, so this port renders the chart **on the server** —
  one flex column per time bucket, one percentage-height div per
  series segment — and wires the interactivity through a colocated
  hook that only toggles classes and pushes events:

    * **stacking** — recharts stacks `Bar`s in declaration order with
      the *first* declared at the bottom: error (red), then warning
      (yellow), then ok (green). A flex column lays out its first
      child at the *top*, so segments are declared ok → warning →
      error to reproduce the fragment's stack: ok on top, error at
      the baseline. Zero-count segments are skipped entirely —
      recharts would draw a zero-height rect, here the div simply
      does not exist.
    * **hover focus** — hovering a column reveals that column's
      server-rendered tooltip and dims every *other* column with
      `opacity-40` (the fragment dims non-active cells via recharts'
      active-tooltip state); moving away reverses both.
    * **tooltip** — one panel per column, rendered server-side and
      shown by the hook. It always carries the formatted timestamp
      plus one line per series (`Errors: 2`, `Warnings: 1`, `Ok: 40`).
      With `hide_zero_values` the zero-count lines are omitted, and
      when no line would render the panel carries `data-empty` so the
      hook skips showing it — the fragment's "don't show tooltip if
      all values are filtered out".
    * **click** — clicking a column pushes `on_bar_click` with
      `%{index, timestamp}` — the LiveView replacement for the
      fragment's `onBarClick(datum)` callback.

  The fragment's `maxBarSize={24}` cap is not ported: buckets share
  the row as equal `flex-1` columns separated by `gap-px`, which
  matches how the chart reads at the fragment's own demo density
  (100 buckets in a `h-24` strip).

  ## Anatomy

      <.logs_bar_chart
        id="logs-chart"
        data={@log_buckets}
        on_bar_click="select-bucket"
      />

    * **wrapper** — the `id`/hook anchor; `h-24` (or `h-full` with
      `is_full_height`) with `gap-y-3` between the chart row and the
      date range.
    * **chart row** — `flex items-end gap-px`: one column per datum,
      each `flex-1` with segments percentage-sized against the
      largest bucket total (guarded to a minimum of 1 so all-zero
      data still renders columns).
    * **tooltip** — absolutely positioned above its column, hidden
      until hover; `pointer-events-none`, `z-50`.
    * **date range row** — first/last timestamps formatted with
      `datetime_format`, `font-mono text-[10px]`, one span per edge.

  ## Data shape

      [%{timestamp: "2026-08-22T10:00:00Z",
         error_count: 2, warning_count: 1, ok_count: 40}, ...]

  Counts may be integers, floats, or numeric strings (`"2"` —
  normalized, defaulting to 0 for missing/unparseable values), with
  atom or string keys. Buckets render in list order; the date range
  assumes they are sorted ascending like the fragment's.

  ## States

    * **empty** — `data: []` renders the optional `empty_state` slot
      instead of the chart (nothing when the slot is absent), like
      the fragment's `EmptyState` prop.
    * **error** — a truthy `error` renders the optional `error_state`
      slot instead (nothing when absent), like `ErrorState`. Error
      wins over empty, matching the fragment's check order. Note
      Elixir truthiness: `""` counts as an error here, unlike JS.
    * **hover** — the hovered column keeps full opacity while the
      others dim to `opacity-40`; its tooltip appears above it.

  The wrapper (with its `id` and hook) renders in every state so
  LiveView morphs always have a stable anchor when the server swaps
  error → empty → chart — the React fragment instead returns the
  slot content bare.

  ## Accessibility

  Columns are pointer targets (like recharts bars, they are not
  keyboard-focusable); the tooltip content is plain DOM so it reads
  out in the accessibility tree, but pair the chart with a data
  table or per-bucket links when the counts matter to keyboard and
  screen-reader users.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`). All listeners are delegated
  from the wrapper root, so LiveView morphs that replace columns or
  tooltips wholesale never orphan them.
  """

  use PolarisUI.Component

  # The visual stack, TOP segment first. A recharts stack renders the
  # first-declared Bar at the BOTTOM (error → warning → ok); a flex
  # column renders its first child at the TOP, so ok → warning → error
  # is the declaration order that reproduces the fragment's stack.
  @segments [
    {:ok_count, "bg-brand-emerald"},
    {:warning_count, "bg-warning"},
    {:error_count, "bg-danger"}
  ]

  # Tooltip lines follow the fragment's Bar (payload) order, with the
  # labels from its default chart config.
  @tooltip_series [
    {:error_count, "Errors"},
    {:warning_count, "Warnings"},
    {:ok_count, "Ok"}
  ]

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the chart root — required because the colocated hook
    that manages hover dimming, tooltips, and click events anchors on it.
    """
  )

  attr(:data, :list,
    required: true,
    doc: """
    Bucket maps — `%{timestamp: "2026-08-22T10:00:00Z", error_count: 2,
    warning_count: 1, ok_count: 40}` (ISO8601 timestamps; counts may be
    integers, floats, or numeric strings, normalized with a 0 default;
    atom or string keys).
    """
  )

  attr(:on_bar_click, :string,
    default: nil,
    doc: "LiveView event pushed on column click with `%{index, timestamp}`."
  )

  attr(:datetime_format, :string,
    default: "%b %d, %Y, %I:%M %p",
    doc: """
    `Calendar.strftime` format for the date-range row and tooltip
    timestamps. The default renders "Aug 22, 2026, 10:00 AM" and ports
    the fragment's dayjs default `'MMM D, YYYY, hh:mma'` ("Aug 22,
    2026, 10:00am"); the divergences are Elixir's zero-padded day
    (`%d` → "Aug 05" where dayjs `D` renders "Aug 5") and uppercase
    meridiem (`%p` → "AM" where dayjs `a` renders "am" — use `%P` for
    lowercase).
    """
  )

  attr(:is_full_height, :boolean,
    default: false,
    doc: "Stretch the wrapper to `h-full` instead of the fragment's fixed `h-24`."
  )

  attr(:hide_zero_values, :boolean,
    default: false,
    doc: """
    Omit zero-count series lines from the tooltip; a bucket whose three
    counts are all zero gets a `data-empty` tooltip the hook never shows.
    """
  )

  attr(:hide_date_range, :boolean,
    default: false,
    doc: "Hide the first/last timestamp row under the chart."
  )

  attr(:error, :any,
    default: nil,
    doc: """
    Any truthy term renders the `error_state` slot instead of the chart
    (nothing when the slot is absent) — the fragment's `ErrorState`.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the wrapper — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the wrapper: `data-*`, `phx-*`, …")

  slot(:empty_state,
    doc: "Rendered inside the wrapper instead of the chart when `data` is `[]`."
  )

  slot(:error_state,
    doc: "Rendered inside the wrapper instead of the chart when `error` is truthy."
  )

  def logs_bar_chart(assigns) do
    data = normalize_data(assigns.data)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Chart",
        data: data,
        max_total: max_total(data),
        segments: @segments,
        tooltip_series: @tooltip_series,
        wrapper_classes:
          cn([
            "flex flex-col gap-y-3",
            if(assigns.is_full_height, do: "h-full", else: "h-24"),
            assigns.class
          ]),
        range: range_labels(data, assigns.hide_date_range, assigns.datetime_format)
      )

    ~H"""
    <div
      id={@id}
      data-polaris-logs-chart
      phx-hook={@hook}
      data-click-event={@on_bar_click}
      class={@wrapper_classes}
      {@rest}
    >
      <%= if @error do %>
        {render_slot(@error_state)}
      <% else %>
        <%= if @data == [] do %>
          {render_slot(@empty_state)}
        <% else %>
          <div class="flex h-full items-end gap-px" data-polaris-logs-chart-bars>
            <div
              :for={{datum, index} <- Enum.with_index(@data)}
              data-polaris-logs-chart-col
              data-index={index}
              data-timestamp={datum.timestamp}
              class="group relative flex h-full flex-1 cursor-pointer flex-col justify-end transition-opacity"
            >
              <div
                :for={{key, color} <- @segments}
                :if={datum[key] > 0}
                data-polaris-logs-chart-segment
                data-series={key}
                style={"height: #{round(datum[key] / @max_total * 100)}%"}
                class={"w-full transition-colors #{color}"}
              >
              </div>
              <div
                data-polaris-logs-chart-tooltip
                data-empty={@hide_zero_values and all_zero?(datum)}
                class="pointer-events-none absolute bottom-full left-1/2 z-50 mb-2 hidden -translate-x-1/2 whitespace-nowrap rounded-sm border border-surface-border bg-surface-ground/95 p-2 text-left text-xs text-content-primary shadow-lg"
              >
                <div class="text-content-muted">
                  {format_timestamp(datum.timestamp, @datetime_format)}
                </div>
                <div
                  :for={{key, label} <- @tooltip_series}
                  :if={not @hide_zero_values or datum[key] > 0}
                >
                  {label}: {datum[key]}
                </div>
              </div>
            </div>
          </div>
          <div
            :if={@range}
            class="flex items-center justify-between font-mono text-[10px] text-content-muted"
            data-polaris-logs-chart-range
          >
            <span>{@range.first}</span>
            <span>{@range.last}</span>
          </div>
        <% end %>
      <% end %>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Chart" runtime>
      {
        mounted() {
          const root = this.el
          const columns = () => Array.from(root.querySelectorAll("[data-polaris-logs-chart-col]"))
          const tooltipOf = (col) => col.querySelector("[data-polaris-logs-chart-tooltip]")
          // All listeners are delegated from the root so LiveView morphs
          // that swap columns/tooltips never orphan them.
          this._onMouseOver = (event) => {
            const col = event.target.closest("[data-polaris-logs-chart-col]")
            if (!col || !root.contains(col)) {
              return
            }
            const tooltip = tooltipOf(col)
            if (tooltip && !tooltip.hasAttribute("data-empty")) {
              tooltip.classList.remove("hidden")
            }
            columns().forEach((other) => {
              if (other !== col) {
                other.classList.add("opacity-40")
              }
            })
          }
          this._onMouseOut = (event) => {
            const col = event.target.closest("[data-polaris-logs-chart-col]")
            if (!col || !root.contains(col)) {
              return
            }
            const tooltip = tooltipOf(col)
            if (tooltip) {
              tooltip.classList.add("hidden")
            }
            columns().forEach((other) => other.classList.remove("opacity-40"))
          }
          this._onClick = (event) => {
            const col = event.target.closest("[data-polaris-logs-chart-col]")
            if (!col || !root.contains(col)) {
              return
            }
            const clickEvent = root.dataset.clickEvent
            if (clickEvent && typeof this.pushEvent === "function") {
              this.pushEvent(clickEvent, {
                index: col.dataset.index,
                timestamp: col.dataset.timestamp
              })
            }
          }
          root.addEventListener("mouseover", this._onMouseOver)
          root.addEventListener("mouseout", this._onMouseOut)
          root.addEventListener("click", this._onClick)
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("mouseover", this._onMouseOver)
          this.el.removeEventListener("mouseout", this._onMouseOut)
          this.el.removeEventListener("click", this._onClick)
        }
      }
    </script>
    """
  end

  ## Normalization

  # One map per bucket with normalized counts and a string timestamp.
  defp normalize_data(data) when is_list(data) do
    Enum.map(data, fn datum ->
      %{
        timestamp: datum |> fetch(:timestamp) |> timestamp_string(),
        error_count: datum |> fetch(:error_count) |> to_number(),
        warning_count: datum |> fetch(:warning_count) |> to_number(),
        ok_count: datum |> fetch(:ok_count) |> to_number()
      }
    end)
  end

  defp normalize_data(other) do
    raise ArgumentError, "expected data to be a list of bucket maps, got: #{inspect(other)}"
  end

  # Atom- or string-keyed fetch.
  defp fetch(map, key) when is_map(map) do
    case Map.get(map, key) do
      nil -> Map.get(map, to_string(key))
      value -> value
    end
  end

  defp fetch(_other, _key), do: nil

  # Counts arrive as integers, floats, or numeric strings; anything
  # else counts as 0.
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

  # Segments are sized against the largest bucket total so the busiest
  # bucket spans the full column height; guarded to 1 so all-zero data
  # never divides by zero.
  defp max_total(data) do
    data
    |> Enum.map(&(&1.error_count + &1.warning_count + &1.ok_count))
    |> Enum.max(fn -> 0 end)
    |> max(1)
  end

  defp all_zero?(datum),
    do: datum.error_count == 0 and datum.warning_count == 0 and datum.ok_count == 0

  ## Timestamps

  # The date-range pair, unless the chart is empty or the row is hidden.
  defp range_labels([], _hide, _format), do: nil
  defp range_labels(_data, true, _format), do: nil

  defp range_labels(data, false, format) do
    %{
      first: format_timestamp(hd(data).timestamp, format),
      last: format_timestamp(List.last(data).timestamp, format)
    }
  end

  # dayjs's forgiving parse: ISO8601 with offset first, then bare
  # naive ISO8601, then the raw string as-is.
  defp format_timestamp(timestamp, format) do
    case parse_datetime(timestamp) do
      nil -> timestamp
      datetime -> Calendar.strftime(datetime, format)
    end
  end

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
end
