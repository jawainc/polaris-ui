defmodule PolarisUI.Components.Pagination do
  @moduledoc """
  The Polaris pagination: page navigation with previous and next links —
  the port of the shadcn Pagination the Supabase design system documents
  (`/docs/components/pagination` declares the shadcn source; the Supabase
  repo ships no implementation of its own, so this follows the upstream
  shadcn v4 anatomy) over the Polaris button tokens.

  ## Anatomy

      <.pagination label="Table pagination">
        <.pagination_content>
          <.pagination_item>
            <.pagination_previous href={~p"/logs?page=\#{@page - 1}"} />
          </.pagination_item>
          <.pagination_item>
            <.pagination_link href="#" is_active>1</.pagination_link>
          </.pagination_item>
          <.pagination_item>
            <.pagination_ellipsis />
          </.pagination_item>
          <.pagination_item>
            <.pagination_next phx-click="next-page" />
          </.pagination_item>
        </.pagination_content>
      </.pagination>

    * **pagination** — the `<nav>` landmark (`mx-auto flex w-full
      justify-center`).
    * **content / item** — the row (`flex flex-row items-center gap-1`)
      and one `<li>` per control.
    * **link** — a page number: the source's `buttonVariants` treatment
      with `variant: isActive ? "outline" : "ghost"` — the active page
      carries `aria-current="page"` on the bordered fill, the rest ghost
      into panel-hover on hover.
    * **previous / next** — chevron plus a small-screen-collapsing
      "Previous"/"Next" verb (`hidden sm:inline`).
    * **ellipsis** — the "…" gap with an `sr-only` "More pages".

  Links are `<a>`s: give `href` for navigation or forward `phx-click` /
  `phx-value-page` through the global attributes for LiveView paging.
  The source's Next.js `<Link>` swap is the LiveView default.

  ## States

    * **rest / hover** — ghost links brighten onto `bg-surface-panel-hover`;
      the active outline keeps its bordered fill and lifts its border.
    * **focus-ring** — the shared emerald `focus-visible` ring.
    * **disabled** — anchors have no native `disabled`; pass
      `aria-disabled="true"` and `tabindex="-1"` via the global
      attributes (the disabled styling keys off `aria-disabled`).

  ## Accessibility

  The nav's `label` (default `"pagination"`, the source's hardcoded
  `aria-label`) should name the paginated collection — "Table
  pagination", "Log pagination" — and previous/next carry their
  "Go to previous/next page" labels from the source.

  No colocated hook is required: paging is ordinary navigation or
  `phx-click` round trips.
  """

  use PolarisUI.Component

  @sizes ~w(tiny small medium)

  attr(:label, :string,
    default: "pagination",
    doc: "Accessible name for the `<nav>` landmark — name the paginated collection."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<nav>`.")
  attr(:rest, :global, doc: "Forwarded to the `<nav>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "One `<.pagination_content>` row.")

  def pagination(assigns) do
    ~H"""
    <nav
      aria-label={@label}
      data-polaris-pagination
      class={cn(["mx-auto flex w-full justify-center", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </nav>
    """
  end

  @doc """
  The pagination row — the source's PaginationContent
  (`flex flex-row items-center gap-1`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<ul>`.")
  attr(:rest, :global, doc: "Forwarded to the `<ul>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "The `pagination_item`s.")

  def pagination_content(assigns) do
    ~H"""
    <ul
      data-polaris-pagination-content
      class={cn(["flex flex-row items-center gap-1", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </ul>
    """
  end

  @doc """
  One pagination control — the source's PaginationItem (`<li>`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<li>`.")
  attr(:rest, :global, doc: "Forwarded to the `<li>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "A link, previous, next, or ellipsis.")

  def pagination_item(assigns) do
    ~H"""
    <li data-polaris-pagination-item class={@class} {@rest}>
      {render_slot(@inner_block)}
    </li>
    """
  end

  @doc """
  A page-number link — the source's PaginationLink: the ghost treatment,
  swapping to the bordered outline fill when `is_active` (with
  `aria-current="page"`).
  """
  attr(:is_active, :boolean,
    default: false,
    doc: "Marks the current page (`aria-current=\"page\"`, outline fill)."
  )

  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc:
      "Control height on the Polaris scale: `tiny` 26px · `small` 34px (default) · `medium` 38px."
  )

  attr(:href, :string,
    default: nil,
    doc: "Link target — omit for a placeholder `<a>` driven by `phx-click`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the link.")
  attr(:rest, :global, doc: "Forwarded to the `<a>`: `phx-click`, `phx-value-page`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "The page number.")

  def pagination_link(assigns) do
    validate_in!(:size, assigns.size, @sizes)

    ~H"""
    <a
      href={@href}
      aria-current={if(@is_active, do: "page")}
      data-polaris-pagination-link
      data-active={to_string(@is_active)}
      data-state={if(@is_active, do: "active", else: "inactive")}
      class={link_classes(@size, @is_active, @class)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc """
  The previous-page control — the source's PaginationPrevious: left
  chevron, "Previous" collapsing away under the `sm` breakpoint,
  `aria-label="Go to previous page"`. Slot in to relabel.
  """
  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc: "Control height on the Polaris scale (see `pagination_link`)."
  )

  attr(:href, :string,
    default: nil,
    doc: "Link target — omit for a placeholder `<a>` driven by `phx-click`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the control.")

  attr(:rest, :global,
    doc: """
    Forwarded to the `<a>`: `phx-click`, `phx-value-page`, `aria-disabled`,
    `tabindex`, …
    """
  )

  slot(:inner_block, doc: "Overrides the \"Previous\" label text.")

  def pagination_previous(assigns) do
    validate_in!(:size, assigns.size, @sizes)

    ~H"""
    <a
      href={@href}
      aria-label="Go to previous page"
      data-polaris-pagination-previous
      class={link_classes(@size, false, cn(["gap-1 px-2.5 sm:pl-2.5", @class]))}
      {@rest}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
        class="size-4"
      >
        <path d="m15 18-6-6 6-6" />
      </svg>
      <span class="hidden sm:inline">{render_slot(@inner_block) || "Previous"}</span>
    </a>
    """
  end

  @doc """
  The next-page control — the source's PaginationNext: "Next" collapsing
  away under the `sm` breakpoint, right chevron,
  `aria-label="Go to next page"`. Slot in to relabel.
  """
  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc: "Control height on the Polaris scale (see `pagination_link`)."
  )

  attr(:href, :string,
    default: nil,
    doc: "Link target — omit for a placeholder `<a>` driven by `phx-click`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the control.")

  attr(:rest, :global,
    doc: """
    Forwarded to the `<a>`: `phx-click`, `phx-value-page`, `aria-disabled`,
    `tabindex`, …
    """
  )

  slot(:inner_block, doc: "Overrides the \"Next\" label text.")

  def pagination_next(assigns) do
    validate_in!(:size, assigns.size, @sizes)

    ~H"""
    <a
      href={@href}
      aria-label="Go to next page"
      data-polaris-pagination-next
      class={link_classes(@size, false, cn(["gap-1 px-2.5 sm:pr-2.5", @class]))}
      {@rest}
    >
      <span class="hidden sm:inline">{render_slot(@inner_block) || "Next"}</span>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
        class="size-4"
      >
        <path d="m9 18 6-6-6-6" />
      </svg>
    </a>
    """
  end

  @doc """
  The ellipsis gap — the source's PaginationEllipsis: the more-horizontal
  dots with an `sr-only` "More pages" for screen readers.
  """
  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc: "Reserved square matching the sibling links' height."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the span.")
  attr(:rest, :global, doc: "Forwarded to the `<span>`: `data-*`, …")

  def pagination_ellipsis(assigns) do
    validate_in!(:size, assigns.size, @sizes)

    ~H"""
    <span
      data-polaris-pagination-ellipsis
      class={cn(["flex items-center justify-center", square_size_classes(@size), @class])}
      {@rest}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
        class="size-4"
      >
        <circle cx="12" cy="12" r="1" />
        <circle cx="19" cy="12" r="1" />
        <circle cx="5" cy="12" r="1" />
      </svg>
      <span class="sr-only">More pages</span>
    </span>
    """
  end

  # The shared link treatment: the source's PaginationLink runs
  # buttonVariants({ variant: isActive ? "outline" : "ghost", size }) —
  # here the Polaris button base, ghost and outline variants, and the
  # 26/34/38px height scale with reserved square widths.
  defp link_classes(size, active, extra) do
    cn([
      "inline-flex items-center justify-center rounded-md font-medium transition-colors",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
      "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
      "disabled:pointer-events-none disabled:opacity-50",
      "aria-disabled:pointer-events-none aria-disabled:opacity-50",
      if(active,
        do: [
          "border border-surface-border bg-surface-base text-content-primary shadow-xs",
          "hover:bg-surface-panel-hover hover:border-surface-border-hover"
        ],
        else: "text-content-secondary hover:bg-surface-panel-hover hover:text-content-primary"
      ),
      size_classes(size),
      extra
    ])
  end

  defp size_classes("tiny"), do: "h-[26px] min-w-[26px] px-1 text-xs"
  defp size_classes("small"), do: "h-[34px] min-w-[34px] px-2 text-sm"
  defp size_classes("medium"), do: "h-[38px] min-w-[38px] px-3 text-sm"

  defp square_size_classes("tiny"), do: "size-[26px]"
  defp square_size_classes("small"), do: "size-[34px]"
  defp square_size_classes("medium"), do: "size-[38px]"

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
