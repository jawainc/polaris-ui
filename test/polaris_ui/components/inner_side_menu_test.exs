defmodule PolarisUI.Components.InnerSideMenuTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.InnerSideMenu` — the
  nav wrapper, section titles, collapsible groups, items (nav + data),
  separators, loading rows, the search field, the sort dropdown, and the
  empty panel, mirroring the Supabase design system fragment
  `ui-patterns/InnerSideMenu`.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.InnerSideMenu

  @group_hook "PolarisUI.Components.InnerSideMenu.Group"
  @sort_hook "PolarisUI.Components.InnerSideMenu.Sort"

  describe "nav wrapper" do
    test "renders a nav landmark with an accessible name" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu label="Project navigation">
          <.inner_side_menu_item href="/db">Database</.inner_side_menu_item>
        </.inner_side_menu>
        """)

      assert html =~ ~s{<nav}
      assert html =~ ~s{aria-label="Project navigation"}
      assert html =~ ~s{data-polaris-inner-side-menu}
    end
  end

  describe "static title" do
    test "renders the mono-uppercase section header" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_title>Analytics</.inner_side_menu_title>
        """)

      assert html =~ "Analytics"
      assert html =~ ~s{data-polaris-ism-title}

      title = class_of(html, "data-polaris-ism-title")

      assert title =~ "font-mono"
      assert title =~ "uppercase"
      assert title =~ "tracking-wide"
      assert title =~ "text-content-muted"
      assert title =~ "hover:text-content-primary"
    end
  end

  describe "collapsible group" do
    test "renders trigger button and content with hook wiring" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_collapsible id="development" title="Development">
          <.inner_side_menu_item href="/db">Database</.inner_side_menu_item>
        </.inner_side_menu_collapsible>
        """)

      assert html =~ ~s{id="development"}
      assert html =~ ~s{id="development-content"}
      assert html =~ ~s{phx-hook="#{@group_hook}"}
      assert html =~ ~s{data-polaris-ism-collapsible-trigger}
      assert html =~ ~s{data-polaris-ism-collapsible-content}
      assert html =~ "Development"
    end

    test "closed by default with aria wiring, default_open flips it" do
      assigns = %{}

      closed =
        rendered_to_string(~H"""
        <.inner_side_menu_collapsible id="sec" title="T">
          <.inner_side_menu_item href="/a">A</.inner_side_menu_item>
        </.inner_side_menu_collapsible>
        """)

      assert closed =~ ~s{data-state="closed"}
      assert closed =~ ~s{aria-expanded="false"}
      assert closed =~ ~s{aria-controls="sec-content"}

      open =
        rendered_to_string(~H"""
        <.inner_side_menu_collapsible id="sec" title="T" default_open>
          <.inner_side_menu_item href="/a">A</.inner_side_menu_item>
        </.inner_side_menu_collapsible>
        """)

      assert open =~ ~s{data-state="open"}
      assert open =~ ~s{aria-expanded="true"}
    end

    test "the trigger carries the chevron that rotates open and mono title styling" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_collapsible id="sec" title="T">
          <.inner_side_menu_item href="/a">A</.inner_side_menu_item>
        </.inner_side_menu_collapsible>
        """)

      trigger = class_of(html, "data-polaris-ism-collapsible-trigger")

      assert trigger =~ "font-mono"
      assert trigger =~ "uppercase"
      assert html =~ "group-data-[state=open]/ism:rotate-90"
      assert html =~ "transition-all"
    end
  end

  describe "nav item" do
    test "renders an anchor with the fragment geometry" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_item href="/project/api">API</.inner_side_menu_item>
        """)

      assert html =~ ~s{<a href="/project/api"}
      assert html =~ "API"

      item = class_of(html, "data-polaris-ism-item")

      assert item =~ "h-7"
      assert item =~ "pl-3"
      assert item =~ "pr-2"
      assert item =~ "rounded-md"
      assert item =~ "justify-between"
    end

    test "inactive: muted text with hover fill; no aria-current" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_item href="/db">Database</.inner_side_menu_item>
        """)

      item = class_of(html, "data-polaris-ism-item")

      assert item =~ "text-content-secondary"
      assert item =~ "hover:bg-surface-panel-hover"
      assert item =~ "hover:text-content-primary"
      refute html =~ "aria-current"
    end

    test "active: selection fill and aria-current=page" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_item href="/db" is_active>Database</.inner_side_menu_item>
        """)

      item = class_of(html, "data-polaris-ism-item")

      assert item =~ "bg-content-primary/10"
      assert item =~ "text-content-primary"
      assert html =~ ~s{aria-current="page"}
      assert html =~ ~s{data-active="true"}
    end

    test "force_hover_state pins the hover background" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_item href="/db" force_hover_state>Database</.inner_side_menu_item>
        """)

      item = class_of(html, "data-polaris-ism-item")

      assert item =~ "bg-surface-panel-hover"
      refute item =~ "hover:bg-surface-panel-hover"
    end

    test "items carry the shared focus-visible ring" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_item href="/db">Database</.inner_side_menu_item>
        """)

      assert html =~ "focus-visible:ring-2"
      assert html =~ "focus-visible:ring-brand-emerald"
    end
  end

  describe "data item" do
    test "active by default with the left indicator bar and px-4" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_data_item href="/editor/public/users">public.users</.inner_side_menu_data_item>
        """)

      item = class_of(html, "data-polaris-ism-data-item")

      assert item =~ "px-4"
      assert item =~ "gap-3"
      assert item =~ "bg-content-primary/10"
      assert html =~ ~s{aria-current="page"}
      assert html =~ ~s{class="absolute left-0 h-full w-0.5 bg-content-primary"}
    end

    test "inactive preview rows drop the indicator and use the preview fill" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_data_item href="/t" is_active={false} is_preview>
          preview
        </.inner_side_menu_data_item>
        """)

      refute html =~ "w-0.5 bg-content-primary"
      item = class_of(html, "data-polaris-ism-data-item")
      assert item =~ "bg-surface-panel-hover"
      refute html =~ "aria-current"
    end

    test "is_active=false with is_opened keeps the opened fill" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_data_item href="/t" is_active={false} is_opened>
          opened
        </.inner_side_menu_data_item>
        """)

      item = class_of(html, "data-polaris-ism-data-item")
      assert item =~ "bg-surface-panel-hover"
      refute item =~ "bg-content-primary/10"
    end
  end

  describe "loading and separator" do
    test "the loading row is a skeleton sized to a real row" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_item_loading />
        """)

      assert html =~ ~s{data-polaris-ism-item-loading}
      assert html =~ "h-7"
      assert html =~ "animate-pulse"
      assert html =~ "bg-surface-panel-hover"
    end

    test "the separator is a muted hairline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_separator />
        """)

      assert html =~ ~s{data-polaris-ism-separator}
      assert html =~ "h-px"
      assert html =~ "bg-surface-border"
    end
  end

  describe "filters and search" do
    test "the filters row container" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_filters>
          <span>filters</span>
        </.inner_side_menu_filters>
        """)

      row = class_of(html, "data-polaris-ism-filters")

      assert row =~ "flex"
      assert row =~ "px-2"
      assert row =~ "gap-2"
    end

    test "the search input wires label/for/id and the leading glyph" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_search_input name="menu-search" label="Search items" value="u" />
        """)

      assert html =~ ~s{<label for="menu-search"}
      assert html =~ ~s{<input type="text" id="menu-search" name="menu-search"}
      assert html =~ ~s{value="u"}
      assert html =~ ~s{placeholder="Search..."}
      assert html =~ "Search items"
      assert html =~ "sr-only"

      input = input_class(html)

      assert input =~ "rounded-sm"
      assert input =~ "pl-7"
      assert input =~ "pr-7"
      assert input =~ "md:h-7"
      assert input =~ "md:text-xs"
    end

    test "loading swaps the search glyph for a spinner" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_search_input name="q" label="Search items" loading />
        """)

      assert html =~ "animate-spin"
      refute html =~ "<circle cx=\"11\" cy=\"11\" r=\"8\""
    end

    test "phx bindings pass through to the input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_search_input
          name="q"
          label="Search items"
          phx-change="search"
          phx-debounce="200"
        />
        """)

      assert html =~ ~s{phx-change="search"}
      assert html =~ ~s{phx-debounce="200"}
    end

    test "the trailing slot renders inside the field's trailing area" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_search_input name="q" label="Search items">
          <:trailing><span data-testid="sort">sort</span></:trailing>
        </.inner_side_menu_search_input>
        """)

      assert html =~ ~s{data-polaris-ism-search-trailing}
      assert html =~ ~s{data-testid="sort"}
      assert html =~ "absolute right-1"
    end
  end

  describe "sort dropdown" do
    test "renders the trigger, menu, and radio items with event wiring" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_sort_dropdown
          id="menu-sort"
          value="alphabetical"
          on_change="sort-menu"
        >
          <:item value="alphabetical">Sort Alphabetically</:item>
          <:item value="reverse">Sort Reverse Alphabetically</:item>
        </.inner_side_menu_sort_dropdown>
        """)

      assert html =~ ~s{id="menu-sort"}
      assert html =~ ~s{phx-hook="#{@sort_hook}"}
      assert html =~ ~s{data-polaris-ism-sort-trigger}
      assert html =~ ~s{data-polaris-ism-sort-content}
      assert html =~ ~s{aria-haspopup="menu"}
      assert html =~ ~s{aria-label="Sort By"}
      assert html =~ "Sort Alphabetically"
      assert html =~ "Sort Reverse Alphabetically"
      assert html =~ ~s{phx-click="sort-menu"}
      assert html =~ ~s{phx-value-value="alphabetical"}
      assert html =~ ~s{phx-value-value="reverse"}
      assert html =~ ~s{role="menuitemradio"}
    end

    test "the selected item is checked and highlighted" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_sort_dropdown id="s" value="reverse" on_change="sort">
          <:item value="alphabetical">A</:item>
          <:item value="reverse">Z</:item>
        </.inner_side_menu_sort_dropdown>
        """)

      assert html =~ ~s{aria-checked="true"}
      assert html =~ ~s{aria-checked="false"}
      assert html =~ "bg-brand-emerald"
    end

    test "the menu starts hidden and opens with the group state" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_sort_dropdown id="s" value="a" on_change="sort">
          <:item value="a">A</:item>
        </.inner_side_menu_sort_dropdown>
        """)

      menu = class_of(html, "data-polaris-ism-sort-content")

      assert menu =~ "invisible"
      assert menu =~ "opacity-0"
      assert menu =~ "group-data-[state=open]/ism-sort:visible"
      assert menu =~ "w-48"
      assert menu =~ "z-50"
    end

    test "an item without a value attribute raises a clear error" do
      assigns = %{}

      assert_raise ArgumentError, ~r/needs a value attribute/, fn ->
        rendered_to_string(~H"""
        <.inner_side_menu_sort_dropdown id="s" value="a" on_change="sort">
          <:item>A</:item>
        </.inner_side_menu_sort_dropdown>
        """)
      end
    end
  end

  describe "empty panel" do
    test "renders title, description, illustration, and actions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_empty_panel
          title="No functions found"
          description="Create your first serverless function to get started."
        >
          <:illustration>
            <div data-testid="art">🚀</div>
          </:illustration>
          <:actions><button data-testid="cta">Create function</button></:actions>
        </.inner_side_menu_empty_panel>
        """)

      assert html =~ ~s{data-polaris-ism-empty-panel}
      assert html =~ ~s{data-polaris-ism-empty-title}
      assert html =~ "No functions found"
      assert html =~ "Create your first serverless function to get started."
      assert html =~ ~s{data-testid="art"}
      assert html =~ ~s{data-testid="cta"}

      panel = class_of(html, "data-polaris-ism-empty-panel")

      assert panel =~ "rounded-md"
      assert panel =~ "border-surface-border"
      assert panel =~ "bg-surface-base"
      assert panel =~ "py-4"
      assert panel =~ "px-5"
    end

    test "description and slots are optional" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.inner_side_menu_empty_panel title="No results" />
        """)

      assert html =~ "No results"
      refute html =~ ~s{data-testid}
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
      true -> ""
    end
  end

  defp input_class(html) do
    ~r{<input[^>]*class="([^"]*)"}
    |> Regex.run(html, capture: :all_but_first)
    |> List.first()
  end
end
