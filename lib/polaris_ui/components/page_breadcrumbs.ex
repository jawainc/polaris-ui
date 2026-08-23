defmodule PolarisUI.Components.PageBreadcrumbs do
  @moduledoc """
  The Polaris page breadcrumbs: the full-width breadcrumb chrome row —
  the port of the Supabase design system fragment
  `ui-patterns/PageBreadcrumbs`.

  This row is *page chrome*: it sits **above** `<.page_header>` and the
  page content, never inside them. Its `border-b` runs edge to edge
  while the row's content stays aligned to the shared measure via an
  internal `<.page_container size="full">`, so chrome rows and content
  columns line up on the same grid:

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
        <:actions>
          <.page_breadcrumbs_actions>
            <button type="button" phx-click="create">Create</button>
          </.page_breadcrumbs_actions>
        </:actions>
      </.page_breadcrumbs>

  ## Port notes

  The React fragment spreads its remaining props onto `Breadcrumb` and
  takes `actions` / `containerClassName` / `slotClassName` props; here
  those map to the `actions` slot and the three class attrs below (the
  `rest` globals go to the outer wrapper, the fragment's root `div`).

  The chrome row's `px-4 xl:px-4` padding (the fragment's
  `pageChromeClassName`) overrides the container's default `px-6
  xl:px-10` because caller classes are merged last via `cn/1` — the
  conflicting defaults are dropped, tailwind-merge style.

  The row's minimum height tracks the `--header-height` CSS variable
  (2.75rem / 44px fallback) so it stays in lockstep with the app's top
  navigation — define the variable on `:root` to sync them.

  ## Anatomy

    * **wrapper** — the outer `div` (`slot_class`); owns no styling of
      its own, just the `data-polaris-page-breadcrumbs` marker.
    * **container row** — a `size="full"` page container carrying the
      chrome: header-height minimum, bottom border, `py-2`, and the two
      ends (breadcrumb trail, actions) spread with `justify-between`.
    * **breadcrumb** — the `<.breadcrumb>` nav (`class`); `min-w-0`
      lets the trail truncate instead of pushing the actions away, and
      `[&_li]:text-sm` sizes the crumbs.
    * **actions** — typically one `<.page_breadcrumbs_actions>` with
      buttons, held at the trailing edge by `ml-auto`.

  ## Accessibility

  The nav landmark and `aria-current="page"` semantics come from the
  `Breadcrumb` components slotted inside — see
  `PolarisUI.Components.Breadcrumb`. Keep one `page_breadcrumbs` per
  page, directly above the `page_header`.

  Presentational only — no states, no events, no hook.
  """

  use PolarisUI.Component

  import PolarisUI.Components.Breadcrumb
  import PolarisUI.Components.PageContainer

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the `<.breadcrumb>` nav (the React
    fragment's `className` prop).
    """
  )

  attr(:container_class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the chrome row container (the React
    fragment's `containerClassName` prop).
    """
  )

  attr(:slot_class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the outer wrapper div (the React
    fragment's `slotClassName` prop).
    """
  )

  attr(:rest, :global, doc: "Forwarded to the outer wrapper div: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The breadcrumb trail — typically a single `<.breadcrumb_list>`."
  )

  slot(:actions,
    doc: "Trailing chrome — typically a `<.page_breadcrumbs_actions>` with buttons."
  )

  def page_breadcrumbs(assigns) do
    ~H"""
    <div class={@slot_class} data-polaris-page-breadcrumbs {@rest}>
      <.page_container
        size="full"
        class={
          cn([
            "flex min-h-[var(--header-height,2.75rem)] items-center justify-between gap-4 border-b border-surface-border py-2 px-4 xl:px-4",
            @container_class
          ])
        }
      >
        <.breadcrumb class={cn(["min-w-0 flex items-center gap-4 [&_li]:text-sm", @class])}>
          {render_slot(@inner_block)}
        </.breadcrumb>
        {render_slot(@actions)}
      </.page_container>
    </div>
    """
  end

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the actions container."
  )

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "Action buttons for the row's trailing edge.")

  def page_breadcrumbs_actions(assigns) do
    ~H"""
    <div
      class={cn(["ml-auto flex shrink-0 items-center gap-2", @class])}
      data-polaris-page-breadcrumbs-actions
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
