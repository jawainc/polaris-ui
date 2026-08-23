defmodule PolarisUI.Components.MetricCardTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.MetricCard` — the
  compound card anatomy, the CSS-only loading/disabled context port
  (group-data variants), differential variants, sparkline geometry,
  and header/label affordances, mirroring the Supabase design system
  fragment `ui-patterns/MetricCard`.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.MetricCard

  # n = 3, step = 50: xs 0/50/100; max = 100: ys 0/50/0.
  @spark [
    %{value: 100, timestamp: "2026-08-22T10:00:00Z"},
    %{value: 50, timestamp: "2026-08-22T11:00:00Z"},
    %{value: 100, timestamp: "2026-08-22T12:00:00Z"}
  ]

  @step_d "M 0,0 L 50,0 L 50,50 L 100,50 L 100,0"

  describe "root" do
    test "renders the card chrome with the loading/disabled swap anchors" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card>
          <.metric_card_header>
            <.metric_card_label>Active users</.metric_card_label>
          </.metric_card_header>
        </.metric_card>
        """)

      root = class_of(html, "data-polaris-metric-card")
      assert root =~ "group"
      assert root =~ "flex flex-col"
      assert root =~ "rounded-lg"
      assert root =~ "border border-surface-border"
      assert root =~ "bg-surface-panel"
      assert root =~ "transition-colors"
      assert root =~ "hover:bg-surface-panel-hover"

      assert html =~ ~s{data-loading="false"}
      assert html =~ ~s{data-disabled="false"}
      assert html =~ ~s{aria-busy="false"}
    end

    test "loading flips data-loading and aria-busy" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card loading>
          <.metric_card_header>
            <.metric_card_label>Active users</.metric_card_label>
          </.metric_card_header>
        </.metric_card>
        """)

      assert html =~ ~s{data-loading="true"}
      assert html =~ ~s{aria-busy="true"}
    end

    test "disabled locks the card like the fragment's isDisabled" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card disabled>
          <.metric_card_header>
            <.metric_card_label>Active users</.metric_card_label>
          </.metric_card_header>
        </.metric_card>
        """)

      root = class_of(html, "data-polaris-metric-card")
      assert root =~ "pointer-events-none"
      assert root =~ "opacity-50"
      assert html =~ ~s{data-disabled="true"}
    end

    test "caller classes merge onto the root and globals pass through" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card class="max-w-md" data-track="x">
          <.metric_card_header>
            <.metric_card_label>Active users</.metric_card_label>
          </.metric_card_header>
        </.metric_card>
        """)

      assert class_of(html, "data-polaris-metric-card") =~ "max-w-md"
      assert html =~ ~s{data-track="x"}
    end
  end

  describe "header" do
    test "renders the label row and links out with href" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_header href="https://supabase.com" link_tooltip="View the dashboard">
          <.metric_card_label>Active users</.metric_card_label>
        </.metric_card_header>
        """)

      header = class_of(html, "data-polaris-metric-card-header")
      assert header =~ "relative flex flex-row items-center justify-between gap-2"
      assert header =~ "p-4 pb-0"
      assert header =~ "border-b-0"

      assert html =~ ~s{<a href="https://supabase.com"}
      assert html =~ ~s{title="View the dashboard"}
      assert html =~ ~s{aria-label="More information"}
      assert html =~ ~s{<span class="sr-only">More information</span>}
      assert html =~ ~s{d="m9 18 6-6-6-6"}
      assert html =~ "size-3.5"
      assert html =~ "data-polaris-metric-card-link"
    end

    test "link_tooltip without href renders the non-link chevron affordance" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_header link_tooltip="Drill into usage">
          <.metric_card_label>Active users</.metric_card_label>
        </.metric_card_header>
        """)

      assert html =~ ~s{<span title="Drill into usage"}
      refute html =~ "<a "
      assert html =~ ~s{<span class="sr-only">More information</span>}
      assert html =~ "data-polaris-metric-card-link"
    end

    test "no chevron without href or link_tooltip" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_header>
          <.metric_card_label>Active users</.metric_card_label>
        </.metric_card_header>
        """)

      refute html =~ "data-polaris-metric-card-link"
    end

    test "caller classes merge onto the header" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_header class="pt-6">
          <.metric_card_label>Active users</.metric_card_label>
        </.metric_card_header>
        """)

      assert class_of(html, "data-polaris-metric-card-header") =~ "pt-6"
    end
  end

  describe "icon" do
    test "tints its glyph secondary and forwards globals" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_icon data-track="x">
          <svg viewBox="0 0 24 24"></svg>
        </.metric_card_icon>
        """)

      assert class_of(html, "data-polaris-metric-card-icon") =~ "text-content-secondary"
      assert html =~ ~s{data-track="x"}
    end
  end

  describe "label" do
    test "composes an info_tooltip when given tooltip and id" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_label id="active-users" tooltip="The number of active users over the last 24 hours">
          Active users
        </.metric_card_label>
        """)

      label = class_of(html, "data-polaris-metric-card-label")
      assert label =~ "flex items-center gap-2 text-sm text-content-secondary"

      assert html =~ ~s{id="active-users-tooltip"}
      assert html =~ "data-polaris-info-tooltip"
      assert html =~ "The number of active users over the last 24 hours"
      assert html =~ "Active users"
    end

    test "label without tooltip renders plain" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_label>Active users</.metric_card_label>
        """)

      assert html =~ "<span>Active users</span>"
      refute html =~ "data-polaris-info-tooltip"
    end

    test "tooltip without an id raises a clear error" do
      assert_raise ArgumentError, ~r/requires a unique id when tooltip is set/, fn ->
        assigns = %{}

        rendered_to_string(~H"""
        <.metric_card_label tooltip="The number of active users over the last 24 hours">
          Active users
        </.metric_card_label>
        """)
      end
    end
  end

  describe "content" do
    test "stacks vertically by default and in a row when horizontal" do
      assigns = %{}

      vertical =
        rendered_to_string(~H"""
        <.metric_card_content>
          <.metric_card_value>12,480</.metric_card_value>
        </.metric_card_content>
        """)

      classes = class_of(vertical, "data-polaris-metric-card-content")
      assert classes =~ "flex flex-1 items-start gap-1 overflow-hidden border-b-0 p-4 pt-0"
      assert classes =~ "flex-col"
      refute classes =~ "flex-row"

      horizontal =
        rendered_to_string(~H"""
        <.metric_card_content orientation="horizontal">
          <.metric_card_value>12,480</.metric_card_value>
        </.metric_card_content>
        """)

      assert class_of(horizontal, "data-polaris-metric-card-content") =~ "flex-row"
    end

    test "invalid orientation raises a clear error" do
      assert_raise ArgumentError, ~r/invalid value for :orientation/, fn ->
        assigns = %{}

        rendered_to_string(~H"""
        <.metric_card_content orientation="diagonal">
          <.metric_card_value>12,480</.metric_card_value>
        </.metric_card_content>
        """)
      end
    end
  end

  describe "value" do
    test "renders content and skeleton swapped by the group-data variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_value>12,480</.metric_card_value>
        """)

      assert html =~ "data-polaris-metric-card-value"
      assert html =~ "12,480"
      assert html =~ "text-xl font-normal tabular-nums group-data-[loading=true]:hidden"
      assert html =~ "data-polaris-metric-card-skeleton"

      skeleton = class_of(html, "data-polaris-metric-card-skeleton")

      assert skeleton =~
               "hidden h-7 w-32 animate-pulse rounded-sm bg-surface-panel-hover group-data-[loading=true]:block"
    end

    test "caller classes merge onto the value text" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_value class="text-2xl" data-track="x">12,480</.metric_card_value>
        """)

      assert html =~ "group-data-[loading=true]:hidden text-2xl"
      assert html =~ ~s{data-track="x"}
    end
  end

  describe "differential" do
    test "colors by variant with the fragment's token mapping" do
      assigns = %{}

      positive =
        rendered_to_string(~H"""
        <.metric_card_differential variant="positive">+4.2%</.metric_card_differential>
        """)

      assert positive =~
               "text-sm tabular-nums group-data-[loading=true]:hidden text-brand-emerald"

      assert positive =~ "+4.2%"

      negative =
        rendered_to_string(~H"""
        <.metric_card_differential variant="negative">-1.8%</.metric_card_differential>
        """)

      assert negative =~ "text-danger"

      default =
        rendered_to_string(~H"""
        <.metric_card_differential>+0.0%</.metric_card_differential>
        """)

      assert default =~ "text-content-secondary"
    end

    test "renders its smaller skeleton with the group-data swap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_differential>+4.2%</.metric_card_differential>
        """)

      assert html =~ "data-polaris-metric-card-differential"

      skeleton = class_of(html, "data-polaris-metric-card-skeleton")

      assert skeleton =~
               "hidden h-5 w-16 animate-pulse rounded-sm bg-surface-panel-hover group-data-[loading=true]:block"
    end

    test "invalid variant raises a clear error" do
      assert_raise ArgumentError, ~r/invalid value for :variant/, fn ->
        assigns = %{}

        rendered_to_string(~H"""
        <.metric_card_differential variant="sideways">+4.2%</.metric_card_differential>
        """)
      end
    end
  end

  describe "sparkline" do
    test "renders the svg with gradient, step, and area paths" do
      assigns = %{data: @spark}

      html =
        rendered_to_string(~H"""
        <.metric_card_sparkline id="s" data={@data} />
        """)

      assert html =~ "data-polaris-metric-card-sparkline-svg"
      assert html =~ ~s{viewBox="0 0 100 100"}
      assert html =~ ~s{preserveAspectRatio="none"}
      assert html =~ ~s{aria-hidden="true"}

      assert html =~ ~s{id="s-gradient"}
      assert html =~ ~s{stop-color="var(--color-brand-emerald)"}
      assert html =~ ~s{stop-opacity="0.8"}
      assert html =~ ~s{fill="url(#s-gradient)"}
      assert html =~ ~s{fill-opacity="0.1"}

      assert html =~ ~s{d="#{@step_d}"}
      assert html =~ ~s{d="#{@step_d} L 100,100 L 0,100 Z"}

      assert html =~ ~s{stroke="var(--color-brand-emerald)"}
      assert html =~ ~s{stroke-width="1.5"}
      assert html =~ ~s{vector-effect="non-scaling-stroke"}

      refute html =~ "#3ecf8e"
    end

    test "gradient ids are unique per instance" do
      assigns = %{data: @spark}

      html =
        rendered_to_string(~H"""
        <div>
          <.metric_card_sparkline id="a" data={@data} />
          <.metric_card_sparkline id="b" data={@data} />
        </div>
        """)

      assert html =~ ~s{id="a-gradient"}
      assert html =~ ~s{id="b-gradient"}
      assert html =~ ~s{fill="url(#a-gradient)"}
      assert html =~ ~s{fill="url(#b-gradient)"}
    end

    test "each point gets a transparent hit rect with a native title" do
      assigns = %{data: @spark}

      html =
        rendered_to_string(~H"""
        <.metric_card_sparkline id="s" data={@data} />
        """)

      # Edges clamp to half a step (25 of 50); the middle spans the full step.
      assert html =~ ~s{width="25"}
      assert html =~ ~s{x="25"}
      assert html =~ ~s{width="50"}
      assert html =~ ~s{height="100"}
      assert html =~ ~s{fill="transparent"}

      assert html =~ "<title>Aug 22, 10am: 100</title>"
      assert html =~ "<title>Aug 22, 11am: 50</title>"
      assert html =~ "<title>Aug 22, 12pm: 100</title>"
    end

    test "values group with thousands separators in titles" do
      assigns = %{
        data: [
          %{value: 4321, timestamp: "2026-08-22T10:00:00Z"},
          %{value: 8642, timestamp: "2026-08-22T11:00:00Z"}
        ]
      }

      html =
        rendered_to_string(~H"""
        <.metric_card_sparkline id="s" data={@data} />
        """)

      assert html =~ "<title>Aug 22, 10am: 4,321</title>"
      assert html =~ "<title>Aug 22, 11am: 8,642</title>"
    end

    test "string keys and numeric string values normalize via data_key" do
      assigns = %{
        data: [
          %{"value" => "100", "timestamp" => "2026-08-22T10:00:00Z"},
          %{"value" => "50", "timestamp" => "2026-08-22T11:00:00Z"},
          %{"value" => "100", "timestamp" => "2026-08-22T12:00:00Z"}
        ]
      }

      html =
        rendered_to_string(~H"""
        <.metric_card_sparkline id="s" data={@data} data_key="value" />
        """)

      assert html =~ ~s{d="#{@step_d}"}
      assert html =~ "<title>Aug 22, 10am: 100</title>"
    end

    test "empty data renders the skeleton slot but no chart" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.metric_card_sparkline id="s" data={[]} />
        """)

      assert html =~ "data-polaris-metric-card-sparkline"

      assert html =~
               "hidden h-14 w-full animate-pulse bg-surface-panel-hover group-data-[loading=true]:block"

      refute html =~ "data-polaris-metric-card-sparkline-svg"
    end

    test "caller classes merge onto the chart wrapper and globals pass through" do
      assigns = %{data: @spark}

      html =
        rendered_to_string(~H"""
        <.metric_card_sparkline id="s" data={@data} class="mt-2" data-track="x" />
        """)

      assert html =~ "relative h-16 w-full group-data-[loading=true]:hidden mt-2"
      assert html =~ ~s{data-track="x"}
    end
  end

  describe "loading swap (context port)" do
    test "loading swaps skeleton and content purely via CSS" do
      assigns = %{data: @spark}

      html =
        rendered_to_string(~H"""
        <.metric_card loading>
          <.metric_card_content>
            <.metric_card_value>12,480</.metric_card_value>
            <.metric_card_differential variant="positive">+4.2%</.metric_card_differential>
          </.metric_card_content>
          <.metric_card_sparkline id="s" data={@data} />
        </.metric_card>
        """)

      assert html =~ ~s{data-loading="true"}

      # Both halves stay in the DOM; CSS flips visibility on the group.
      assert html =~ "group-data-[loading=true]:block"
      assert html =~ "group-data-[loading=true]:hidden"
      assert html =~ "12,480"
      assert html =~ "+4.2%"
    end

    test "assembles the full card like the fragment demo" do
      assigns = %{data: @spark}

      html =
        rendered_to_string(~H"""
        <.metric_card>
          <.metric_card_header href="https://supabase.com" link_tooltip="View the dashboard">
            <.metric_card_icon>
              <svg viewBox="0 0 24 24"></svg>
            </.metric_card_icon>
            <.metric_card_label
              id="active-users"
              tooltip="The number of active users over the last 24 hours"
            >
              Active users
            </.metric_card_label>
          </.metric_card_header>
          <.metric_card_content>
            <.metric_card_value>4,509</.metric_card_value>
            <.metric_card_differential variant="positive">+3.4%</.metric_card_differential>
          </.metric_card_content>
          <.metric_card_sparkline id="users-spark" data={@data} />
        </.metric_card>
        """)

      assert html =~ "data-polaris-metric-card"
      assert html =~ "data-polaris-metric-card-header"
      assert html =~ "data-polaris-metric-card-icon"
      assert html =~ "data-polaris-metric-card-label"
      assert html =~ "data-polaris-metric-card-content"
      assert html =~ "data-polaris-metric-card-value"
      assert html =~ "data-polaris-metric-card-differential"
      assert html =~ "data-polaris-metric-card-sparkline"
      assert html =~ "Active users"
      assert html =~ "4,509"
      assert html =~ "+3.4%"
      assert html =~ ~s{d="#{@step_d}"}
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
