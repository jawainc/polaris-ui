defmodule PolarisUI.Components.BreadcrumbTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Breadcrumb` — landmark,
  list/item anatomy, link vs current page, separator, and ellipsis,
  mirroring the Supabase design system `Breadcrumb` primitive.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Breadcrumb

  describe "anatomy" do
    test "renders the nav landmark with breadcrumb label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>Database</.breadcrumb_item>
          </.breadcrumb_list>
        </.breadcrumb>
        """)

      assert html =~ ~s{aria-label="breadcrumb"}
      assert html =~ "<nav"
      assert html =~ ~s{data-polaris-breadcrumb}
      assert html =~ "<ol"
      assert html =~ ~s{data-polaris-breadcrumb-list}
      assert html =~ "<li"
      assert html =~ "Database"
    end

    test "the list wraps items with the fragment's gaps and size" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>Database</.breadcrumb_item>
          </.breadcrumb_list>
        </.breadcrumb>
        """)

      class = class_of(html, "data-polaris-breadcrumb-list")
      assert class =~ "flex"
      assert class =~ "flex-wrap"
      assert class =~ "items-center"
      assert class =~ "gap-0.5"
      assert class =~ "sm:gap-1.5"
      assert class =~ "text-sm"
      assert class =~ "text-content-muted"
    end
  end

  describe "links and the current page" do
    test "a navigable crumb renders an anchor with hover and focus states" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_link href="/project/demo">Project</.breadcrumb_link>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.breadcrumb>
        """)

      assert html =~ ~s{href="/project/demo"}
      assert html =~ ~s{data-polaris-breadcrumb-link}

      class = class_of(html, "data-polaris-breadcrumb-link")
      assert class =~ "transition-colors"
      assert class =~ "hover:text-content-primary"
      assert class =~ "focus-visible:ring-2"
      assert class =~ "focus-visible:ring-brand-emerald"
    end

    test "the current page renders aria-current and the bright label, not a link" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.breadcrumb>
        """)

      assert html =~ ~s{aria-current="page"}
      assert html =~ ~s{aria-disabled="true"}
      assert html =~ ~s{data-polaris-breadcrumb-page}
      assert class_of(html, "data-polaris-breadcrumb-page") =~ "text-content-primary"
      refute html =~ ~s{<a href="/project/demo"}
    end

    test "a link without href renders a placeholder anchor" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_link>Crumb</.breadcrumb_link>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.breadcrumb>
        """)

      assert html =~ ~s{data-polaris-breadcrumb-link}
      refute html =~ "href="
    end
  end

  describe "separator" do
    test "renders the chevron hidden from assistive tech" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>Project</.breadcrumb_item>
            <.breadcrumb_separator />
            <.breadcrumb_item>Database</.breadcrumb_item>
          </.breadcrumb_list>
        </.breadcrumb>
        """)

      assert html =~ ~s{data-polaris-breadcrumb-separator}
      assert html =~ ~s{aria-hidden="true"}
      assert html =~ ~s{role="presentation"}
      assert class_of(html, "data-polaris-breadcrumb-separator") =~ "[&amp;_svg]:size-3.5"
    end

    test "accepts custom separator content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>Project</.breadcrumb_item>
            <.breadcrumb_separator>/</.breadcrumb_separator>
          </.breadcrumb_list>
        </.breadcrumb>
        """)

      assert html =~ ~r{>\s*/\s*</li>}
    end
  end

  describe "ellipsis" do
    test "renders the collapsed-middle marker with a screen-reader label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_ellipsis />
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.breadcrumb>
        """)

      assert html =~ ~s{data-polaris-breadcrumb-ellipsis}
      assert html =~ "sr-only"
      assert html =~ "More"
    end
  end

  describe "customization" do
    test "caller classes merge on every subcomponent" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumb class="mb-2">
          <.breadcrumb_list class="text-xs">
            <.breadcrumb_item class="truncate">
              <.breadcrumb_link href="/p" class="font-mono">Project</.breadcrumb_link>
            </.breadcrumb_item>
            <.breadcrumb_separator class="px-1" />
            <.breadcrumb_page class="font-mono">Database</.breadcrumb_page>
          </.breadcrumb_list>
        </.breadcrumb>
        """)

      assert class_of(html, ~s{aria-label="breadcrumb"}) =~ "mb-2"
      assert class_of(html, "data-polaris-breadcrumb-list") =~ "text-xs"
      assert class_of(html, "data-polaris-breadcrumb-item") =~ "truncate"
      assert class_of(html, "data-polaris-breadcrumb-link") =~ "font-mono"
      assert class_of(html, "data-polaris-breadcrumb-separator") =~ "px-1"
      assert class_of(html, "data-polaris-breadcrumb-page") =~ "font-mono"
    end
  end

  # Extracts the class attribute of the element carrying the marker,
  # regardless of attribute order within the tag.
  defp class_of(html, marker) when is_binary(marker) do
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
