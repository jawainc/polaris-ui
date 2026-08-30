defmodule PolarisUI.Components.ProgressTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Progress` — the port of
  the Supabase design system Progress (shadcn over Radix): the 4px pill
  track, the translating fill, the determinate/indeterminate states, and
  the `role="progressbar"` accessibility contract.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Progress

  defp render_progress(assigns) do
    assigns =
      Map.merge(%{value: nil, max: 100, indeterminate: false, class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.progress value={@value} max={@max} indeterminate={@indeterminate} class={@class} {@rest} />
    """)
  end

  describe "anatomy" do
    test "renders the progressbar track with the source treatment" do
      html = render_progress(%{value: 33})

      assert html =~ ~s{role="progressbar"}
      assert html =~ ~s{data-polaris-progress}
      assert html =~ ~s{data-polaris-progress-indicator}

      class = track_class(html)
      assert class =~ "relative h-1 w-full overflow-hidden rounded-full"
      assert class =~ "bg-surface-border"
    end

    test "renders the fill with the source indicator treatment" do
      html = render_progress(%{value: 66})

      class = indicator_class(html)
      assert class =~ "h-full w-full flex-1 bg-content-primary"
      assert class =~ "transition-all"
    end

    test "the fill is decorative — the track is the a11y face" do
      html = render_progress(%{value: 66})

      assert indicator_chunk(html) =~ ~s{aria-hidden="true"}
    end
  end

  describe "determinate state" do
    test "translates the fill by the remaining percentage" do
      html = render_progress(%{value: 66})

      assert html =~ "transform: translateX(-34%)"
      assert html =~ ~s{data-state="determinate"}
    end

    test "value 100 fills the track completely" do
      html = render_progress(%{value: 100})

      assert html =~ "transform: translateX(-0%)"
    end

    test "value 0 parks the fill off-track" do
      html = render_progress(%{value: 0})

      assert html =~ "transform: translateX(-100%)"
    end

    test "integers coerce to the float attr" do
      html = render_progress(%{value: 25})

      assert html =~ "transform: translateX(-75%)"
    end

    test "max rescales the value" do
      html = render_progress(%{value: 30, max: 60})

      assert html =~ "transform: translateX(-50%)"
      assert html =~ ~s{aria-valuemax="60"}
    end

    test "out-of-range values clamp" do
      html = render_progress(%{value: 250})

      assert html =~ "transform: translateX(-0%)"
    end

    test "carries aria-valuenow and data-value" do
      html = render_progress(%{value: 66})

      assert html =~ ~s{aria-valuenow="66"}
      assert html =~ ~s{data-value="66"}
    end
  end

  describe "indeterminate state" do
    test "a nil value renders the Radix indeterminate data-state, parked" do
      html = render_progress(%{})

      assert html =~ ~s{data-state="indeterminate"}
      refute html =~ ~s{aria-valuenow=}
      refute html =~ "animate-progress-indeterminate"
    end

    test "indeterminate sweeps the half-width segment on the token animation" do
      html = render_progress(%{indeterminate: true})

      assert html =~ ~s{data-state="indeterminate"}
      class = indicator_class(html)
      assert class =~ "w-1/2"
      assert class =~ "animate-progress-indeterminate"
    end

    test "indeterminate drops the inline transform" do
      html = render_progress(%{indeterminate: true})

      refute html =~ "translateX(-"
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html =
        render_progress(%{rest: %{"aria-label" => "Upload progress", "data-testid" => "upload"}})

      assert html =~ ~s{aria-label="Upload progress"}
      assert html =~ ~s{data-testid="upload"}
    end

    test "caller classes merge onto the track and win conflicts via cn/1" do
      html = render_progress(%{value: 10, class: "h-2 w-[60%]"})

      class = track_class(html)
      assert class =~ "h-2 w-[60%]"
      refute class =~ "h-1 w-full"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_progress(%{value: 33})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp track_class(html), do: class_of(html, ~s{data-polaris-progress data-})

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

  defp indicator_chunk(html) do
    [_, rest | _] = String.split(html, "data-polaris-progress-indicator", parts: 2)
    String.split(rest, ">") |> Enum.at(0)
  end

  defp indicator_class(html) do
    indicator_chunk(html)
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
