defmodule PolarisUI.Components.ScrollAreaTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.ScrollArea` — the
  port of the Supabase design system ScrollArea (shadcn over Radix):
  the hidden-native-scroll viewport, the overlay scrollbar tracks and
  pill thumbs, and the visibility types.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.ScrollArea

  defp render_scroll_area(assigns) do
    assigns =
      Map.merge(
        %{id: "tags", orientation: "vertical", type: "hover", class: nil, rest: %{}},
        assigns
      )

    rendered_to_string(~H"""
    <.scroll_area id={@id} orientation={@orientation} type={@type} class={@class} {@rest}>
      content
    </.scroll_area>
    """)
  end

  describe "anatomy" do
    test "renders the root, viewport, and scrollbar markers" do
      html = render_scroll_area(%{})

      assert html =~ ~s{id="tags"}
      assert html =~ ~s{data-polaris-scroll-area}
      assert html =~ ~s{data-polaris-scroll-viewport}
      assert html =~ ~s{data-polaris-scroll-bar}
      assert html =~ ~s{data-polaris-scroll-thumb}
    end

    test "the root is the source's overflow-hidden shell" do
      html = render_scroll_area(%{})

      class = root_class(html)
      assert class =~ "relative overflow-hidden"
    end

    test "caller chrome (the demo's sized bordered card) merges onto the root" do
      html = render_scroll_area(%{class: "h-72 w-48 rounded-md border"})

      class = root_class(html)
      assert class =~ "h-72 w-48 rounded-md border"
    end

    test "the viewport scrolls natively with native scrollbars hidden" do
      html = render_scroll_area(%{})

      class = viewport_class(html)
      assert class =~ "h-full w-full overflow-auto"
      assert class =~ "[scrollbar-width:none]"
      assert class =~ "[&amp;::-webkit-scrollbar]:hidden"
      assert class =~ "rounded-[inherit]"
    end

    test "content keeps its natural width (the Radix min-width sizing)" do
      html = render_scroll_area(%{})

      assert html =~ ~s{class="min-w-full"}
    end

    test "the track is the source's 10px overlay with the inset thumb" do
      html = render_scroll_area(%{})

      class = bar_class(html)
      assert class =~ "w-2.5"
      assert class =~ "border-l border-l-transparent"
      assert class =~ "p-px"
      assert class =~ "touch-none select-none"
    end

    test "the thumb is the rounded pill on the border token" do
      html = render_scroll_area(%{})

      class = thumb_class(html)
      assert class =~ "relative flex-1 rounded-full bg-surface-border"
    end
  end

  describe "orientation" do
    test "vertical (the source default) renders only the vertical bar" do
      html = render_scroll_area(%{orientation: "vertical"})

      assert html =~ ~s{data-orientation="vertical"}
      refute html =~ ~s{data-orientation="horizontal"}
    end

    test "horizontal renders the horizontal track (the explicit ScrollBar child)" do
      html = render_scroll_area(%{orientation: "horizontal"})

      assert html =~ ~s{data-orientation="horizontal"}
      refute html =~ ~s{data-orientation="vertical"}

      class = bar_class(html)
      assert class =~ "h-2.5 w-full"
      assert class =~ "border-t border-t-transparent"
    end

    test "both renders the vertical and horizontal bars" do
      html = render_scroll_area(%{orientation: "both"})

      assert html =~ ~s{data-orientation="vertical"}
      assert html =~ ~s{data-orientation="horizontal"}
    end

    test "rejects unknown orientations at render time" do
      assert_raise ArgumentError, ~r/invalid value for :orientation/, fn ->
        render_scroll_area(%{orientation: "diagonal"})
      end
    end
  end

  describe "visibility types" do
    test "hover is the default and carries the 600ms hide semantics" do
      html = render_scroll_area(%{})

      assert html =~ ~s{data-type="hover"}
    end

    test "the visibility types ride data-state starting hidden" do
      html = render_scroll_area(%{type: "scroll"})

      assert html =~ ~s{data-type="scroll"}
      assert html =~ ~s{data-state="hidden"}

      class = bar_class(html)
      assert class =~ "opacity-0"
      assert class =~ "data-[state=visible]:opacity-100"
    end

    test "thumbs only appear when there is something to scroll" do
      html = render_scroll_area(%{})

      assert html =~ ~s{data-overflow="false"}

      class = bar_class(html)
      assert class =~ "data-[overflow=false]:hidden"
    end

    test "rejects unknown types at render time" do
      assert_raise ArgumentError, ~r/invalid value for :type/, fn ->
        render_scroll_area(%{type: "sometimes"})
      end
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_scroll_area(%{rest: %{"aria-label" => "Tags", "data-testid" => "tags-list"}})

      assert html =~ ~s{aria-label="Tags"}
      assert html =~ ~s{data-testid="tags-list"}
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_scroll_area(%{})

      assert html =~ ~s{data-phx-runtime-hook="PolarisUI.Components.ScrollArea.Root"}
      assert html =~ ~s{window["phx_hook_PolarisUI.Components.ScrollArea.Root"]}
      assert html =~ "mounted()"
    end

    test "the hook re-measures on scroll, resize, and LiveView patches" do
      html = render_scroll_area(%{})

      assert html =~ "updated()"
      assert html =~ "ResizeObserver"
      assert html =~ "HIDE_DELAY"
      assert html =~ "600"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_scroll_area(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp root_class(html), do: class_of(html, "data-polaris-scroll-area data-type")

  defp viewport_class(html), do: class_of(html, "data-polaris-scroll-viewport")

  defp bar_class(html), do: class_of(html, "data-polaris-scroll-bar")

  defp thumb_class(html), do: class_of(html, "data-polaris-scroll-thumb")

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
