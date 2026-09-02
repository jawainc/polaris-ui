defmodule PolarisUI.Components.TableTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Table` — the port of
  the Supabase design system Table family: the overflow scroll wrapper
  around the semantic table, the panel-surfaced header rows, the
  hover/selected row states, the heading-meta treatment, and the
  TableHeadSort icon machine driven by the server-side `current_sort`
  contract.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Table

  ## Render helpers — one per subcomponent, Map.merge defaults.

  defp render_table(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}, selected: false}, assigns)

    rendered_to_string(~H"""
    <.table class={@class} {@rest}>
      <.table_caption>Projects across all regions</.table_caption>
      <.table_header>
        <.table_row>
          <.table_head>Name</.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row is_selected={assigns[:selected]}>
          <.table_cell>Production</.table_cell>
        </.table_row>
        <.table_row>
          <.table_cell>Staging</.table_cell>
        </.table_row>
      </.table_body>
      <.table_footer>
        <.table_row>
          <.table_cell>2 projects</.table_cell>
        </.table_row>
      </.table_footer>
    </.table>
    """)
  end

  defp render_table_header(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.table_header class={@class} {@rest}>
      <tr><th>Region</th></tr>
    </.table_header>
    """)
  end

  defp render_table_body(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.table_body class={@class} {@rest}>
      <tr><td>Sao Paulo</td></tr>
    </.table_body>
    """)
  end

  defp render_table_footer(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.table_footer class={@class} {@rest}>
      <tr><td>2 projects</td></tr>
    </.table_footer>
    """)
  end

  defp render_table_row(assigns) do
    assigns = Map.merge(%{is_selected: false, class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.table_row is_selected={@is_selected} class={@class} {@rest}>
      <td>Production</td>
    </.table_row>
    """)
  end

  defp render_table_head(assigns) do
    assigns = Map.merge(%{sort: nil, abbr: nil, class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.table_head sort={@sort} abbr={@abbr} class={@class} {@rest}>Region</.table_head>
    """)
  end

  defp render_table_head_sort(assigns) do
    assigns =
      Map.merge(
        %{column: "name", current_sort: nil, on_sort: "sort-projects", class: nil, rest: %{}},
        assigns
      )

    rendered_to_string(~H"""
    <.table_head_sort
      column={@column}
      current_sort={@current_sort}
      on_sort={@on_sort}
      class={@class}
      {@rest}
    >
      Name
    </.table_head_sort>
    """)
  end

  defp render_table_cell(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.table_cell class={@class} {@rest}>Sao Paulo</.table_cell>
    """)
  end

  defp render_table_caption(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.table_caption class={@class} {@rest}>Projects across all regions</.table_caption>
    """)
  end

  describe "anatomy" do
    test "wraps the table in the horizontal-scroll container (the ShadowScrollArea port)" do
      html = render_table(%{})

      assert html =~ ~s{<div class="w-full overflow-x-auto" data-polaris-table>}

      class = table_class(html)
      assert class =~ "group/table"
      assert class =~ "w-full caption-bottom text-sm"
    end

    test "renders every section inside the one table" do
      html = render_table(%{})

      assert html =~ "<thead"
      assert html =~ "<tbody"
      assert html =~ "<tfoot"
      assert html =~ "<caption"
      assert html =~ "Projects across all regions"
      assert html =~ "Staging"
    end

    test "the header paints its rows with the panel surface" do
      class = class_of(render_table_header(%{}), "data-polaris-table-header")

      assert class =~ "[&_tr]:border-b"
      assert class =~ "[&_tr]:border-surface-border"
      assert class =~ "[&>tr]:bg-surface-panel"
    end

    test "the body drops the last row's border" do
      class = class_of(render_table_body(%{}), "data-polaris-table-body")

      assert class =~ "[&_tr:last-child]:border-0"
    end

    test "the footer leads with a border and medium weight" do
      class = class_of(render_table_footer(%{}), "data-polaris-table-footer")

      assert class =~ "border-t border-surface-border"
      assert class =~ "font-medium"
    end

    test "the row carries the group marker, hover wash, and selected treatment" do
      class = class_of(render_table_row(%{}), "data-polaris-table-row")

      assert class =~ "group/row"
      assert class =~ "border-b border-surface-border"
      assert class =~ "transition-colors"
      assert class =~ "hover:bg-surface-panel-hover"
      assert class =~ "data-[state=selected]:bg-surface-muted"
    end

    test "the head renders in the heading-meta treatment" do
      class = class_of(render_table_head(%{}), "data-polaris-table-head")

      assert class =~ "h-10"
      assert class =~ "px-4"
      assert class =~ "text-left align-middle whitespace-nowrap"
      assert class =~ "text-xs font-mono uppercase tracking-wider"
      assert class =~ "text-content-secondary"
      assert class =~ "[&:has([role=checkbox])]:pr-0"
    end

    test "the cell is padded with the checkbox-column parity" do
      class = class_of(render_table_cell(%{}), "data-polaris-table-cell")

      assert class =~ "p-4 align-middle transition-colors"
      assert class =~ "[&:has([role=checkbox])]:pr-0"
    end

    test "the caption is muted copy over a top border" do
      class = class_of(render_table_caption(%{}), "data-polaris-table-caption")

      assert class =~ "border-t border-surface-border"
      assert class =~ "p-4 text-sm text-content-muted"
    end

    test "the sort button lays the label beside the stacked icon box" do
      html = render_table_head_sort(%{})

      assert html =~ "Name"
      assert html =~ ~s{class="w-3 h-3 relative overflow-hidden" aria-hidden="true"}

      class = class_of(html, "data-polaris-table-head-sort")
      assert class =~ "group/table-head-sort"
      assert class =~ "flex w-full items-center gap-1"
      assert class =~ "cursor-pointer select-none text-left"
      assert class =~ "text-xs font-mono uppercase tracking-wider"
    end
  end

  describe "sort state model" do
    test "unsorted shows the chevrons with both arrows slid out" do
      html = render_table_head_sort(%{current_sort: nil})

      assert icon_class(html, "M12 19V5") =~ "translate-y-full"
      assert icon_class(html, "M12 5v14") =~ "-translate-y-full"

      chevrons = icon_class(html, "m7 15 5 5 5-5")
      assert chevrons =~ "transition-opacity opacity-80 md:opacity-40"
      assert chevrons =~ "group-hover/table-head-sort:opacity-80"
    end

    test "a column that is not the current sort stays in the chevrons state" do
      html = render_table_head_sort(%{column: "name", current_sort: "region:asc"})

      assert icon_class(html, "m7 15 5 5 5-5") =~ "group-hover/table-head-sort:opacity-80"
      assert icon_class(html, "M12 19V5") =~ "translate-y-full"
    end

    test "ascending slides the up arrow in and hides the chevrons" do
      html = render_table_head_sort(%{current_sort: "name:asc"})

      up = icon_class(html, "M12 19V5")
      assert up =~ "translate-y-0"
      refute up =~ "translate-y-full"

      assert icon_class(html, "M12 5v14") =~ "-translate-y-full"

      chevrons = icon_class(html, "m7 15 5 5 5-5")
      assert chevrons =~ "opacity-0!"
      refute chevrons =~ "group-hover/table-head-sort:opacity-80"
    end

    test "descending slides the down arrow in" do
      html = render_table_head_sort(%{current_sort: "name:desc"})

      down = icon_class(html, "M12 5v14")
      assert down =~ "translate-y-0"
      refute down =~ "-translate-y-full"

      assert icon_class(html, "M12 19V5") =~ "translate-y-full"
    end

    test "arrows transition transforms; chevrons transition opacity" do
      html = render_table_head_sort(%{})

      assert icon_class(html, "M12 19V5") =~ "transition-transform"
      assert icon_class(html, "M12 5v14") =~ "transition-transform"
      assert icon_class(html, "m7 15 5 5 5-5") =~ "transition-opacity"
    end

    test "a malformed current_sort is treated as unsorted" do
      html = render_table_head_sort(%{current_sort: "name"})

      assert icon_class(html, "m7 15 5 5 5-5") =~ "group-hover/table-head-sort:opacity-80"
    end
  end

  describe "events" do
    test "pushes the on_sort event with the column value" do
      html = render_table_head_sort(%{on_sort: "sort-projects"})

      assert html =~ ~s{phx-click="sort-projects"}
      assert html =~ ~s{phx-value-column="name"}
    end

    test "forwards extra attributes onto the sort button via rest" do
      html = render_table_head_sort(%{rest: %{"data-testid" => "name-sort"}})

      assert html =~ ~s{data-testid="name-sort"}
    end
  end

  describe "states" do
    test "the selected row paints data-state=selected" do
      html = render_table_row(%{is_selected: true})

      assert html =~ ~s{data-state="selected"}
    end

    test "the unselected row omits data-state entirely" do
      html = render_table_row(%{is_selected: false})

      refute html =~ "data-state"
    end

    test "the sort button carries the focus-ring treatment" do
      class = class_of(render_table_head_sort(%{}), "data-polaris-table-head-sort")

      assert class =~ "focus-visible:outline-none"
      assert class =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    end

    test "caller classes merge and win conflicts via cn/1" do
      class =
        class_of(
          render_table_head_sort(%{class: "w-auto"}),
          "data-polaris-table-head-sort"
        )

      assert class =~ "w-auto"
      refute class =~ "w-full"
    end
  end

  describe "accessibility" do
    test "the head announces an ascending sort via aria-sort" do
      html = render_table_head(%{sort: "ascending"})

      assert html =~ ~s{aria-sort="ascending"}
    end

    test "the head announces a descending sort via aria-sort" do
      html = render_table_head(%{sort: "descending"})

      assert html =~ ~s{aria-sort="descending"}
    end

    test "unsorted heads omit aria-sort" do
      html = render_table_head(%{})

      refute html =~ "aria-sort"
    end

    test "abbr gives screen readers the short heading" do
      html = render_table_head(%{abbr: "Region"})

      assert html =~ ~s{abbr="Region"}
    end

    test "the sort icons are hidden decoration" do
      html = render_table_head_sort(%{})

      assert count(html, ~s{aria-hidden="true"}) == 4
    end

    test "rejects an invalid sort value at render time" do
      assert_raise ArgumentError, ~r/invalid value for :sort/, fn ->
        render_table_head(%{sort: "ascending-descending"})
      end
    end
  end

  describe "attributes" do
    test "rest forwards onto the table element (not the wrapper)" do
      html = render_table(%{rest: %{"data-testid" => "projects-grid"}})

      [wrapper, table | _] = String.split(html, "<table", parts: 2)
      refute wrapper =~ "data-testid"
      assert table =~ ~s{data-testid="projects-grid"}
    end

    test "table classes merge caller-last — text-base replaces text-sm" do
      assigns = %{class: "text-base"}

      html =
        rendered_to_string(~H"""
        <.table class={@class}><tbody></tbody></.table>
        """)

      class = table_class(html)
      assert class =~ "text-base"
      refute class =~ "text-sm"
    end

    test "header classes merge caller-last — a caller row background wins" do
      class =
        class_of(
          render_table_header(%{class: "[&>tr]:bg-surface-base"}),
          "data-polaris-table-header"
        )

      assert class =~ "[&>tr]:bg-surface-base"
      refute class =~ "bg-surface-panel"
    end

    test "rest forwards onto rows" do
      html = render_table_row(%{rest: %{"data-row-id" => "42"}})

      assert html =~ ~s{data-row-id="42"}
    end

    test "rest forwards onto cells" do
      html = render_table_cell(%{rest: %{"data-field" => "region"}})

      assert html =~ ~s{data-field="region"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_table(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end

    test "pure server-rendered chrome — no hook, no script" do
      html = render_table(%{})

      refute html =~ "phx-hook"
      refute html =~ "<script"
    end
  end

  ## Extractors

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  # The class attribute of the <table> element.
  defp table_class(html) do
    [_, after_tag | _] = String.split(html, "<table", parts: 2)

    after_tag
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  # The class of the icon whose first <path> carries `marker` — the icon's
  # svg tag is the last class attribute before that path.
  defp icon_class(html, marker) do
    [before_path | _] = String.split(html, marker, parts: 2)

    before_path
    |> String.split(~s{class="})
    |> Enum.at(-1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  # Extracts the class attribute of the element carrying the marker,
  # regardless of attribute order within the tag.
  defp class_of(html, marker) do
    marker = Regex.escape(marker)
    class_after = ~r{<[^>]*#{marker}[^>]*?class="([^"]*)"[^>]*>}
    class_before = ~r{<[^>]*class="([^"]*)"[^>]*?#{marker}[^>]*>}

    cond do
      match = Regex.run(class_after, html, capture: :all_but_first) -> hd(match) |> unescape()
      match = Regex.run(class_before, html, capture: :all_but_first) -> hd(match) |> unescape()
      true -> flunk("no element with marker #{marker}")
    end
  end

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
