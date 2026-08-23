defmodule PolarisUI.Components.PageContainerTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.PageContainer` — sizes,
  the shared measure/padding chrome, and pass-through attributes,
  mirroring the Supabase design system fragment `ui-patterns/PageContainer`.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.PageContainer

  describe "anatomy" do
    test "renders a div with the container chrome" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_container>Content</.page_container>
        """)

      assert html =~ ~s{data-polaris-page-container}
      container = class_of(html)

      assert container =~ "mx-auto"
      assert container =~ "w-full"
      assert container =~ "@container"
      assert container =~ "px-6"
      assert container =~ "xl:px-10"
    end

    test "renders inner content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_container>Database tables</.page_container>
        """)

      assert html =~ "Database tables"
    end
  end

  describe "sizes" do
    test "default is 1200px" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_container>Content</.page_container>
        """)

      assert class_of(html) =~ "max-w-[1200px]"
      assert html =~ ~s{data-size="default"}
    end

    test "small, large, and full map to their measures" do
      for {size, width} <- [
            {"small", "max-w-[768px]"},
            {"large", "max-w-[1600px]"},
            {"full", "max-w-none"}
          ] do
        assigns = %{size: size}

        html =
          rendered_to_string(~H"""
          <.page_container size={@size}>Content</.page_container>
          """)

        assert class_of(html) =~ width
        assert html =~ ~s{data-size="#{size}"}
      end
    end
  end

  describe "customization" do
    test "caller classes merge and globals pass through" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_container class="bg-surface-panel" data-track="x" id="shell">Content</.page_container>
        """)

      assert class_of(html) =~ "bg-surface-panel"
      assert class_of(html) =~ "max-w-[1200px]"
      assert html =~ ~s{data-track="x"}
      assert html =~ ~s{id="shell"}
    end
  end

  # Extracts the class attribute of the container element.
  defp class_of(html) do
    case Regex.run(~r{<div[^>]*class="([^"]*)"[^>]*>}, html, capture: :all_but_first) do
      [class] -> class
      nil -> flunk("no container div rendered")
    end
  end
end
