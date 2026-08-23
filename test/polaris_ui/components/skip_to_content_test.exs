defmodule PolarisUI.Components.SkipToContentTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.SkipToContent` — the
  Supabase skip-link fragment port (`ui-patterns/SkipToContent`): wrapper
  anatomy, off-screen / reveal mechanics, the label fallback, and the
  landmark href contract.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.SkipToContent

  defp render_skip(attrs \\ []) do
    assigns = %{attrs: Map.merge(%{href: "#main"}, Map.new(attrs))}

    rendered_to_string(~H"""
    <.skip_to_content {@attrs} />
    """)
  end

  describe "anatomy" do
    test "renders the positioning wrapper with an anchor inside, no <button>" do
      html = render_skip()

      assert html =~ "data-polaris-skip"
      assert html =~ "<a"
      refute html =~ "<button"
    end

    test "the anchor carries the passed href" do
      assert render_skip(href: "#docs-content") =~ ~s{href="#docs-content"}
    end
  end

  describe "off-screen placement" do
    test "is fully translated off-screen by default" do
      assert class_of(render_skip(), "data-polaris-skip") =~ "-translate-y-full"
    end

    test "pins to the top-left corner above everything else" do
      cls = class_of(render_skip(), "data-polaris-skip")

      assert cls =~ "fixed"
      assert cls =~ "top-0"
      assert cls =~ "left-[10px]"
      assert cls =~ "z-[100]"
    end

    test "w-fit keeps the wrapper hugging the link" do
      # w-fit: the wrapper is a block div by default and would otherwise span
      # the full content column — a skip link should hug its label.
      assert class_of(render_skip(), "data-polaris-skip") =~ "w-fit"
    end
  end

  describe "reveal on focus" do
    test "slides into view via focus-within translate" do
      cls = class_of(render_skip(), "data-polaris-skip")

      assert cls =~ "focus-within:translate-y-[10px]"
      # the resting position stays off-screen next to the reveal utility
      assert cls =~ "-translate-y-full"
    end
  end

  describe "transition" do
    test "animates the transform over 200ms ease-out" do
      cls = class_of(render_skip(), "data-polaris-skip")

      assert cls =~ "transition-transform"
      assert cls =~ "duration-200"
      assert cls =~ "ease-out"
    end
  end

  describe "label" do
    test "defaults to \"Skip to content\" when no do-block is given" do
      assert render_skip() =~ "Skip to content"
    end

    test "falls back to the default label when the do-block is blank" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.skip_to_content href="#main"></.skip_to_content>
        """)

      assert html =~ "Skip to content"
    end

    test "renders a custom label from the inner block" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.skip_to_content href="#docs-content">Skip to docs</.skip_to_content>
        """)

      assert html =~ "Skip to docs"
      assert html =~ ~s{href="#docs-content"}
    end
  end

  describe "button rendering" do
    test "renders the tiny default button variant as the anchor" do
      html = render_skip()

      # tiny size scale
      assert html =~ "h-[26px]"
      assert html =~ "text-xs"
      # default variant surface
      assert html =~ "bg-surface-panel"
      assert html =~ "border-surface-border"
      assert html =~ "hover:bg-surface-panel-hover"
    end
  end

  describe "class merging and rest forwarding" do
    test "caller classes win over wrapper defaults through cn/1" do
      cls = class_of(render_skip(class: "left-[16px]"), "data-polaris-skip")

      assert cls =~ "left-[16px]"
      refute cls =~ "left-[10px]"
    end

    test "forwards global attributes to the wrapper via rest" do
      html = render_skip("data-testid": "skip-link")

      assert html =~ ~s{data-testid="skip-link"}
    end
  end

  describe "accessibility" do
    test "renders a real focusable anchor carrying the hash href" do
      html = render_skip(href: "#main")

      assert html =~ "<a"
      assert html =~ ~s{href="#main"}
      # nothing removes the link from the tab order — it must be reachable via Tab
      refute html =~ ~s{tabindex="-1"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      refute render_skip(class: "w-full") =~ "#["
    end
  end

  # Extracts the class attribute of the element carrying the marker,
  # regardless of attribute order within the tag.
  defp class_of(html, marker) do
    marker = Regex.escape(marker)

    class_after = ~r{<[^>]*#{marker}(?![\w-])[^>]*?class="([^"]*)"[^>]*>}
    class_before = ~r{<[^>]*class="([^"]*)"[^>]*?#{marker}(?![\w-])[^>]*>}

    cond do
      match = Regex.run(class_after, html, capture: :all_but_first) -> hd(match)
      match = Regex.run(class_before, html, capture: :all_but_first) -> hd(match)
      true -> flunk("no element with marker #{marker}")
    end
  end
end
