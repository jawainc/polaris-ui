defmodule PolarisUI.Components.PageHeader do
  @moduledoc """
  The Polaris page header: the title block at the top of a page — the
  port of the Supabase design system fragment `ui-patterns/PageHeader`.

  A compound component: the root renders its children in order
  (breadcrumb row first, meta row, navigation tabs last) while each
  subcomponent owns one slice of the anatomy. Subcomponents that align
  to the content measure (`page_header_breadcrumb`, `page_header_meta`,
  `page_header_navigation_tabs`) wrap themselves in a
  `<.page_container>` of the same `size` as the root.

  ## LiveView port notes

  The React fragment threads `size` from the root to its children
  through React context; LiveView has no context for function
  components, so every subcomponent that needs the size takes its own
  `size` attribute with the same values and the same default. Pass the
  same `size` to the root and to those subcomponents:

      <.page_header size="large">
        <.page_header_breadcrumb size="large">…</.page_header_breadcrumb>
        <.page_header_meta size="large">…</.page_header_meta>
        <.page_header_navigation_tabs size="large">…</.page_header_navigation_tabs>
      </.page_header>

  ## Anatomy

      <.page_header>
        <.page_header_breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_link href="/project/demo">Project</.breadcrumb_link>
            </.breadcrumb_item>
            <.breadcrumb_separator />
            <.breadcrumb_item>
              <.breadcrumb_page>Database</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.page_header_breadcrumb>
        <.page_header_meta>
          <.page_header_icon>
            <div class="flex size-14 shrink-0 items-center justify-center rounded-lg border border-surface-border bg-surface-panel">
              DB
            </div>
          </.page_header_icon>
          <.page_header_summary>
            <.page_header_title>Demo Function</.page_header_title>
            <.page_header_description>
              Serverless functions that run at the edge with low latency.
            </.page_header_description>
          </.page_header_summary>
          <.page_header_aside>
            <button type="button" phx-click="deploy">Deploy Function</button>
          </.page_header_aside>
        </.page_header_meta>
        <.page_header_navigation_tabs>
          <.nav_menu label="Sections">
            <.nav_menu_item is_active>Overview</.nav_menu_item>
            <.nav_menu_item>Logs</.nav_menu_item>
          </.nav_menu>
        </.page_header_navigation_tabs>
      </.page_header>

    * **page_header** — the root `div`: a full-width column stacking its
      rows with `gap-4`, with `pt-12` of breathing room above (`pt-6`
      for `full`, where the header usually sits under a
      `page_breadcrumbs` chrome row).
    * **page_header_breadcrumb** — the trail above the meta row, crumbs
      at `text-xs`, aligned to the measure by its container.
    * **page_header_meta** — the icon / summary / aside row: stacks on
      narrow containers, spreads (`@xl:flex-row @xl:items-center
      @xl:justify-between`) once the page container is wide enough.
      The icon is held fixed and the summary flexes via child selectors
      keyed on the `data-polaris-*` markers (the port of the fragment's
      `*:data-[slot=...]` pattern).
    * **page_header_icon** — the glyph card left of the title (the demo
      slots a 56px `size-14` rounded card).
    * **page_header_summary** — the title + description stack (`gap-1`).
    * **page_header_title** — the page's single `<h1>`.
    * **page_header_description** — supporting copy under the title.
    * **page_header_aside** — trailing actions (buttons) inside meta.
    * **page_header_navigation_tabs** — the tab row (typically
      `<.nav_menu>`) closing the header. For measured sizes the border
      lives on the inner row (it stops at the measure); for `full` it
      moves to the container so the rule runs edge to edge. Either way
      `[&>nav]:border-b-0` suppresses the nav menu's own border.

  ## Sizes

  | Size      | Root padding | Measure (via the wrapped containers) |
  |-----------|--------------|--------------------------------------|
  | `small`   | `pt-12`      | 768px — focus flows                  |
  | `default` | `pt-12`      | 1200px — standard app pages          |
  | `large`   | `pt-12`      | 1600px — wide data views             |
  | `full`    | `pt-6`       | none — under a breadcrumbs chrome row |

  ## Accessibility

    * One `page_header` per page; `page_header_title` is the page's
      single `<h1>` (one heading level, no nesting tricks).
    * Render children in the fragment's order: breadcrumb, meta,
      navigation tabs — the root is a plain flex column, so document
      order is visual order.
    * The nav landmark, `aria-current="page"`, and tab semantics come
      from the slotted `Breadcrumb` and `NavMenu` components.

  Presentational only — no states, no events, no hook.
  """

  use PolarisUI.Component

  import PolarisUI.Components.Breadcrumb
  import PolarisUI.Components.PageContainer

  @sizes ~w(default small large full)

  attr(:size, :string,
    values: @sizes,
    default: "default",
    doc: """
    Content measure — pass the same value to the container-wrapping
    subcomponents (`page_header_breadcrumb`, `page_header_meta`,
    `page_header_navigation_tabs`). Also drives the root padding:
    `pt-12`, except `full` tightens to `pt-6`.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc:
      "Rows in order: `page_header_breadcrumb`, `page_header_meta`, `page_header_navigation_tabs`."
  )

  def page_header(assigns) do
    ~H"""
    <div
      class={cn(["flex w-full flex-col gap-4", size_classes(@size), @class])}
      data-polaris-page-header
      data-size={@size}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:size, :string,
    values: @sizes,
    default: "default",
    doc: "Same `size` as the root `page_header` — picks the wrapping container's measure."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the `<.breadcrumb>` nav."
  )

  attr(:rest, :global, doc: "Forwarded to the `<.breadcrumb>` nav: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "Typically a single `<.breadcrumb_list>`.")

  def page_header_breadcrumb(assigns) do
    ~H"""
    <.page_container size={@size}>
      <.breadcrumb class={cn(["flex items-center gap-4 [&_li]:text-xs", @class])} {@rest}>
        {render_slot(@inner_block)}
      </.breadcrumb>
    </.page_container>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the icon wrapper.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The glyph card — typically a 56px rounded square with an icon."
  )

  def page_header_icon(assigns) do
    ~H"""
    <div class={cn(["text-content-secondary", @class])} data-polaris-page-header-icon {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the summary stack.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "A `<.page_header_title>` and, optionally, a `<.page_header_description>`."
  )

  def page_header_summary(assigns) do
    ~H"""
    <div class={cn(["flex flex-col gap-1", @class])} data-polaris-page-header-summary {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<h1>`.")
  attr(:rest, :global, doc: "Forwarded to the `<h1>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The page title (plain text — the page's single `<h1>`)."
  )

  def page_header_title(assigns) do
    ~H"""
    <h1 class={cn(["text-xl text-content-primary", @class])} data-polaris-page-header-title {@rest}>
      {render_slot(@inner_block)}
    </h1>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the description.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "Supporting copy rendered below the title.")

  def page_header_description(assigns) do
    ~H"""
    <div
      class={cn(["text-sm text-content-secondary", @class])}
      data-polaris-page-header-description
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:size, :string,
    values: @sizes,
    default: "default",
    doc: "Same `size` as the root `page_header` — picks the wrapping container's measure."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the meta row (the inner div)."
  )

  attr(:rest, :global, doc: "Forwarded to the meta row `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "`page_header_icon`, `page_header_summary`, and `page_header_aside` in order."
  )

  def page_header_meta(assigns) do
    ~H"""
    <.page_container size={@size}>
      <div
        class={
          cn([
            "flex flex-col gap-4 @xl:flex-row @xl:items-center @xl:justify-between",
            "[&>[data-polaris-page-header-icon]]:shrink-0",
            "[&>[data-polaris-page-header-summary]]:flex-1",
            @class
          ])
        }
        data-polaris-page-header-meta
        {@rest}
      >
        {render_slot(@inner_block)}
      </div>
    </.page_container>
    """
  end

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the actions container."
  )

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "Action elements — buttons, dropdowns, …")

  def page_header_aside(assigns) do
    ~H"""
    <div
      class={cn(["flex shrink-0 items-center gap-2", @class])}
      data-polaris-page-header-actions
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:size, :string,
    values: @sizes,
    default: "default",
    doc: """
    Same `size` as the root `page_header` — picks the wrapping
    container's measure and where the bottom border lives (on the inner
    row for measured sizes, on the container for `full`).
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the footer row (the inner div)."
  )

  attr(:rest, :global, doc: "Forwarded to the footer row `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "Typically a single `<.nav_menu>`.")

  def page_header_navigation_tabs(assigns) do
    ~H"""
    <.page_container
      size={@size}
      class={if @size == "full", do: "border-b border-surface-border"}
    >
      <div
        class={
          cn([
            "w-full [&>nav]:border-b-0",
            if(@size != "full", do: "border-b border-surface-border"),
            @class
          ])
        }
        data-polaris-page-header-footer
        {@rest}
      >
        {render_slot(@inner_block)}
      </div>
    </.page_container>
    """
  end

  defp size_classes("default"), do: "pt-12"
  defp size_classes("small"), do: "pt-12"
  defp size_classes("large"), do: "pt-12"
  defp size_classes("full"), do: "pt-6"
end
