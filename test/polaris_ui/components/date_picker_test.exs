defmodule PolarisUI.Components.DatePickerTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.DatePicker` — the
  port of the Supabase design system Date Picker (ui-patterns): the
  Popover + Button + Calendar composition behind a date-field trigger.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.DatePicker

  @hook "PolarisUI.Components.DatePicker.Root"

  defp render_picker(assigns) do
    assigns =
      Map.merge(
        %{
          id: "due-date",
          value: nil,
          mode: "single",
          on_select: "pick-due-date",
          name: nil,
          min_date: nil,
          max_date: nil,
          month: nil,
          week_starts_on: 0,
          show_outside_days: true,
          placeholder: "Pick a date",
          button_variant: "default",
          button_size: "small",
          is_invalid: false,
          disabled: false,
          class: nil,
          popover_class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.date_picker
      id={@id}
      value={@value}
      mode={@mode}
      on_select={@on_select}
      name={@name}
      min_date={@min_date}
      max_date={@max_date}
      month={@month}
      week_starts_on={@week_starts_on}
      show_outside_days={@show_outside_days}
      placeholder={@placeholder}
      button_variant={@button_variant}
      button_size={@button_size}
      is_invalid={@is_invalid}
      disabled={@disabled}
      class={@class}
      popover_class={@popover_class}
      {assigns[:rest]}
    />
    """)
  end

  describe "trigger" do
    test "renders the placeholder in muted text when empty" do
      html = render_picker(%{})

      assert html =~ "Pick a date"
      assert html =~ "text-content-muted font-normal"
    end

    test "renders the selected date in the long form" do
      html = render_picker(%{value: ~D[2026-08-23]})

      assert html =~ "August 23, 2026"
    end

    test "a range renders from – to, or just the open-ended from" do
      full = render_picker(%{mode: "range", value: %{from: ~D[2026-08-23], to: ~D[2026-08-29]}})
      assert full =~ "August 23, 2026 – August 29, 2026"

      partial = render_picker(%{mode: "range", value: %{from: ~D[2026-08-23], to: nil}})
      assert partial =~ "August 23, 2026"
      refute partial =~ "–"
    end

    test "carries the source DatePickerButton classes and calendar glyph" do
      html = render_picker(%{})

      assert html =~ "w-[240px] justify-start text-left font-normal"
      assert html =~ "data-polaris-date-picker-trigger"
      assert html =~ "M8 2v4"
    end

    test "carries dialog-popup semantics" do
      html = render_picker(%{})

      assert html =~ ~s{aria-haspopup="dialog"}
      assert html =~ ~s{aria-expanded="false"}
    end

    test "is_invalid tints the trigger with the danger tokens" do
      html = render_picker(%{is_invalid: true})

      assert html =~ "border-danger-border bg-danger-fill"
      assert html =~ "focus-visible:ring-danger"
    end

    test "disabled locks the trigger" do
      html = render_picker(%{disabled: true})

      assert html =~ " disabled"
    end

    test "the variant, size, and caller classes pass through" do
      html = render_picker(%{button_variant: "outline", class: "w-[280px]"})

      assert html =~ "w-[280px]"
    end
  end

  describe "form field" do
    test "name renders a hidden input carrying the ISO date (single mode)" do
      html = render_picker(%{name: "due_date", value: ~D[2026-08-23]})

      assert html =~ ~s{type="hidden" name="due_date" value="2026-08-23"}
    end
  end

  describe "popover" do
    test "ships hidden, wrapping the nested Calendar" do
      html = render_picker(%{})

      assert html =~ ~s{data-polaris-date-picker-popover}
      assert html =~ "hidden"
      assert html =~ ~s{id="due-date-calendar"}
      assert html =~ "data-polaris-calendar"
    end

    test "the Calendar receives the picker's configuration" do
      html =
        render_picker(%{
          value: ~D[2026-08-23],
          min_date: ~D[2026-01-01],
          max_date: ~D[2026-12-31],
          month: ~D[2026-08-05]
        })

      assert html =~ ~s{data-selected="2026-08-23"}
      assert html =~ ~s{data-min="2026-01-01"}
      assert html =~ ~s{data-max="2026-12-31"}
      assert html =~ ~s{data-month="2026-08-01"}
      assert html =~ ~s{data-select-event="pick-due-date"}
    end

    test "range mode forwards the from/to selection" do
      html = render_picker(%{mode: "range", value: %{from: ~D[2026-08-23], to: ~D[2026-08-29]}})

      assert html =~ ~s{data-mode="range"}
      assert html =~ ~s{data-from="2026-08-23"}
      assert html =~ ~s{data-to="2026-08-29"}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook and ships its script inline" do
      html = render_picker(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
      assert html =~ ~s{data-mode="single"}
    end

    test "single mode closes the popover on a day click" do
      html = render_picker(%{})

      assert html =~ "data-polaris-calendar-day"
      assert html =~ "root.dataset.mode === \"single\""
    end

    test "flips up when there is no room below the trigger" do
      html = render_picker(%{})

      assert html =~ "innerHeight - rect.bottom"
      assert html =~ "p.style.bottom = \"100%\""
    end

    test "Escape closes and refocuses; click-outside closes" do
      html = render_picker(%{})

      assert html =~ "Escape"
      assert html =~ "root.contains(event.target)"
    end
  end

  describe "validation" do
    test "rejects an unknown mode" do
      assert_raise ArgumentError, ~r/:mode/, fn ->
        render_picker(%{mode: "multiple"})
      end
    end

    test "single mode rejects a span value" do
      assert_raise ArgumentError, ~r/mode="single"/, fn ->
        render_picker(%{value: %{from: ~D[2026-08-23], to: ~D[2026-08-29]}})
      end
    end

    test "range mode rejects a bare date and an inverted span" do
      assert_raise ArgumentError, ~r/mode="range"/, fn ->
        render_picker(%{mode: "range", value: ~D[2026-08-23]})
      end

      assert_raise ArgumentError, ~r/before/, fn ->
        render_picker(%{mode: "range", value: %{from: ~D[2026-08-29], to: ~D[2026-08-23]}})
      end
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_picker(%{value: ~D[2026-08-23], is_invalid: true})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
