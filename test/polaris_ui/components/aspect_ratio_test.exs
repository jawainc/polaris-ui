defmodule PolarisUI.Components.AspectRatioTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.AspectRatio` — the port
  of the Supabase design system AspectRatio (a re-export of the Radix
  primitive): a two-element padding-bottom wrapper with an
  absolutely-positioned inner div carrying the caller's attributes.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.AspectRatio

  defp render_ratio(assigns) do
    assigns =
      Map.merge(%{ratio: 1.0, class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.aspect_ratio ratio={@ratio} class={@class} {assigns[:rest]}>
      {assigns[:content]}
    </.aspect_ratio>
    """)
  end

  describe "anatomy" do
    test "renders the two-element padding-bottom structure" do
      html = render_ratio(%{content: {:safe, "<img src=\"x.jpg\" alt=\"Photo\" />"}})

      assert html =~ ~s{data-polaris-aspect-ratio-wrapper}
      assert html =~ ~s{style="position: relative; width: 100%; padding-bottom: 100.0%"}

      # the inner div is absolutely positioned on all sides and holds the content
      assert html =~ ~s{style="position: absolute; top: 0; right: 0; bottom: 0; left: 0;"}
      assert html =~ ~s{src="x.jpg"}
      # inner follows the wrapper
      wrapper = position(html, "data-polaris-aspect-ratio-wrapper")
      inner = position(html, "position: absolute")
      assert is_integer(wrapper) and is_integer(inner) and wrapper < inner
    end

    test "the wrapper is unstyled except for the inline ratio math" do
      html = render_ratio(%{})

      wrapper = wrapper_attrs(html)
      # the wrapper carries no class — caller classes must never break the ratio
      refute wrapper =~ ~s{class=}
    end
  end

  describe "ratio" do
    test "16/9 renders the canonical 56.25% padding" do
      html = render_ratio(%{ratio: 16 / 9})

      assert html =~ "padding-bottom: 56.25%"
    end

    test "common ratios map to their exact percentages" do
      ratios = %{
        1.0 => "100.0%",
        (4 / 3) => "75.0%",
        (3 / 2) => "66.6667%",
        (21 / 9) => "42.8571%"
      }

      for {ratio, padding} <- ratios do
        html = render_ratio(%{ratio: ratio})
        assert html =~ "padding-bottom: #{padding}"
      end
    end

    test "integer ratios divide cleanly" do
      html = render_ratio(%{ratio: 2})

      assert html =~ "padding-bottom: 50.0%"
    end

    test "rejects zero, negative, and non-numeric ratios" do
      for ratio <- [0, -1.5, "16/9", nil] do
        assert_raise ArgumentError, ~r/:ratio/, fn ->
          render_ratio(%{ratio: ratio})
        end
      end
    end
  end

  describe "attributes" do
    test "class lands on the inner div, never the wrapper" do
      html = render_ratio(%{class: "rounded-md bg-surface-panel"})

      inner = inner_class(html)
      assert inner =~ "rounded-md"
      assert inner =~ "bg-surface-panel"

      wrapper = wrapper_attrs(html)
      refute wrapper =~ "rounded-md"
    end

    test "forwards global attributes via rest to the inner div" do
      html = render_ratio(%{rest: %{"data-testid" => "media-frame", id: "frame"}})

      assert html =~ ~s{data-testid="media-frame"}
      assert html =~ ~s{id="frame"}
    end

    test "merges a caller style before the primitive positioning, which wins" do
      html = render_ratio(%{rest: %{style: "border-radius: 8px;"}})

      assert html =~
               ~s{style="border-radius: 8px; position: absolute; top: 0; right: 0; bottom: 0; left: 0;"}
    end

    test "a style without a trailing semicolon still merges cleanly" do
      html = render_ratio(%{rest: %{style: "overflow: hidden"}})

      assert html =~ ~s{style="overflow: hidden; position: absolute}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_ratio(%{class: "rounded-md"})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  # First byte offset of `pattern` in `html`, or nil — for ordering checks.
  defp position(html, pattern) do
    case :binary.match(html, pattern) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  # The attribute chunk of the wrapper element (up to the first `>`).
  defp wrapper_attrs(html) do
    [_, after_marker | _] = String.split(html, "data-polaris-aspect-ratio-wrapper", parts: 2)

    after_marker |> String.split(">") |> List.first()
  end

  # The class attribute of the inner (absolutely-positioned) div — class
  # renders before style, so search the chunk preceding the marker.
  defp inner_class(html) do
    [before_inner | _] = String.split(html, "position: absolute", parts: 2)

    before_inner
    |> String.split(~s{class="})
    |> List.last()
    |> String.split("\"")
    |> List.first()
  end
end
