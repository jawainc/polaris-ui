defmodule PolarisUI.Components.NavMenuTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.NavMenu` — menu anatomy,
  active/inactive item states, and pass-through attributes, mirroring the
  Supabase design system `NavMenu` primitive.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.NavMenu

  describe "anatomy" do
    test "renders a nav with a menu list" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.nav_menu>
          <.nav_menu_item><button type="button">Overview</button></.nav_menu_item>
        </.nav_menu>
        """)

      assert html =~ "<nav"
      assert html =~ ~s{data-polaris-nav-menu}
      assert html =~ ~s{role="menu"}
      assert html =~ ~s{data-polaris-nav-menu-list}
      assert html =~ ~s{data-polaris-nav-menu-item}
      assert html =~ "Overview"
    end

    test "the nav carries the bottom border and the list flexes with the fragment's gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.nav_menu>
          <.nav_menu_item><button type="button">Overview</button></.nav_menu_item>
        </.nav_menu>
        """)

      nav = class_of(html, ~s{dir="ltr"})
      assert nav =~ "border-b"
      assert nav =~ "border-surface-border"

      list = class_of(html, "data-polaris-nav-menu-list")
      assert list =~ "flex"
      assert list =~ "gap-5"
    end
  end

  describe "item states" do
    test "inactive items render muted with hover brightening" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.nav_menu>
          <.nav_menu_item><button type="button">Logs</button></.nav_menu_item>
        </.nav_menu>
        """)

      assert html =~ ~s{aria-selected="false"}
      assert html =~ ~s{data-state="inactive"}

      item = class_of(html, "data-polaris-nav-menu-item")
      assert item =~ "text-content-muted"
      assert item =~ "hover:text-content-primary"
      assert item =~ "border-b-2"
      assert item =~ "border-transparent"
    end

    test "active items render selected with the bright label and underline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.nav_menu>
          <.nav_menu_item is_active><button type="button">Overview</button></.nav_menu_item>
        </.nav_menu>
        """)

      assert html =~ ~s{aria-selected="true"}
      assert html =~ ~s{data-state="active"}

      item = class_of(html, "data-polaris-nav-menu-item")
      assert item =~ "data-[state=active]:text-content-primary"
      assert item =~ "data-[state=active]:border-content-primary"
    end

    test "items carry the source's focus-ring treatment" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.nav_menu>
          <.nav_menu_item><button type="button">Overview</button></.nav_menu_item>
        </.nav_menu>
        """)

      item = class_of(html, "data-polaris-nav-menu-item")

      assert item =~
               "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"

      assert item =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
      assert item =~ "disabled:pointer-events-none disabled:opacity-50"
    end
  end

  describe "customization" do
    test "caller classes merge and globals pass through" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.nav_menu class="max-w-md" aria-label="Sections" data-track="x">
          <.nav_menu_item class="ml-2" data-section="logs">
            <button type="button">Logs</button>
          </.nav_menu_item>
        </.nav_menu>
        """)

      assert class_of(html, ~s{dir="ltr"}) =~ "max-w-md"
      assert class_of(html, "data-polaris-nav-menu-item") =~ "ml-2"
      assert html =~ ~s{aria-label="Sections"}
      assert html =~ ~s{data-track="x"}
      assert html =~ ~s{data-section="logs"}
    end

    test "an explicit aria-label via rest wins over the label attr form" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.nav_menu label="Page sections">
          <.nav_menu_item><button type="button">Overview</button></.nav_menu_item>
        </.nav_menu>
        """)

      assert html =~ ~s{aria-label="Page sections"}
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
