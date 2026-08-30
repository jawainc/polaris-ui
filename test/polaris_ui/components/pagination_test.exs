defmodule PolarisUI.Components.PaginationTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Pagination` — the port
  of the shadcn Pagination documented by the Supabase design system: the
  nav landmark, the row anatomy, ghost/outline link states, the
  previous/next controls with collapsing verbs, and the ellipsis gap.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Pagination

  describe "anatomy" do
    test "renders the pagination nav landmark with the centered row" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination>
          <.pagination_content>
            <.pagination_item><.pagination_link href="#">1</.pagination_link></.pagination_item>
          </.pagination_content>
        </.pagination>
        """)

      assert html =~ "<nav"
      assert html =~ ~s{aria-label="pagination"}
      assert html =~ ~s{data-polaris-pagination}
      assert html =~ ~s{data-polaris-pagination-content}
      assert html =~ ~s{data-polaris-pagination-item}
      assert html =~ ~s{data-polaris-pagination-link}
      assert html =~ ~r{>\s*1\s*</a>}

      assert class_of(html, "data-polaris-pagination") =~ "mx-auto flex w-full justify-center"

      content = class_of(html, "data-polaris-pagination-content")
      assert content =~ "flex flex-row items-center"
      assert content =~ "gap-1"

      assert html =~ "<li"
    end

    test "the label attr names the nav landmark" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination label="Table pagination">
          <.pagination_content></.pagination_content>
        </.pagination>
        """)

      assert html =~ ~s{aria-label="Table pagination"}
    end
  end

  describe "links" do
    test "inactive links render the ghost treatment" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination>
          <.pagination_content>
            <.pagination_item>
              <.pagination_link href="/logs?page=2">2</.pagination_link>
            </.pagination_item>
          </.pagination_content>
        </.pagination>
        """)

      refute html =~ ~s{aria-current=}
      assert html =~ ~s{data-state="inactive"}
      assert html =~ ~s{data-active="false"}

      class = class_of(html, "data-polaris-pagination-link")
      assert class =~ "text-content-secondary"
      assert class =~ "hover:bg-surface-panel-hover hover:text-content-primary"
      refute class =~ "border-surface-border"
    end

    test "active links render the outline fill with aria-current" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination>
          <.pagination_content>
            <.pagination_item><.pagination_link href="#" is_active>1</.pagination_link></.pagination_item>
          </.pagination_content>
        </.pagination>
        """)

      assert html =~ ~s{aria-current="page"}
      assert html =~ ~s{data-active="true"}
      assert html =~ ~s{data-state="active"}

      class = class_of(html, "data-polaris-pagination-link")
      assert class =~ "border border-surface-border bg-surface-base"
      assert class =~ "text-content-primary"
      assert class =~ "hover:bg-surface-panel-hover hover:border-surface-border-hover"
    end

    test "links carry the shared button base, sizes, and focus ring" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination>
          <.pagination_content>
            <.pagination_item><.pagination_link href="#">3</.pagination_link></.pagination_item>
          </.pagination_content>
        </.pagination>
        """)

      class = class_of(html, "data-polaris-pagination-link")
      assert class =~ "inline-flex items-center justify-center rounded-md"
      assert class =~ "transition-colors"

      assert class =~
               "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"

      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
      assert class =~ "h-[34px] min-w-[34px]"
    end

    test "the size attr swaps the height scale" do
      assigns = %{}

      tiny =
        rendered_to_string(~H"""
        <.pagination_link href="#" size="tiny">1</.pagination_link>
        """)

      medium =
        rendered_to_string(~H"""
        <.pagination_link href="#" size="medium">1</.pagination_link>
        """)

      tiny_class = class_of(tiny, "data-polaris-pagination-link")
      assert tiny_class =~ "h-[26px] min-w-[26px]"
      assert tiny_class =~ "text-xs"
      assert class_of(medium, "data-polaris-pagination-link") =~ "h-[38px] min-w-[38px]"
    end

    test "an invalid size raises at render time" do
      assigns = %{}

      assert_raise ArgumentError, ~r/invalid value for :size/, fn ->
        rendered_to_string(~H"""
        <.pagination_link href="#" size="jumbo">1</.pagination_link>
        """)
      end
    end

    test "without href, renders a placeholder anchor driven by phx-click" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination_link phx-click="goto-page" phx-value-page="4">4</.pagination_link>
        """)

      refute html =~ ~s{href=}
      assert html =~ ~s{phx-click="goto-page"}
      assert html =~ ~s{phx-value-page="4"}
    end

    test "caller classes merge and win conflicts via cn/1" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination_link href="#" class="h-[38px]">1</.pagination_link>
        """)

      class = class_of(html, "data-polaris-pagination-link")
      assert class =~ "h-[38px]"
      refute class =~ "h-[34px]"
    end
  end

  describe "previous / next" do
    test "previous renders the chevron, collapsing verb, and source aria-label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination_previous href="/logs?page=1" />
        """)

      assert html =~ ~s{data-polaris-pagination-previous}
      assert html =~ ~s{aria-label="Go to previous page"}
      assert html =~ ~s{<path d="m15 18-6-6 6-6">}
      assert html =~ "Previous"
      assert html =~ ~s{class="hidden sm:inline"}

      class = class_of(html, "data-polaris-pagination-previous")
      assert class =~ "gap-1"
      assert class =~ "sm:pl-2.5"
    end

    test "next renders the chevron, collapsing verb, and source aria-label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination_next href="/logs?page=3" />
        """)

      assert html =~ ~s{data-polaris-pagination-next}
      assert html =~ ~s{aria-label="Go to next page"}
      assert html =~ ~s{<path d="m9 18 6-6-6-6">}
      assert html =~ "Next"
      assert html =~ ~s{class="hidden sm:inline"}

      assert class_of(html, "data-polaris-pagination-next") =~ "sm:pr-2.5"
    end

    test "the inner block overrides the verb microcopy" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination_next href="#">Older logs</.pagination_next>
        """)

      assert html =~ "Older logs"
      refute html =~ ">Next<"
    end
  end

  describe "ellipsis" do
    test "renders the dots with a screen-reader-only More pages" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination_ellipsis />
        """)

      assert html =~ ~s{data-polaris-pagination-ellipsis}
      assert html =~ ~s{<circle cx="12" cy="12" r="1">}
      assert html =~ ~s{<circle cx="19" cy="12" r="1">}
      assert html =~ ~s{<circle cx="5" cy="12" r="1">}
      assert html =~ ~s{class="sr-only">More pages}
      assert class_of(html, "data-polaris-pagination-ellipsis") =~ "size-[34px]"
    end

    test "the ellipsis square follows the size scale" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination_ellipsis size="medium" />
        """)

      assert class_of(html, "data-polaris-pagination-ellipsis") =~ "size-[38px]"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pagination>
          <.pagination_content>
            <.pagination_item><.pagination_previous href="#" /></.pagination_item>
            <.pagination_item><.pagination_link href="#" is_active>1</.pagination_link></.pagination_item>
            <.pagination_item><.pagination_ellipsis /></.pagination_item>
            <.pagination_item><.pagination_next href="#" /></.pagination_item>
          </.pagination_content>
        </.pagination>
        """)

      refute html =~ "#[", "arbitrary-value class leaked"
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
