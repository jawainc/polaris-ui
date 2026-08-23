defmodule PolarisUI.Components.PageHeaderTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.PageHeader` — root
  sizes, every subcomponent's anatomy, and the navigation tabs border
  ownership, mirroring the Supabase design system fragment
  `ui-patterns/PageHeader` (context-propagated `size` becomes an attr on
  each subcomponent).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Breadcrumb
  import PolarisUI.Components.NavMenu
  import PolarisUI.Components.PageHeader

  describe "root" do
    test "measured sizes pad with pt-12 and record data-size" do
      for size <- ~w(default small large) do
        assigns = %{size: size}

        html =
          rendered_to_string(~H"""
          <.page_header size={@size}>Content</.page_header>
          """)

        assert html =~ "data-polaris-page-header"
        assert html =~ ~s{data-size="#{size}"}
        assert class_of(html, "data-polaris-page-header") =~ "pt-12"
      end
    end

    test "default size applies without passing the attr" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header>Content</.page_header>
        """)

      assert html =~ ~s{data-size="default"}
    end

    test "full tightens the top padding to pt-6" do
      assigns = %{size: "full"}

      html =
        rendered_to_string(~H"""
        <.page_header size={@size}>Content</.page_header>
        """)

      root = class_of(html, "data-polaris-page-header")

      assert html =~ ~s{data-size="full"}
      assert root =~ "pt-6"
      assert root =~ "flex w-full flex-col gap-4"
      refute root =~ "pt-12"
    end

    test "merges caller classes and forwards globals" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header class="gap-8" id="page-header" data-track="y">
          <.page_header_title>Title</.page_header_title>
        </.page_header>
        """)

      root = class_of(html, "data-polaris-page-header")

      assert root =~ "flex w-full flex-col"
      assert root =~ "gap-8"
      assert root =~ "pt-12"
      assert html =~ ~s{id="page-header"}
      assert html =~ ~s{data-track="y"}
    end
  end

  describe "breadcrumb" do
    test "wraps the breadcrumb nav in a container of the same size" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_breadcrumb size="small">
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Logs</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_header_breadcrumb>
        """)

      assert html =~ "data-polaris-page-container"
      assert html =~ ~s{data-size="small"}
      assert html =~ "data-polaris-breadcrumb"

      nav = class_of(html, "data-polaris-breadcrumb")
      assert nav =~ "flex items-center gap-4"
      assert nav =~ "[&amp;_li]:text-xs"
    end

    test "merges classes onto the nav and forwards globals to it" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_breadcrumb class="w-72" data-foo="b">
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Logs</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_header_breadcrumb>
        """)

      assert class_of(html, "data-polaris-breadcrumb") =~ "w-72"
      assert html =~ ~s{data-foo="b"}
    end
  end

  describe "icon, summary, title, description, aside" do
    test "icon renders the marker with secondary-color styling" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_icon class="size-14" data-icon="db">
          <span class="block size-14">DB</span>
        </.page_header_icon>
        """)

      icon = class_of(html, "data-polaris-page-header-icon")

      assert icon =~ "text-content-secondary"
      assert icon =~ "size-14"
      assert html =~ ~s{data-icon="db"}
      assert html =~ "DB"
    end

    test "summary stacks title and description" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_summary class="gap-2" data-sum="1">
          <.page_header_title>Demo Function</.page_header_title>
          <.page_header_description>Runs at the edge.</.page_header_description>
        </.page_header_summary>
        """)

      summary = class_of(html, "data-polaris-page-header-summary")

      assert summary =~ "flex flex-col"
      assert summary =~ "gap-2"
      assert html =~ ~s{data-sum="1"}
      assert html =~ "Demo Function"
      assert html =~ "Runs at the edge."
    end

    test "title is the h1 with heading-title typography" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_title class="tracking-tight" id="page-title">Demo Function</.page_header_title>
        """)

      assert html =~ "<h1"

      title = class_of(html, "data-polaris-page-header-title")

      assert title =~ "text-xl"
      assert title =~ "text-content-primary"
      assert title =~ "tracking-tight"
      assert html =~ ~s{id="page-title"}
    end

    test "description carries the sub-section typography" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_description class="max-w-lg" data-desc="1">
          Serverless functions that run at the edge.
        </.page_header_description>
        """)

      description = class_of(html, "data-polaris-page-header-description")

      assert description =~ "text-sm"
      assert description =~ "text-content-secondary"
      assert description =~ "max-w-lg"
      assert html =~ ~s{data-desc="1"}
      assert html =~ "Serverless functions that run at the edge."
    end

    test "aside holds actions with the fragment's gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_aside class="flex-wrap" data-aside="1">
          <button type="button">Secondary</button>
          <button type="button">Deploy Function</button>
        </.page_header_aside>
        """)

      aside = class_of(html, "data-polaris-page-header-actions")

      assert aside =~ "flex shrink-0 items-center gap-2"
      assert aside =~ "flex-wrap"
      assert html =~ ~s{data-aside="1"}
      assert html =~ "Deploy Function"
    end
  end

  describe "meta" do
    test "lays out icon, summary, and aside via container queries" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_meta size="large">
          <.page_header_icon><span class="block size-14">DB</span></.page_header_icon>
          <.page_header_summary>
            <.page_header_title>Demo Function</.page_header_title>
          </.page_header_summary>
          <.page_header_aside>
            <button type="button">Deploy</button>
          </.page_header_aside>
        </.page_header_meta>
        """)

      assert html =~ "data-polaris-page-container"
      assert html =~ ~s{data-size="large"}

      meta = class_of(html, "data-polaris-page-header-meta")

      assert meta =~ "flex flex-col gap-4"
      assert meta =~ "@xl:flex-row"
      assert meta =~ "@xl:items-center"
      assert meta =~ "@xl:justify-between"

      # Child layout selectors on the data-polaris markers (HTML-escaped).
      assert meta =~ "[&amp;&gt;[data-polaris-page-header-icon]]:shrink-0"
      assert meta =~ "[&amp;&gt;[data-polaris-page-header-summary]]:flex-1"

      # The children land inside the meta row.
      assert html =~ "data-polaris-page-header-icon"
      assert html =~ "data-polaris-page-header-summary"
      assert html =~ "data-polaris-page-header-actions"
      assert html =~ "Demo Function"
    end

    test "merges classes and forwards globals onto the inner row" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_meta class="py-2" data-track="meta">
          <.page_header_summary>
            <.page_header_title>Title</.page_header_title>
          </.page_header_summary>
        </.page_header_meta>
        """)

      assert class_of(html, "data-polaris-page-header-meta") =~ "py-2"
      assert html =~ ~s{data-track="meta"}
    end
  end

  describe "navigation tabs" do
    test "measured sizes put the border on the footer row, not the container" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_navigation_tabs>
          <.nav_menu>
            <.nav_menu_item is_active>Overview</.nav_menu_item>
            <.nav_menu_item>Logs</.nav_menu_item>
          </.nav_menu>
        </.page_header_navigation_tabs>
        """)

      container = class_of(html, "data-polaris-page-container")
      refute container =~ "border-b"
      refute container =~ "border-surface-border"

      footer = class_of(html, "data-polaris-page-header-footer")

      assert footer =~ "w-full"
      assert footer =~ "border-b border-surface-border"
      assert footer =~ "[&amp;&gt;nav]:border-b-0"
      assert html =~ "data-polaris-nav-menu"
    end

    test "full moves the border to the container and drops it from the row" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_navigation_tabs size="full">
          <.nav_menu>
            <.nav_menu_item>Overview</.nav_menu_item>
          </.nav_menu>
        </.page_header_navigation_tabs>
        """)

      container = class_of(html, "data-polaris-page-container")

      assert container =~ "border-b border-surface-border"
      assert container =~ "max-w-none"

      footer = class_of(html, "data-polaris-page-header-footer")

      assert footer =~ "w-full"
      assert footer =~ "[&amp;&gt;nav]:border-b-0"
      # The plain border token is gone (the selector variant remains).
      refute "border-b" in String.split(footer)
      refute footer =~ "border-surface-border"
    end

    test "merges classes and forwards globals onto the footer row" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header_navigation_tabs class="mt-2" data-track="tabs">
          <.nav_menu>
            <.nav_menu_item>Overview</.nav_menu_item>
          </.nav_menu>
        </.page_header_navigation_tabs>
        """)

      assert class_of(html, "data-polaris-page-header-footer") =~ "mt-2"
      assert html =~ ~s{data-track="tabs"}
    end
  end

  describe "composition" do
    test "composes the full demo anatomy in document order" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_header>
          <.page_header_breadcrumb>
            <.breadcrumb_list>
              <.breadcrumb_item>
                <.breadcrumb_page>Project</.breadcrumb_page>
              </.breadcrumb_item>
            </.breadcrumb_list>
          </.page_header_breadcrumb>
          <.page_header_meta>
            <.page_header_summary>
              <.page_header_title>Demo Function</.page_header_title>
              <.page_header_description>Runs at the edge.</.page_header_description>
            </.page_header_summary>
            <.page_header_aside>
              <button type="button">Deploy Function</button>
            </.page_header_aside>
          </.page_header_meta>
          <.page_header_navigation_tabs>
            <.nav_menu>
              <.nav_menu_item>Overview</.nav_menu_item>
            </.nav_menu>
          </.page_header_navigation_tabs>
        </.page_header>
        """)

      breadcrumb_at = html |> :binary.match("data-polaris-breadcrumb") |> elem(0)
      meta_at = html |> :binary.match("data-polaris-page-header-meta") |> elem(0)
      footer_at = html |> :binary.match("data-polaris-page-header-footer") |> elem(0)

      assert breadcrumb_at < meta_at && meta_at < footer_at
      assert html =~ "Demo Function"
      assert html =~ "Deploy Function"
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
