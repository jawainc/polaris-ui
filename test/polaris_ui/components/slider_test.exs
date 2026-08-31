defmodule PolarisUI.Components.SliderTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Slider` — the port of
  the Supabase design system Slider: the Radix thumbs/track/range with
  pointer and keyboard contracts.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Slider

  @hook "PolarisUI.Components.Slider.Slider"

  defp render_slider(assigns) do
    assigns =
      Map.merge(
        %{
          id: "price",
          value: nil,
          min: 0.0,
          max: 100.0,
          step: 1.0,
          disabled: false,
          name: nil,
          on_change: nil,
          on_commit: nil,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.slider
      id={@id}
      value={@value}
      min={@min}
      max={@max}
      step={@step}
      disabled={@disabled}
      name={@name}
      on_change={@on_change}
      on_commit={@on_commit}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "anatomy" do
    test "renders the source's root, track, and thumbs" do
      html = render_slider(%{value: [33]})

      root = marker_class(html, "data-polaris-slider data-min")
      assert root =~ "relative flex w-full touch-none select-none items-center"
      assert html =~ "data-polaris-slider-track"
      assert html =~ "data-polaris-slider-thumb"
    end

    test "the track is the 4px pill on the muted border tone" do
      html = render_slider(%{value: [33]})

      track = marker_class(html, "data-polaris-slider-track")
      assert track =~ "relative h-1 w-full grow overflow-hidden rounded-full bg-surface-border"
    end

    test "the range fills between the first and last thumb in muted foreground" do
      html = render_slider(%{value: [20, 80]})

      range = marker_class(html, "data-polaris-slider-range")
      assert range =~ "absolute h-full bg-content-secondary"
      assert html =~ "left: 20%; right: 20%"
    end

    test "a single thumb's range runs to the far end" do
      html = render_slider(%{value: [33]})

      assert html =~ "left: 0%; right: 67%"
    end

    test "the thumb is the 20px disc — foreground fill, ground ring, focus ring" do
      html = render_slider(%{value: [33]})

      thumb = marker_class(html, "data-polaris-slider-thumb data-index")
      assert thumb =~ "block h-5 w-5 rounded-full border-2 border-surface-ground bg-content-primary"
      assert thumb =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert thumb =~ "hover:bg-brand-emerald"
      assert thumb =~ "active:scale-95"
      assert thumb =~ "disabled:pointer-events-none disabled:opacity-50"
    end
  end

  describe "values" do
    test "the value list length is the thumb count" do
      html = render_slider(%{value: [20, 50, 80]})

      assert count_marker(html, "data-polaris-slider-thumb data-index") == 3
    end

    test "a single number normalizes to one thumb" do
      html = render_slider(%{value: 33})

      assert count_marker(html, "data-polaris-slider-thumb data-index") == 1
    end

    test "a bare slider inherits the source's full-range default" do
      html = render_slider(%{})

      assert count_marker(html, "data-polaris-slider-thumb data-index") == 2
      assert html =~ "left: 0%; right: 0%"
    end

    test "thumb positions derive from min/max with the half-thumb offset" do
      html = render_slider(%{value: [75], min: 0, max: 300})

      assert html =~ "left: calc(25% - 2.5px)"
    end

    test "float steps render without trailing zeros" do
      html = render_slider(%{value: [2.5], step: 2.5})

      assert html =~ ~s{data-step="2.5"}
      assert html =~ ~s{aria-valuenow="2.5"}
    end
  end

  describe "disabled" do
    test "dims the root and drops thumbs from the tab order" do
      html = render_slider(%{value: [33], disabled: true})

      root = marker_class(html, "data-polaris-slider data-min")
      assert root =~ "opacity-50 pointer-events-none"
      assert html =~ ~s{data-disabled="true"}
      assert html =~ ~s{tabindex="-1"}
      assert html =~ ~s{aria-disabled="true"}
    end

    test "enabled thumbs are tab stops" do
      html = render_slider(%{value: [33]})

      assert html =~ ~s{tabindex="0"}
    end
  end

  describe "forms" do
    test "name renders one hidden range input per thumb" do
      html = render_slider(%{value: [20, 80], name: "price"})

      assert count_marker(html, ~s{type="range" name="price"}) == 2
      assert html =~ ~s{value="20"}
      assert html =~ ~s{value="80"}
      assert html =~ "aria-hidden=\"true\""
    end

    test "no inputs without a name" do
      html = render_slider(%{value: [33]})

      refute html =~ "<input", "hidden range input leaked without a name"
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_slider(%{value: [33]})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "dragging rides locally and pushes on release" do
      html = render_slider(%{value: [33], on_change: "price-change", on_commit: "price-commit"})

      assert html =~ ~s{data-change-event="price-change"}
      assert html =~ ~s{data-commit-event="price-commit"}
      assert html =~ "pointerdown"
      assert html =~ "pointermove"
      assert html =~ "pushEvent(name, { value: values })"
    end

    test "pressing the track moves the nearest thumb" do
      html = render_slider(%{value: [20, 80]})

      assert html =~ "_nearestThumb"
      assert html =~ "Math.abs(center - position)"
    end

    test "keyboard follows the Radix contract — arrows, shift x10, Page, Home/End" do
      html = render_slider(%{value: [33]})

      assert html =~ "keydown"
      assert html =~ ~s{case "ArrowLeft"}
      assert html =~ ~s{case "ArrowRight"}
      assert html =~ "event.shiftKey ? 10 : 1"
      assert html =~ ~s{case "PageUp"}
      assert html =~ ~s{case "Home"}
      assert html =~ ~s{case "End"}
      assert html =~ "preventDefault"
    end

    test "values snap to the step and clamp to the axis" do
      html = render_slider(%{value: [33], min: 0, max: 10, step: 2})

      assert html =~ ~s{data-min="0"}
      assert html =~ ~s{data-max="10"}
      assert html =~ ~s{data-step="2"}
      assert html =~ "Math.round((value - config.min) / config.step) * config.step + config.min"
      assert html =~ "Math.min(config.max, Math.max(config.min, snapped))"
    end
  end

  describe "accessibility" do
    test "each thumb is a slider role with the full value contract" do
      html = render_slider(%{value: [30], min: 0, max: 100})

      assert html =~ ~s{role="slider"}
      assert html =~ ~s{aria-valuemin="0"}
      assert html =~ ~s{aria-valuenow="30"}
      assert html =~ ~s{aria-valuemax="100"}
      assert html =~ ~s{aria-orientation="horizontal"}
    end

    test "thumb ids derive from the root" do
      html = render_slider(%{value: [30, 70]})

      assert html =~ ~s{id="price-thumb-0"}
      assert html =~ ~s{id="price-thumb-1"}
    end

    test "forwards global attributes for labelling" do
      html = render_slider(%{value: [33], rest: %{"aria-label" => "Price range"}})

      assert html =~ ~s{aria-label="Price range"}
    end
  end

  describe "attributes" do
    test "caller classes merge onto the root" do
      html = render_slider(%{value: [33], class: "w-3/5"})

      assert html =~ "w-3/5"
    end

    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_slider(%{value: [33]})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  # The class attribute of the element carrying the given marker.
  defp marker_class(html, marker) do
    [_, after_marker | _] = String.split(html, marker, parts: 2)

    class =
      case :binary.match(after_marker, ~s{class="}) do
        {index, _} -> binary_part(after_marker, index + 7, byte_size(after_marker) - index - 7)
        :nomatch -> ""
      end

    class |> String.split(~s{"}) |> List.first()
  end

  defp count_marker(html, marker) do
    html |> String.split(marker) |> length() |> Kernel.-(1)
  end
end
