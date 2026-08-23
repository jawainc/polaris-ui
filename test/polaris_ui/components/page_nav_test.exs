defmodule PolarisUI.Components.PageNavTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.PageNav` — the chrome
  row anatomy, the nav-stretching child selectors, and pass-through
  attributes, mirroring the Supabase design system fragment
  `ui-patterns/PageNav`.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.NavMenu
  import PolarisUI.Components.PageNav

  describe "anatomy" do
    test "renders the chrome row wrapping the menu wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_nav>
          <.nav_menu>
            <.nav_menu_item><button type="button">Overview</button></.nav_menu_item>
          </.nav_menu>
        </.page_nav>
        """)

      assert html =~ ~s{data-polaris-page-nav}
      assert html =~ ~s{data-polaris-page-nav-menu}
      assert html =~ "Overview"
    end

    test "the row is a full page container with the chrome treatment" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_nav>
          <.nav_menu>
            <.nav_menu_item><button type="button">Overview</button></.nav_menu_item>
          </.nav_menu>
        </.page_nav>
        """)

      row = class_of(html, "data-polaris-page-nav")
      assert row =~ "flex"
      assert row =~ "min-h-[var(--header-height,2.75rem)]"
      assert row =~ "items-center"
      assert row =~ "border-b"
      assert row =~ "border-surface-border"
      # Chrome rows tighten the container padding to 16px everywhere.
      assert row =~ "px-4"
      assert row =~ "xl:px-4"
      refute row =~ "px-6"

      # size=full on the container: no max-width constraint survives.
      assert html =~ ~s{data-size="full"}
      assert row =~ "max-w-none"
      refute row =~ "max-w-["
    end
  end

  describe "nav stretching" do
    test "the menu wrapper stretches a slotted nav_menu to the header height" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_nav>
          <.nav_menu>
            <.nav_menu_item><button type="button">Overview</button></.nav_menu_item>
          </.nav_menu>
        </.page_nav>
        """)

      menu = class_of(html, "data-polaris-page-nav-menu")

      assert menu =~ "flex"
      assert menu =~ "w-full"
      assert menu =~ "min-h-[var(--header-height,2.75rem)]"
      assert menu =~ "items-center"

      # The fragment's child selectors (HTML-escaped in the class attr).
      assert menu =~ "[&amp;&gt;nav]:flex"
      assert menu =~ "[&amp;&gt;nav]:border-b-0"
      assert menu =~ "[&amp;&gt;nav&gt;ul]:h-full"
      assert menu =~ "[&amp;&gt;nav&gt;ul&gt;li]:h-full"
    end

    test "the slotted nav renders inside the wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_nav>
          <.nav_menu label="Sections">
            <.nav_menu_item is_active><button type="button">Logs</button></.nav_menu_item>
          </.nav_menu>
        </.page_nav>
        """)

      assert html =~ ~s{data-polaris-nav-menu}
      assert html =~ ~s{data-state="active"}
      assert html =~ "Logs"
    end
  end

  describe "customization" do
    test "caller classes merge onto the menu wrapper and globals pass through" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_nav class="max-w-md" data-track="x">
          <.nav_menu>
            <.nav_menu_item><button type="button">Overview</button></.nav_menu_item>
          </.nav_menu>
        </.page_nav>
        """)

      assert class_of(html, "data-polaris-page-nav-menu") =~ "max-w-md"
      assert html =~ ~s{data-track="x"}
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
