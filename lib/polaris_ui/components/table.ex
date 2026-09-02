defmodule PolarisUI.Components.Table do
  @moduledoc """
  The Polaris table: the data-grid chrome — the port of the Supabase
  design system Table family (`packages/ui`, semantic `<table>`
  subcomponents in the shadcn style) for server-rendered LiveView data.

  ## Anatomy

      <.table>
        <.table_caption>Projects across all regions</.table_caption>
        <.table_header>
          <.table_row>
            <.table_head abbr="Name">Name</.table_head>
            <.table_head sort={@region_sort_aria}>
              <.table_head_sort
                column="region"
                current_sort={@current_sort}
                on_sort="sort-projects"
              >Region</.table_head_sort>
            </.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :for={project <- @projects} is_selected={project.id == @selected_id}>
            <.table_cell>{project.name}</.table_cell>
            <.table_cell>{project.region}</.table_cell>
          </.table_row>
        </.table_body>
        <.table_footer>
          <.table_row>
            <.table_cell>{length(@projects)} projects</.table_cell>
          </.table_row>
        </.table_footer>
      </.table>

    * **table** — the horizontal-scroll wrapper (`div.w-full.overflow-x-auto`,
      standing in for the source's ShadowScrollArea) around the semantic
      `<table>` (`group/table w-full caption-bottom text-sm`).
    * **table_header / table_body / table_footer** — the three row
      groups: the header paints its rows with the panel surface (the
      source's `bg-200`), the body drops the last row's border, the
      footer leads with a border and medium weight.
    * **table_row** — a `group/row` `<tr>` with the hover wash and the
      selected state (`is_selected` paints `data-state="selected"`).
    * **table_head** — the `<th>` in the source's `heading-meta`
      treatment (mono, uppercase, xsmall — the same metadata style as
      the Select group labels), optionally carrying `abbr` and
      `aria-sort`.
    * **table_head_sort** — the source's `TableHeadSort` as a LiveView
      button: it pushes `on_sort` with `phx-value-column` and animates
      the stacked chevron/arrow icon trio from `current_sort`.
    * **table_cell** — the `<td>`: `p-4 align-middle`, with the
      checkbox-column parity (`[&:has([role=checkbox])]:pr-0`).
    * **table_caption** — the caption; render it first in the markup —
      `caption-bottom` on the table paints it below the rows regardless.

  ## State model

  The table is **non-interactive chrome**: rows and heads render exactly
  what the server assigns. Sorting is a plain LiveView round trip —
  `table_head_sort` pushes `on_sort` with `%{"column" => column}`, the
  handler recomputes `current_sort` (`"column:asc"` / `"column:desc"`,
  the source's contract), and the icons plus `aria-sort` re-render from
  it. The family has no loading or disabled state of its own; forward
  row/head attributes via `rest` (`data-*`, `aria-*`, `phx-*`) as
  needed.

  ## States

    * **rest** — hairline `border-surface-border` separators; header
      rows sit on `bg-surface-panel`.
    * **hover** — rows wash with `hover:bg-surface-panel-hover` (the
      source's `hover:bg-surface-200`).
    * **selected** — `is_selected` rows take
      `data-[state=selected]:bg-surface-muted`, pairing with a selection
      checkbox column.
    * **sort** — the stacked icon trio in every sort head: the neutral
      chevrons (40% opacity, 80% on group hover, 80% below `md`) hide
      once the column is active, and the up/down arrows slide in
      (`translate-y`) for asc/desc.
    * **focus-ring** — the sort button carries the shared emerald
      `focus-visible` ring; a Polaris addition, since the source's
      button ships no focus treatment.

  ## Accessibility

    * Semantic table landmarks only — no ARIA roles to add.
    * `table_head` renders `aria-sort="ascending" | "descending"` — an
      improvement over the source, which never announces sort state.
      Compute it alongside `current_sort`; omit it for unsorted heads.
    * `abbr` on `table_head` gives screen readers the short heading.
    * The sort icons are `aria-hidden` decoration — the column name
      plus `aria-sort` carries the meaning.

  ## Microcopy

  Headings are short nouns ("Name", "Region", "Status", "Size") — never
  sentences; keep the sort label identical to its column name.

  No hook is needed; the family is fully presentational (sorting is a
  server round trip).
  """

  use PolarisUI.Component

  @sorts ~w(ascending descending)

  # The source's `heading-meta` utility — the mono/uppercase/xsmall
  # metadata treatment, ported like the Select group labels.
  defp heading_meta, do: "text-xs font-mono uppercase tracking-wider"

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the `<table>` (the scroll wrapper is fixed)."
  )

  attr(:rest, :global, doc: "Forwarded to the `<table>`: `id`, `data-*`, `aria-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The sections — header, body, footer rows, caption.")

  def table(assigns) do
    ~H"""
    <div class="w-full overflow-x-auto" data-polaris-table>
      <table class={cn(["group/table w-full caption-bottom text-sm", @class])} {@rest}>
        {render_slot(@inner_block)}
      </table>
    </div>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<thead>`.")
  attr(:rest, :global, doc: "Forwarded to the `<thead>`: `data-*`, `aria-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "`<.table_row>` cells with `<.table_head>` cells.")

  def table_header(assigns) do
    ~H"""
    <thead
      data-polaris-table-header
      class={
        cn(["[&_tr]:border-b [&_tr]:border-surface-border [&>tr]:bg-surface-panel", @class])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </thead>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<tbody>`.")
  attr(:rest, :global, doc: "Forwarded to the `<tbody>`: `data-*`, `aria-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "`<.table_row>` rows with `<.table_cell>` cells.")

  def table_body(assigns) do
    ~H"""
    <tbody data-polaris-table-body class={cn(["[&_tr:last-child]:border-0", @class])} {@rest}>
      {render_slot(@inner_block)}
    </tbody>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<tfoot>`.")
  attr(:rest, :global, doc: "Forwarded to the `<tfoot>`: `data-*`, `aria-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "`<.table_row>` rows for the summary line.")

  def table_footer(assigns) do
    ~H"""
    <tfoot
      data-polaris-table-footer
      class={cn(["border-t border-surface-border font-medium", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </tfoot>
    """
  end

  attr(:is_selected, :boolean,
    default: false,
    doc: """
    Selection state (compute from the selection set). Paints
    `data-state="selected"`, driving the muted row background — pairs
    with a leading checkbox column.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<tr>`.")
  attr(:rest, :global, doc: "Forwarded to the `<tr>`: `data-*`, `aria-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The row's cells.")

  def table_row(assigns) do
    ~H"""
    <tr
      data-polaris-table-row
      data-state={if @is_selected, do: "selected"}
      class={
        cn([
          "group/row border-b border-surface-border transition-colors",
          "hover:bg-surface-panel-hover data-[state=selected]:bg-surface-muted",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </tr>
    """
  end

  attr(:sort, :string,
    default: nil,
    doc: """
    Announces the column's sort state as `aria-sort` — `"ascending"` or
    `"descending"` for the active sort, omitted when unsorted (an a11y
    improvement over the source). Compute it alongside `current_sort`.
    """
  )

  attr(:abbr, :string,
    default: nil,
    doc: "Short heading for screen readers (the HTML `abbr` attribute on `<th>`)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<th>`.")
  attr(:rest, :global, doc: "Forwarded to the `<th>`: `data-*`, `aria-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The heading text, or a `<.table_head_sort>` for a sortable column."
  )

  def table_head(assigns) do
    if assigns.sort, do: validate_in!(:sort, assigns.sort, @sorts)

    ~H"""
    <th
      data-polaris-table-head
      abbr={@abbr}
      aria-sort={@sort}
      class={
        cn([
          "h-10 p-0 px-4 text-left align-middle whitespace-nowrap font-medium",
          heading_meta(),
          "text-content-secondary",
          "[&:has([role=checkbox])]:pr-0 transition-colors",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </th>
    """
  end

  attr(:column, :string,
    required: true,
    doc: "The column key this head sorts — pushed to the server as `phx-value-column`."
  )

  attr(:current_sort, :string,
    default: nil,
    doc: """
    The active sort in the source's `"<column>:<direction>"` contract
    (e.g. `"name:asc"`, `"name:desc"`). Any other value — or nil —
    renders the neutral chevrons state.
    """
  )

  attr(:on_sort, :string,
    required: true,
    doc: """
    LiveView event pushed on click with `%{"column" => column}` — the
    handler owns the next direction ("name:asc" → "name:desc" → unsorted).
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the sort button.")
  attr(:rest, :global, doc: "Forwarded to the button: `data-*`, `aria-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The heading label — the column's noun.")

  def table_head_sort(assigns) do
    {active?, asc?, desc?} = sort_state(assigns.column, assigns.current_sort)

    assigns = assign(assigns, active?: active?, asc?: asc?, desc?: desc?)

    ~H"""
    <button
      type="button"
      data-polaris-table-head-sort
      phx-click={@on_sort}
      phx-value-column={@column}
      class={
        cn([
          "group/table-head-sort flex w-full items-center gap-1 cursor-pointer select-none text-left",
          "whitespace-nowrap bg-transparent border-none p-0",
          heading_meta(),
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
      <span class="w-3 h-3 relative overflow-hidden" aria-hidden="true">
        <.arrow_up
          class={
            cn([
              "w-3 h-3 absolute inset-0 transition-transform",
              if(@asc?, do: "translate-y-0", else: "translate-y-full")
            ])
          }
        />
        <.arrow_down
          class={
            cn([
              "w-3 h-3 absolute inset-0 transition-transform",
              if(@desc?, do: "translate-y-0", else: "-translate-y-full")
            ])
          }
        />
        <.chevrons_up_down
          class={
            cn([
              "w-3 h-3 absolute inset-0 transition-opacity opacity-80 md:opacity-40",
              if(@active?, do: "opacity-0!", else: "group-hover/table-head-sort:opacity-80")
            ])
          }
        />
      </span>
    </button>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<td>`.")
  attr(:rest, :global, doc: "Forwarded to the `<td>`: `data-*`, `aria-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The cell content.")

  def table_cell(assigns) do
    ~H"""
    <td
      data-polaris-table-cell
      class={cn(["p-4 align-middle transition-colors [&:has([role=checkbox])]:pr-0", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </td>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<caption>`.")
  attr(:rest, :global, doc: "Forwarded to the `<caption>`: `data-*`, `aria-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "Inline content — a sentence describing the table, not a data cell."
  )

  def table_caption(assigns) do
    ~H"""
    <caption
      data-polaris-table-caption
      class={cn(["border-t border-surface-border p-4 text-sm text-content-muted", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </caption>
    """
  end

  # The source's derivation: split currentSort on ":" — the column is
  # active when it matches; asc/desc come from the direction half.
  defp sort_state(column, current_sort) do
    case current_sort && String.split(current_sort, ":", parts: 2) do
      [current_column, current_order] ->
        active? = current_column == column

        {active?, active? and current_order == "asc", active? and current_order == "desc"}

      _ ->
        {false, false, false}
    end
  end

  # The stacked sort icons — lucide geometry (ArrowUp, ArrowDown,
  # ChevronsUpDown) at 12px, reusing the arrow paths already in the
  # Polaris icon vocabulary.
  defp arrow_up(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      class={@class}
    >
      <path d="M12 19V5" />
      <path d="m5 12 7-7 7 7" />
    </svg>
    """
  end

  defp arrow_down(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      class={@class}
    >
      <path d="M12 5v14" />
      <path d="m19 12-7 7-7-7" />
    </svg>
    """
  end

  defp chevrons_up_down(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      class={@class}
    >
      <path d="m7 15 5 5 5-5" />
      <path d="m7 9 5-5 5 5" />
    </svg>
    """
  end

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
