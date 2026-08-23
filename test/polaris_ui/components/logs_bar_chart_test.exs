defmodule PolarisUI.Components.LogsBarChartTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.LogsBarChart` —
  chart anatomy, stacked segment geometry, tooltip microcopy, the
  date-range row, empty/error states, and the colocated hover/click
  hook, mirroring the Supabase design system fragment
  `ui-patterns/LogsBarChart` (a recharts stacked bar chart rendered
  server-side as flex columns).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.LogsBarChart

  @hook "PolarisUI.Components.LogsBarChart.Chart"

  # Single bucket, total 43: error 2 -> 5%, warning 1 -> 2%, ok 40 -> 93%.
  @single [%{timestamp: "2026-08-22T10:00:00Z", error_count: 2, warning_count: 1, ok_count: 40}]

  @buckets [
    %{timestamp: "2026-08-22T10:00:00Z", error_count: 2, warning_count: 1, ok_count: 40},
    %{timestamp: "2026-08-22T10:05:00Z", error_count: 0, warning_count: 3, ok_count: 10}
  ]

  describe "anatomy" do
    test "renders the wrapper with hook anchor, chart row, and columns" do
      assigns = %{data: @buckets}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      assert html =~ ~s{id="c"}
      assert html =~ "data-polaris-logs-chart"
      assert html =~ "data-polaris-logs-chart-bars"
      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ "<script"

      assert length(Regex.scan(~r/data-index=/, html)) == 2
      assert html =~ ~s{data-index="0"}
      assert html =~ ~s{data-index="1"}
      assert html =~ ~s{data-timestamp="2026-08-22T10:00:00Z"}
      assert html =~ ~s{data-timestamp="2026-08-22T10:05:00Z"}
      assert length(Regex.scan(~r/data-polaris-logs-chart-tooltip /, html)) == 2
    end

    test "wrapper is h-24 by default and h-full with is_full_height" do
      assigns = %{data: @single}

      default =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      wrapper = class_of(default, "data-polaris-logs-chart")
      assert wrapper =~ "flex flex-col gap-y-3"
      assert wrapper =~ "h-24"
      refute wrapper =~ "h-full"

      full =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} is_full_height />
        """)

      assert class_of(full, "data-polaris-logs-chart") =~ "h-full"
    end

    test "caller classes merge onto the wrapper and globals pass through" do
      assigns = %{data: @single}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} class="w-full" data-track="x" />
        """)

      assert class_of(html, "data-polaris-logs-chart") =~ "w-full"
      assert html =~ ~s{data-track="x"}
    end
  end

  describe "segments" do
    test "segment heights are percentages of the largest bucket total" do
      assigns = %{data: @single}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      assert segment_style(html, "error_count") == "height: 5%"
      assert segment_style(html, "warning_count") == "height: 2%"
      assert segment_style(html, "ok_count") == "height: 93%"
    end

    test "series colors map to danger, warning, and brand tokens" do
      assigns = %{data: @single}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      assert class_of(html, ~s{data-series="error_count"}) =~ "bg-danger"
      assert class_of(html, ~s{data-series="warning_count"}) =~ "bg-warning"
      assert class_of(html, ~s{data-series="ok_count"}) =~ "bg-brand-emerald"
    end

    test "segments stack ok on top and error at the bottom, like recharts" do
      assigns = %{data: @single}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      ok_at = position_of(html, ~s{data-series="ok_count"})
      warning_at = position_of(html, ~s{data-series="warning_count"})
      error_at = position_of(html, ~s{data-series="error_count"})

      assert ok_at < warning_at and warning_at < error_at
    end

    test "zero-count segments are skipped entirely" do
      assigns = %{data: @buckets}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      # Second bucket has error_count 0: one error segment, two of the rest.
      assert length(Regex.scan(~r/data-series="error_count"/, html)) == 1
      assert length(Regex.scan(~r/data-series="warning_count"/, html)) == 2
      assert length(Regex.scan(~r/data-series="ok_count"/, html)) == 2
    end

    test "numeric string counts normalize to the same geometry" do
      assigns = %{
        data: [
          %{
            timestamp: "2026-08-22T10:00:00Z",
            error_count: "2",
            warning_count: "1",
            ok_count: "40"
          }
        ]
      }

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      assert segment_style(html, "error_count") == "height: 5%"
      assert segment_style(html, "ok_count") == "height: 93%"
      assert html =~ "Errors: 2"
    end
  end

  describe "tooltip" do
    test "renders the formatted timestamp plus one line per series" do
      assigns = %{data: @single}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      tooltip = class_of(html, "data-polaris-logs-chart-tooltip")
      assert tooltip =~ "hidden"
      assert tooltip =~ "z-50"
      assert tooltip =~ "pointer-events-none"

      assert html =~ "Aug 22, 2026, 10:00 AM"
      assert html =~ "Errors: 2"
      assert html =~ "Warnings: 1"
      assert html =~ "Ok: 40"
    end

    test "hide_zero_values omits zero-count lines" do
      assigns = %{
        data: [
          %{timestamp: "2026-08-22T10:00:00Z", error_count: 2, warning_count: 0, ok_count: 40}
        ]
      }

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} hide_zero_values />
        """)

      assert html =~ "Errors: 2"
      assert html =~ "Ok: 40"
      refute html =~ "Warnings:"
    end

    test "an all-zero bucket gets a data-empty tooltip only when hide_zero_values" do
      assigns = %{
        data: [
          %{timestamp: "2026-08-22T10:00:00Z", error_count: 0, warning_count: 0, ok_count: 0}
        ]
      }

      with_lines =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      assert with_lines =~ "Errors: 0"
      assert with_lines =~ "Ok: 0"
      refute tooltip_tag(with_lines) =~ "data-empty"

      filtered =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} hide_zero_values />
        """)

      assert tooltip_tag(filtered) =~ "data-empty"
      refute filtered =~ "Errors:"
      refute filtered =~ "Warnings:"
      refute filtered =~ "Ok:"
    end
  end

  describe "date range" do
    test "formats the first and last timestamps with datetime_format" do
      assigns = %{data: @buckets}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      range = class_of(html, "data-polaris-logs-chart-range")
      assert range =~ "flex items-center justify-between"
      assert range =~ "font-mono text-[10px]"
      assert range =~ "text-content-muted"

      assert html =~ "<span>Aug 22, 2026, 10:00 AM</span>"
      assert html =~ "<span>Aug 22, 2026, 10:05 AM</span>"

      assert position_of(html, "<span>Aug 22, 2026, 10:00 AM</span>") <
               position_of(html, "<span>Aug 22, 2026, 10:05 AM</span>")
    end

    test "a custom strftime format wins" do
      assigns = %{data: @buckets}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} datetime_format="%Y-%m-%d %H:%M" />
        """)

      assert html =~ "2026-08-22 10:00"
      assert html =~ "2026-08-22 10:05"
      refute html =~ "Aug 22"
    end

    test "unparseable timestamps pass through raw" do
      assigns = %{
        data: [
          %{timestamp: "earliest", error_count: 1, warning_count: 1, ok_count: 1},
          %{timestamp: "latest", error_count: 1, warning_count: 1, ok_count: 1}
        ]
      }

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      assert html =~ "<span>earliest</span>"
      assert html =~ "<span>latest</span>"
    end

    test "hide_date_range removes the row" do
      assigns = %{data: @buckets}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} hide_date_range />
        """)

      refute html =~ "data-polaris-logs-chart-range"
    end
  end

  describe "empty and error states" do
    test "empty data renders the empty_state slot instead of the chart" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={[]}>
          <:empty_state>No log events in this time period.</:empty_state>
        </.logs_bar_chart>
        """)

      assert html =~ "No log events in this time period."
      refute html =~ "data-polaris-logs-chart-bars"
      refute html =~ "data-polaris-logs-chart-range"
    end

    test "empty data without the slot renders just the wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={[]} />
        """)

      assert html =~ ~s{id="c"}
      refute html =~ "data-polaris-logs-chart-bars"
      refute html =~ "data-polaris-logs-chart-range"
    end

    test "a truthy error renders the error_state slot instead of the chart" do
      assigns = %{data: @buckets}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} error={:boom}>
          <:error_state>Failed to load log events.</:error_state>
        </.logs_bar_chart>
        """)

      assert html =~ "Failed to load log events."
      refute html =~ "data-polaris-logs-chart-bars"
      refute html =~ "data-polaris-logs-chart-range"
    end

    test "error wins over empty and renders nothing without the slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={[]} error="failed">
          <:empty_state>Never shown.</:empty_state>
        </.logs_bar_chart>
        """)

      refute html =~ "Never shown."
      refute html =~ "data-polaris-logs-chart-bars"

      bare =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={[]} error="failed" />
        """)

      refute bare =~ "data-polaris-logs-chart-bars"
    end
  end

  describe "hook" do
    test "attaches the colocated runtime hook with its click event" do
      assigns = %{data: @single}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} on_bar_click="select-bucket" />
        """)

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-click-event="select-bucket"}
      assert html =~ "<script"
    end

    test "no click event attribute when on_bar_click is unset" do
      assigns = %{data: @single}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} />
        """)

      refute html =~ "data-click-event"
    end

    test "hook delegates hover, dimming, and click from the root" do
      assigns = %{data: @single}

      html =
        rendered_to_string(~H"""
        <.logs_bar_chart id="c" data={@data} on_bar_click="select-bucket" />
        """)

      assert html =~ ~s/"mouseover"/
      assert html =~ ~s/"mouseout"/
      assert html =~ "addEventListener(\"click\""
      assert html =~ "closest"
      assert html =~ "data-polaris-logs-chart-col"
      assert html =~ "opacity-40"
      assert html =~ "data-empty"
      assert html =~ "pushEvent(clickEvent"
      assert html =~ "typeof this.pushEvent"
      assert html =~ "destroyed"
      assert html =~ "removeEventListener"
    end
  end

  # Byte offset of a substring's first occurrence, for DOM-order checks.
  defp position_of(html, substring) do
    html |> String.split(substring) |> hd() |> byte_size()
  end

  # The opening tag of the first tooltip element (scoped so refutes never
  # trip over the same marker inside the hook's selector strings).
  defp tooltip_tag(html) do
    [tag] = Regex.run(~r/<div[^>]*data-polaris-logs-chart-tooltip[^>]*>/, html)
    tag
  end

  defp segment_style(html, series) do
    marker = Regex.escape(~s{data-series="#{series}"})

    style_after = ~r{<[^>]*#{marker}[^>]*?style="([^"]*)"[^>]*>}
    style_before = ~r{<[^>]*style="([^"]*)"[^>]*?#{marker}[^>]*>}

    cond do
      match = Regex.run(style_after, html, capture: :all_but_first) -> hd(match)
      match = Regex.run(style_before, html, capture: :all_but_first) -> hd(match)
      true -> flunk("no segment element with data-series=\"#{series}\"")
    end
  end

  # Extracts the class attribute of the element carrying the marker,
  # regardless of attribute order within the tag.
  defp class_of(html, marker) do
    marker = Regex.escape(marker)

    class_after = ~r{<[^>]*#{marker}[^>]*?class="([^"]*)"[^>]*>}
    class_before = ~r{<[^>]*class="([^"]*)"[^>]*?#{marker}[^>]*>}

    cond do
      match = Regex.run(class_after, html, capture: :all_but_first) -> hd(match)
      match = Regex.run(class_before, html, capture: :all_but_first) -> hd(match)
      true -> flunk("no element with marker #{marker}")
    end
  end
end
