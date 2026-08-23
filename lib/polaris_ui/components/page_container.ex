defmodule PolarisUI.Components.PageContainer do
  @moduledoc """
  The Polaris page container: the width-owning wrapper all page chrome and
  page content sit inside — the port of the Supabase design system fragment
  `ui-patterns/PageContainer`.

  Every page-level fragment (`PageBreadcrumbs`, `PageHeader`, `PageNav`)
  wraps its content in a page container so rows can run full-bleed (borders
  edge to edge) while their *content* stays aligned to the same measure:

      <.page_container size="large">
        <.page_header>
          <.page_header_meta>
            <.page_header_summary>
              <.page_header_title>Database</.page_header_title>
            </.page_header_summary>
          </.page_header_meta>
        </.page_header>
        {render_slot(@inner_block)}
      </.page_container>

  ## Sizes

  | Size      | Max width | Use for                                        |
  |-----------|-----------|------------------------------------------------|
  | `small`   | 768px     | Focus flows — single-column forms, auth pages  |
  | `default` | 1200px    | Standard app pages (the default)               |
  | `large`   | 1600px    | Wide data views — tables, log explorers        |
  | `full`    | none      | Page chrome rows and full-bleed content        |

  The container is also a CSS container (`@container`), so page-level
  fragments can adapt their layout with container queries (`@xl:flex-row`)
  instead of viewport breakpoints.

  Presentational only — no states, no events, no hook.
  """

  use PolarisUI.Component

  @sizes ~w(small default large full)

  attr(:size, :string,
    values: @sizes,
    default: "default",
    doc: """
    Content measure: `small` 768px, `default` 1200px, `large` 1600px,
    `full` no max-width (page chrome rows).
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the container — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The page content to align to the measure.")

  def page_container(assigns) do
    ~H"""
    <div
      class={cn(["mx-auto w-full @container px-6 xl:px-10", size_classes(@size), @class])}
      data-polaris-page-container
      data-size={@size}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp size_classes("small"), do: "max-w-[768px]"
  defp size_classes("default"), do: "max-w-[1200px]"
  defp size_classes("large"), do: "max-w-[1600px]"
  defp size_classes("full"), do: "max-w-none"
end
