defmodule PolarisUI.Components.CalendarTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Calendar` — the port of
  the Supabase design system Calendar (react-day-picker v9 wrapper): the
  bordered `p-3` surface, caption + chevron nav, the flex weekday header,
  36px day buttons with emerald selection fills, outside/disabled
  dimming, and the colocated runtime hook that owns months, selection,
  and the roving-tabindex keyboard grid.

  Fixtures use August 2026 (starting Saturday, 31 days → 6 lead days,
  5 trail days, 42 cells with `show_outside_days`).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Calendar

  @hook "PolarisUI.Components.Calendar.Root"
  @month ~D[2026-08-01]

  defp render_calendar(assigns) do
    assigns =
      Map.merge(
        %{
          id: "cal",
          month: @month,
          mode: "single",
          selected: nil,
          min_date: nil,
          max_date: nil,
          show_outside_days: true,
          week_starts_on: 0,
          on_select: nil,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.calendar
      id={@id}
      month={@month}
      mode={@mode}
      selected={@selected}
      min_date={@min_date}
      max_date={@max_date}
      show_outside_days={@show_outside_days}
      week_starts_on={@week_starts_on}
      on_select={@on_select}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "anatomy" do
    test "renders the bordered p-3 surface carrying the hook config" do
      html = render_calendar(%{})

      assert html =~ ~s{id="cal"}
      assert html =~ ~s{data-polaris-calendar }
      assert html =~ ~s{data-mode="single"}
      assert html =~ ~s{data-month="2026-08-01"}
      assert html =~ ~s{data-week-start="0"}
      assert html =~ ~s{data-outside="true"}
      assert html =~ ~s{phx-hook="#{@hook}"}

      class = root_class(html)
      assert class =~ "rounded-md border border-surface-border"
      assert class =~ "bg-surface-base p-3"
    end

    test "renders the centered caption with polite live updates" do
      html = render_calendar(%{})

      assert html =~ ~s{id="cal-caption"}
      assert html =~ ~s{aria-live="polite"}
      assert html =~ "August 2026"
      assert html =~ ~s{data-polaris-calendar-caption}
    end

    test "renders the chevron nav buttons absolutely positioned in the caption" do
      html = render_calendar(%{})

      prev = nav_chunk(html, "prev")
      assert prev =~ ~s{aria-label="Previous month"}
      assert prev =~ "absolute left-0 top-0"
      assert prev =~ "h-7 w-7"
      assert prev =~ "opacity-50 hover:opacity-100"
      assert prev =~ "aria-disabled:opacity-25 aria-disabled:hover:opacity-25"
      assert prev =~ "aria-disabled:cursor-not-allowed"

      next = nav_chunk(html, "next")
      assert next =~ ~s{aria-label="Next month"}
      assert next =~ "absolute right-0 top-0"

      assert html =~ ~s{<path d="m15 18-6-6 6-6">}
      assert html =~ ~s{<path d="m9 18 6-6-6-6">}
      assert html =~ ~s{class="h-4 w-4 pointer-events-none"}
    end

    test "renders the weekday header with narrow labels and full names" do
      html = render_calendar(%{})

      assert html =~ ~s{<th scope="col" aria-label="Sunday"}
      assert html =~ ~s{<th scope="col" aria-label="Saturday"}
      assert html =~ ~r{>\s*Su\s*<}
      assert html =~ ~r{>\s*Sa\s*<}

      weekday =
        html |> String.split("<th scope=") |> Enum.at(1) |> String.split("</th>") |> List.first()

      assert weekday =~ "text-content-muted rounded-md w-9 font-normal text-[0.8rem]"
    end

    test "renders the month grid semantics" do
      html = render_calendar(%{})

      assert html =~ ~s{role="grid" aria-labelledby="cal-caption"}
      assert html =~ ~s{data-polaris-calendar-grid}
      # 42 day cells chunk into six flex week rows.
      assert day_count(html) == 42
      assert rem(day_count(html), 7) == 0
    end

    test "renders 42 cells: 31 days plus lead and trail outside days" do
      html = render_calendar(%{})

      assert day_count(html) == 42
      assert html =~ ~s{data-date="2026-07-26"}
      assert html =~ ~s{data-date="2026-07-31"}
      assert html =~ ~s{data-date="2026-08-01"}
      assert html =~ ~s{data-date="2026-08-31"}
      assert html =~ ~s{data-date="2026-09-01"}
      assert html =~ ~s{data-date="2026-09-05"}
      refute html =~ ~s{data-date="2026-09-06"}
    end

    test "day buttons are 36px ghost buttons with full date labels" do
      html = render_calendar(%{})

      assert html =~ ~s{aria-label="August 15, 2026"}
      class = day_class(html, "2026-08-15")
      assert class =~ "inline-flex h-9 w-9 items-center justify-center"
      assert class =~ "rounded-md p-0 font-normal text-sm"
      assert class =~ "hover:bg-surface-panel-hover hover:text-content-primary"
      assert class =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert class =~ "aria-selected:hover:bg-transparent aria-selected:hover:text-inherit"
    end

    test "day cells carry the source layout with rounded range caps" do
      html = render_calendar(%{})

      td = html |> String.split("<td class=") |> Enum.at(1) |> unescape()
      assert td =~ "text-center text-sm p-0 relative w-9 box-border"
      assert td =~ "first:[&:has([aria-selected])]:rounded-l-md"
      assert td =~ "last:[&:has([aria-selected])]:rounded-r-md"
      assert td =~ "focus-within:relative focus-within:z-20"
    end

    test "hides outside days as blank cells when disabled" do
      html = render_calendar(%{show_outside_days: false})

      refute html =~ ~s{data-date="2026-07-26"}
      refute html =~ ~s{data-date="2026-09-01"}
      assert day_count(html) == 31
      # 42 cells total (31 days + 11 blanks); the hook ships two more
      # `<td class=` fragments inside its renderer strings.
      assert count(html, "<td class=") == 44
    end

    test "rotates the weekday header for week_starts_on" do
      html = render_calendar(%{week_starts_on: 1})

      first_th =
        html |> String.split("<th scope=") |> Enum.at(1) |> String.split("</th>") |> List.first()

      assert first_th =~ ~s{aria-label="Monday"}
      assert first_th =~ ~r{>\s*Mo\b}
      assert html =~ ~s{data-week-start="1"}
      # Monday-first: August 1st (Saturday) leads with 5 outside days.
      assert day_count(html) == 42
      assert html =~ ~s{data-date="2026-07-27"}
      refute html =~ ~s{data-date="2026-07-26"}
    end
  end

  describe "single mode" do
    test "seeds the selection as data-selected and marks the day" do
      html = render_calendar(%{selected: ~D[2026-08-15]})

      assert html =~ ~s{data-selected="2026-08-15"}
      assert html =~ ~s{data-date="2026-08-15" aria-selected="true"}
      assert day_class(html, "2026-08-15") =~ "bg-brand-emerald text-surface-ground rounded-md"
    end

    test "unselected days stay plain and aria-selected=false" do
      html = render_calendar(%{selected: ~D[2026-08-15]})

      assert html =~ ~s{data-date="2026-08-16" aria-selected="false"}
      refute day_class(html, "2026-08-16") =~ "bg-brand-emerald"
    end

    test "today carries the quiet panel chip when not selected" do
      html = render_calendar(%{month: Date.utc_today()})

      today = Date.utc_today() |> Date.to_iso8601()
      assert day_class(html, today) =~ "bg-surface-panel-hover text-content-primary rounded-md"
    end

    test "a selected today overrides the today chip" do
      html = render_calendar(%{month: Date.utc_today(), selected: Date.utc_today()})

      today = Date.utc_today() |> Date.to_iso8601()
      class = day_class(html, today)
      assert class =~ "bg-brand-emerald"
      refute class =~ "bg-surface-panel-hover text-content-primary rounded-md"
    end
  end

  describe "range mode" do
    test "seeds from/to as data attributes" do
      html =
        render_calendar(%{
          mode: "range",
          selected: %{from: ~D[2026-08-10], to: ~D[2026-08-14]}
        })

      assert html =~ ~s{data-from="2026-08-10"}
      assert html =~ ~s{data-to="2026-08-14"}
      assert html =~ ~s{data-mode="range"}
    end

    test "a full range fills end caps and tints the middle" do
      html =
        render_calendar(%{
          mode: "range",
          selected: %{from: ~D[2026-08-10], to: ~D[2026-08-14]}
        })

      assert day_class(html, "2026-08-10") =~ "bg-brand-emerald text-surface-ground rounded-l-md"
      assert day_class(html, "2026-08-14") =~ "bg-brand-emerald text-surface-ground rounded-r-md"
      assert day_class(html, "2026-08-12") =~ "bg-brand-fill text-content-primary rounded-none"
    end

    test "every day in the range is aria-selected" do
      html =
        render_calendar(%{
          mode: "range",
          selected: %{from: ~D[2026-08-10], to: ~D[2026-08-14]}
        })

      for day <- 10..14//1 do
        assert html =~
                 ~s{data-date="2026-08-#{String.pad_leading("#{day}", 2, "0")}" aria-selected="true"}
      end

      assert html =~ ~s{data-date="2026-08-15" aria-selected="false"}
    end

    test "a partial range (from only) fills just the start day" do
      html = render_calendar(%{mode: "range", selected: %{from: ~D[2026-08-10]}})

      assert html =~ ~s{data-from="2026-08-10"}
      refute html =~ "data-to="
      assert day_class(html, "2026-08-10") =~ "bg-brand-emerald text-surface-ground rounded-md"
      assert day_class(html, "2026-08-11") |> refute_contains("bg-brand")
    end

    test "outside days inside a range stay fully opaque" do
      html =
        render_calendar(%{
          mode: "range",
          selected: %{from: ~D[2026-07-30], to: ~D[2026-08-05]}
        })

      assert day_class(html, "2026-07-31") =~ "opacity-100"
      assert day_class(html, "2026-09-01") =~ "text-content-muted opacity-50"
    end
  end

  describe "bounds" do
    test "days beyond min/max render aria-disabled and dimmed" do
      html = render_calendar(%{min_date: ~D[2026-08-03], max_date: ~D[2026-08-28]})

      assert html =~ ~s{data-date="2026-08-02" aria-selected="false" aria-disabled="true"}
      assert html =~ ~s{data-date="2026-08-29" aria-selected="false" aria-disabled="true"}
      assert day_class(html, "2026-08-02") =~ "cursor-not-allowed text-content-muted opacity-50"
      assert html =~ ~s{data-date="2026-08-15" aria-selected="false" aria-disabled="false"}
    end

    test "disabled days drop the hover treatment" do
      html = render_calendar(%{min_date: ~D[2026-08-03]})

      refute day_class(html, "2026-08-02") =~ "hover:bg-surface-panel-hover"
      assert day_class(html, "2026-08-15") =~ "hover:bg-surface-panel-hover"
    end

    test "nav disables at the min/max months" do
      html = render_calendar(%{min_date: ~D[2026-08-03], max_date: ~D[2026-09-15]})

      assert nav_chunk(html, "prev") =~ ~s{aria-disabled="true"}
      assert nav_chunk(html, "next") =~ ~s{aria-disabled="false"}

      html = render_calendar(%{min_date: ~D[2026-07-03], max_date: ~D[2026-08-31]})
      assert nav_chunk(html, "prev") =~ ~s{aria-disabled="false"}
      assert nav_chunk(html, "next") =~ ~s{aria-disabled="true"}
    end

    test "unbounded navigation never disables" do
      html = render_calendar(%{})

      assert nav_chunk(html, "prev") =~ ~s{aria-disabled="false"}
      assert nav_chunk(html, "next") =~ ~s{aria-disabled="false"}
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_calendar(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "seeds month, mode, bounds, and selection from the dataset" do
      html =
        render_calendar(%{selected: ~D[2026-08-15], min_date: ~D[2026-08-01]})

      assert html =~ ~s{this._selected = ds.selected || null}
      assert html =~ ~s{this._min = ds.min || null}
      assert html =~ ~s{this._mode = ds.mode || "single"}
      assert html =~ ~s{const month = (ds.month || "").split("-")}
    end

    test "renders months client-side mirroring the server markup" do
      html = render_calendar(%{})

      assert html =~ "_tableHtml(y, m)"
      assert html =~ "grid.innerHTML = this._tableHtml(y, m)"
      assert html =~ ~s{caption.textContent = new Date(y, m, 1).toLocaleString}
    end

    test "selects days with the RDP semantics" do
      html = render_calendar(%{})

      # single: clicking the selected day clears it
      assert html =~
               ~s{this._selected = this._selected === iso ? null : iso}

      # range: from → to, an earlier click restarting
      assert html =~ "if (!this._from || this._to) {"
      assert html =~ "} else if (iso < this._from) {"
    end

    test "guards disabled days and disabled nav" do
      html = render_calendar(%{})

      assert html =~ ~s{if (day.getAttribute("aria-disabled") === "true") return}
      assert html =~ ~s{prev.getAttribute("aria-disabled") === "true"}
    end

    test "pushes the on_select event with mode-shaped payloads" do
      html = render_calendar(%{on_select: "pick-date"})

      assert html =~ ~s{data-select-event="pick-date"}
      assert html =~ ~s[pushEvent(this._selectEvent, { date: this._selected })]
      assert html =~ ~s[pushEvent(this._selectEvent, { from: this._from, to: this._to })]
    end

    test "no data-select-event attribute without on_select" do
      html = render_calendar(%{})

      refute html =~ "data-select-event"
    end

    test "clamps navigation between the min and max months" do
      html = render_calendar(%{})

      assert html =~ "_monthKey(this._min)"
      assert html =~ "_monthKey(this._max)"
      assert html =~ "this._render(y, m)"
    end

    test "implements the roving-tabindex keyboard grid" do
      html = render_calendar(%{})

      assert html =~ "_rove()"
      assert html =~ "d.tabIndex = d === active ? 0 : -1"
      assert html =~ ~s{"ArrowLeft"}
      assert html =~ ~s{"ArrowRight"}
      assert html =~ ~s{"ArrowUp"}
      assert html =~ ~s{"ArrowDown"}
      assert html =~ ~s{"Home"}
      assert html =~ ~s{"End"}
      assert html =~ ~s{"PageUp"}
      assert html =~ ~s{"PageDown"}
      assert html =~ "event.preventDefault()"
    end

    test "month changes are announced through the live caption" do
      html = render_calendar(%{})

      assert html =~ ~s{aria-live="polite"}
    end

    test "re-renders the hook month after LiveView patches" do
      html = render_calendar(%{})

      assert html =~ "updated()"
      assert html =~ "The hook is authoritative"
    end

    test "mirrors the day class constants from the module" do
      html = render_calendar(%{})

      script = hook_script(html)
      assert script =~ "first:[&:has([aria-selected])]:rounded-l-md"
      assert script =~ "last:[&:has([aria-selected])]:rounded-r-md"
      assert script =~ "bg-brand-emerald text-surface-ground rounded-l-md"
      assert script =~ "bg-brand-fill text-content-primary rounded-none"
      assert script =~ "hover:bg-surface-panel-hover hover:text-content-primary"
      assert script =~ "cursor-not-allowed text-content-muted opacity-50"
    end
  end

  describe "validation" do
    test "rejects an unknown mode" do
      assert_raise ArgumentError, ~r/:mode/, fn ->
        render_calendar(%{mode: "multi"})
      end
    end

    test "rejects a range map in single mode" do
      assert_raise ArgumentError, ~r/mode="single" expects selected to be a Date/, fn ->
        render_calendar(%{selected: %{from: ~D[2026-08-10]}})
      end
    end

    test "rejects a Date in range mode" do
      assert_raise ArgumentError, ~r/mode="range" expects/, fn ->
        render_calendar(%{mode: "range", selected: ~D[2026-08-10]})
      end
    end

    test "rejects a range whose to precedes its from" do
      assert_raise ArgumentError, ~r/before `from`/, fn ->
        render_calendar(%{mode: "range", selected: %{from: ~D[2026-08-10], to: ~D[2026-08-01]}})
      end
    end

    test "rejects a non-Date range to" do
      assert_raise ArgumentError, ~r/must be a Date or nil/, fn ->
        render_calendar(%{mode: "range", selected: %{from: ~D[2026-08-10], to: "2026-08-14"}})
      end
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_calendar(%{rest: %{"data-testid" => "dob-calendar"}})

      assert html =~ ~s{data-testid="dob-calendar"}
    end

    test "classes merge onto the root" do
      html = render_calendar(%{class: "max-w-fit"})

      assert root_class(html) =~ "max-w-fit"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_calendar(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  ## Helpers

  defp refute_contains(class, pattern) do
    refute class =~ pattern
    class
  end

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  # Day buttons in the rendered grid — the 2026- prefix excludes the
  # hook's `data-date="' + iso` renderer fragments.
  defp day_count(html), do: count(html, ~s{data-date="2026-})

  # The root renders its class before the data-polaris marker.
  defp root_class(html) do
    [before_marker | _] = String.split(html, ~s{data-polaris-calendar }, parts: 2)

    before_marker
    |> String.split(~s{class="})
    |> List.last()
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp nav_chunk(html, which) do
    [_, rest | _] = String.split(html, "data-polaris-calendar-#{which}", parts: 2)
    String.split(rest, ">") |> Enum.at(0)
  end

  defp day_class(html, date) do
    [_, rest | _] = String.split(html, ~s{data-date="#{date}"}, parts: 2)

    rest
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  # The raw hook script (unrendered by attribute escaping — script bodies
  # ship raw, but class constants still contain the raw selector text).
  defp hook_script(html) do
    [_, rest | _] = String.split(html, "data-phx-runtime-hook", parts: 2)
    rest
  end

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
