defmodule PolarisUI.Components.SeparatorTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Separator` — the port
  of the Supabase design system Separator (shadcn over Radix): the
  1px hairline, the orientation sizing, and the decorative/semantic
  accessibility contract.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Separator

  defp render_separator(assigns) do
    assigns =
      Map.merge(%{orientation: "horizontal", decorative: true, class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.separator orientation={@orientation} decorative={@decorative} class={@class} {@rest} />
    """)
  end

  describe "anatomy" do
    test "renders the hairline with the source treatment" do
      html = render_separator(%{})

      assert html =~ ~s{data-polaris-separator}
      class = separator_class(html)
      assert class =~ "shrink-0 bg-surface-border"
    end

    test "horizontal is a full-width 1px line" do
      html = render_separator(%{orientation: "horizontal"})

      assert html =~ ~s{data-orientation="horizontal"}
      class = separator_class(html)
      assert class =~ "h-px w-full"
      refute class =~ "h-full w-px"
    end

    test "vertical is a full-height 1px line" do
      html = render_separator(%{orientation: "vertical"})

      assert html =~ ~s{data-orientation="vertical"}
      class = separator_class(html)
      assert class =~ "h-full w-px"
      refute class =~ "h-px w-full"
    end
  end

  describe "semantics" do
    test "decorative (the source default) is removed from the a11y tree" do
      html = render_separator(%{decorative: true})

      assert html =~ ~s{role="none"}
      refute html =~ ~s{aria-orientation}
    end

    test "semantic carries role=separator" do
      html = render_separator(%{decorative: false})

      assert html =~ ~s{role="separator"}
    end

    test "semantic vertical adds aria-orientation (horizontal is the ARIA default)" do
      html = render_separator(%{decorative: false, orientation: "vertical"})

      assert html =~ ~s{aria-orientation="vertical"}

      horizontal = render_separator(%{decorative: false, orientation: "horizontal"})
      refute horizontal =~ ~s{aria-orientation}
    end

    test "data-orientation is always rendered, decorative or not" do
      html = render_separator(%{decorative: true, orientation: "vertical"})

      assert html =~ ~s{data-orientation="vertical"}
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html =
        render_separator(%{rest: %{"data-testid" => "divider", "aria-label" => "Section break"}})

      assert html =~ ~s{data-testid="divider"}
      assert html =~ ~s{aria-label="Section break"}
    end

    test "caller classes merge and win conflicts via cn/1" do
      html = render_separator(%{orientation: "vertical", class: "w-0.5 bg-surface-border-hover"})

      class = separator_class(html)
      assert class =~ "bg-surface-border-hover"
      refute class =~ "bg-surface-border "
      assert class =~ "h-full"
    end

    test "rejects unknown orientations at render time" do
      assert_raise ArgumentError, ~r/invalid value for :orientation/, fn ->
        render_separator(%{orientation: "diagonal"})
      end
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_separator(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp separator_class(html), do: class_of(html, "data-polaris-separator")

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
