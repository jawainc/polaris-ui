defmodule PolarisUI.Components.PageBreadcrumbsTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.PageBreadcrumbs` — the
  full-width breadcrumb chrome row above the page header, mirroring the
  Supabase design system fragment `ui-patterns/PageBreadcrumbs`.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Breadcrumb
  import PolarisUI.Components.PageBreadcrumbs

  describe "anatomy" do
    test "renders the wrapper, a full-width container, and the breadcrumb nav" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_breadcrumbs>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_link href="/project/demo">Project</.breadcrumb_link>
            </.breadcrumb_item>
            <.breadcrumb_separator />
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_breadcrumbs>
        """)

      assert html =~ "data-polaris-page-breadcrumbs"
      assert html =~ "data-polaris-page-container"
      assert html =~ ~s{data-size="full"}
      assert html =~ "data-polaris-breadcrumb"
      assert html =~ ~s{aria-label="breadcrumb"}
      assert html =~ "Project"
      assert html =~ "Database"
    end

    test "the chrome row carries the fragment's height, border, and layout" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_breadcrumbs>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_breadcrumbs>
        """)

      row = class_of(html, "data-polaris-page-container")

      assert row =~ "flex"
      assert row =~ "min-h-[var(--header-height,2.75rem)]"
      assert row =~ "items-center"
      assert row =~ "justify-between"
      assert row =~ "gap-4"
      assert row =~ "border-b border-surface-border"
      assert row =~ "py-2"
      assert row =~ "max-w-none"
    end

    test "the chrome padding px-4 overrides the container's measure padding" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_breadcrumbs>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_breadcrumbs>
        """)

      row = class_of(html, "data-polaris-page-container")

      # cn/1 resolves the conflict tailwind-merge style: the later
      # caller class drops the container's earlier default entirely.
      assert row =~ "px-4"
      assert row =~ "xl:px-4"
      refute row =~ "px-6"
      refute row =~ "xl:px-10"
    end

    test "the breadcrumb nav keeps the trail clipped with text-sm crumbs" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_breadcrumbs>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_breadcrumbs>
        """)

      nav = class_of(html, "data-polaris-breadcrumb")

      assert nav =~ "min-w-0 flex items-center gap-4"
      # `&` in the arbitrary selector HTML-escapes in the class attribute.
      assert nav =~ "[&amp;_li]:text-sm"
    end
  end

  describe "actions" do
    test "the actions slot renders after the breadcrumb trail" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_breadcrumbs>
          <:actions>
            <.page_breadcrumbs_actions>
              <button type="button" phx-click="create">Create</button>
            </.page_breadcrumbs_actions>
          </:actions>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_breadcrumbs>
        """)

      assert html =~ "data-polaris-page-breadcrumbs-actions"
      assert html =~ ~s{phx-click="create"}

      actions = class_of(html, "data-polaris-page-breadcrumbs-actions")
      assert actions =~ "ml-auto flex shrink-0 items-center gap-2"

      trail_at = html |> :binary.match("data-polaris-breadcrumb") |> elem(0)
      actions_at = html |> :binary.match("data-polaris-page-breadcrumbs-actions") |> elem(0)
      assert trail_at < actions_at
    end

    test "the actions slot is optional" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_breadcrumbs>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_breadcrumbs>
        """)

      refute html =~ "data-polaris-page-breadcrumbs-actions"
    end

    test "actions render standalone with merged classes and globals" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_breadcrumbs_actions class="flex-wrap" data-foo="bar">
          <button type="button">Create</button>
        </.page_breadcrumbs_actions>
        """)

      actions = class_of(html, "data-polaris-page-breadcrumbs-actions")

      assert actions =~ "ml-auto"
      assert actions =~ "flex-wrap"
      assert html =~ ~s{data-foo="bar"}
      assert html =~ "Create"
    end
  end

  describe "class merging and globals" do
    test "class, container_class, and slot_class each land on their layer" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_breadcrumbs class="w-64" container_class="bg-surface-panel" slot_class="py-8">
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_breadcrumbs>
        """)

      assert class_of(html, "data-polaris-breadcrumb") =~ "w-64"

      container = class_of(html, "data-polaris-page-container")
      assert container =~ "bg-surface-panel"
      assert container =~ "border-b border-surface-border"

      assert class_of(html, "data-polaris-page-breadcrumbs") =~ "py-8"
    end

    test "globals pass through to the outer wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_breadcrumbs id="page-crumbs" data-track="chrome">
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_breadcrumbs>
        """)

      assert html =~ ~s{id="page-crumbs"}
      assert html =~ ~s{data-track="chrome"}
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
