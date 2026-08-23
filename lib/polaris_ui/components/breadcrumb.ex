defmodule PolarisUI.Components.Breadcrumb do
  @moduledoc """
  The Polaris breadcrumb: a hierarchy trail showing where the current page
  lives — the port of the Supabase design system `Breadcrumb` primitive
  (`packages/ui`) that the `PageBreadcrumbs` and `PageHeaderBreadcrumb`
  fragments build on.

  ## Anatomy

      <.breadcrumb>
        <.breadcrumb_list>
          <.breadcrumb_item>
            <.breadcrumb_link href="/project/demo">Project</.breadcrumb_link>
          </.breadcrumb_item>
          <.breadcrumb_separator />
          <.breadcrumb_item>
            <.breadcrumb_page>Database</.breadcrumb_page>
          </.breadcrumb_item>
        </.breadcrumb_list>
      </.breadcrumb>

    * **breadcrumb** — the `<nav aria-label="breadcrumb">` landmark.
    * **list** — the wrapping `<ol>`; items wrap when space runs out.
    * **item** — one `<li>` crumb.
    * **link** — a navigable crumb (everything except the current page).
    * **page** — the current page: `aria-current="page"`, not a link.
    * **separator** — the chevron between crumbs, hidden from assistive
      tech (`aria-hidden`) like the Supabase primitive.
    * **ellipsis** — the collapsed-middle marker for long trails
      (`1.5rem` square, "More" for screen readers).

  Breadcrumb labels describe location, not actions — "Database", not
  "Go to database".

  Presentational only — states are the link hover/focus treatment.
  """

  use PolarisUI.Component

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<nav>`.")
  attr(:rest, :global, doc: "Forwarded to the `<nav>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "Typically a single `<.breadcrumb_list>`.")

  def breadcrumb(assigns) do
    ~H"""
    <nav aria-label="breadcrumb" class={@class} data-polaris-breadcrumb {@rest}>
      {render_slot(@inner_block)}
    </nav>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<ol>`.")
  attr(:rest, :global, doc: "Forwarded to the `<ol>`: `data-*`, `aria-*`, …")

  slot(:inner_block,
    required: true,
    doc: "Alternating `<.breadcrumb_item>` and `<.breadcrumb_separator>`."
  )

  def breadcrumb_list(assigns) do
    ~H"""
    <ol
      class={
        cn([
          "flex flex-wrap items-center gap-0.5 break-words text-sm text-content-muted sm:gap-1.5",
          @class
        ])
      }
      data-polaris-breadcrumb-list
      {@rest}
    >
      {render_slot(@inner_block)}
    </ol>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<li>`.")
  attr(:rest, :global, doc: "Forwarded to the `<li>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "A `<.breadcrumb_link>` or `<.breadcrumb_page>`.")

  def breadcrumb_item(assigns) do
    ~H"""
    <li
      class={cn(["inline-flex items-center gap-1.5 leading-5 text-content-muted", @class])}
      data-polaris-breadcrumb-item
      {@rest}
    >
      {render_slot(@inner_block)}
    </li>
    """
  end

  attr(:href, :string,
    default: nil,
    doc: "Link target — omit to render a placeholder `<a>` without href."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the link.")
  attr(:rest, :global, doc: "Forwarded to the `<a>`: `phx-click`, `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "Crumb label.")

  def breadcrumb_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={
        cn([
          "transition-colors underline hover:text-content-primary lg:no-underline",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
          "rounded-xs",
          @class
        ])
      }
      data-polaris-breadcrumb-link
      {@rest}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the current-page span."
  )

  attr(:rest, :global, doc: "Forwarded to the `<span>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "Current page label.")

  def breadcrumb_page(assigns) do
    ~H"""
    <span
      role="link"
      aria-disabled="true"
      aria-current="page"
      class={cn(["text-content-primary no-underline", @class])}
      data-polaris-breadcrumb-page
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the separator `<li>`.")
  attr(:rest, :global, doc: "Forwarded to the `<li>` (already `aria-hidden`).")

  slot(:inner_block,
    doc: "Custom separator content; defaults to the chevron glyph like the Supabase primitive."
  )

  def breadcrumb_separator(assigns) do
    ~H"""
    <li
      role="presentation"
      aria-hidden="true"
      class={cn(["[&_svg]:size-3.5 text-content-muted", @class])}
      data-polaris-breadcrumb-separator
      {@rest}
    >
      <%= if slot_content?(@inner_block, assigns) do %>
        {render_slot(@inner_block)}
      <% else %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="m9 18 6-6-6-6" />
        </svg>
      <% end %>
    </li>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the ellipsis wrapper.")

  attr(:rest, :global,
    doc: "Forwarded to the `<span>` (a screen-reader \"More\" label is included)."
  )

  def breadcrumb_ellipsis(assigns) do
    ~H"""
    <span
      class={cn(["flex h-4 w-4 items-center justify-center", @class])}
      data-polaris-breadcrumb-ellipsis
      {@rest}
    >
      <svg
        role="presentation"
        aria-hidden="true"
        width="15"
        height="15"
        viewBox="0 0 15 15"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M3.625 7.5C3.625 8.12132 3.12132 8.625 2.5 8.625C1.87868 8.625 1.375 8.12132 1.375 7.5C1.375 6.87868 1.87868 6.375 2.5 6.375C3.12132 6.375 3.625 6.87868 3.625 7.5ZM8.625 7.5C8.625 8.12132 8.12132 8.625 7.5 8.625C6.87868 8.625 6.375 8.12132 6.375 7.5C6.375 6.87868 6.87868 6.375 7.5 6.375C8.12132 6.375 8.625 6.87868 8.625 7.5ZM12.5 8.625C13.1213 8.625 13.625 8.12132 13.625 7.5C13.625 6.87868 13.1213 6.375 12.5 6.375C11.8787 6.375 11.375 6.87868 11.375 7.5C11.375 8.12132 11.8787 8.625 12.5 8.625Z"
          fill="currentColor"
          fill-rule="evenodd"
          clip-rule="evenodd"
        />
      </svg>
      <span class="sr-only">More</span>
    </span>
    """
  end
end
