defmodule PolarisUI.Components.PageNav do
  @moduledoc """
  The Polaris page nav: a full-width sub-navigation row for page chrome
  that wraps a `NavMenu` — the port of the Supabase design system
  fragment `ui-patterns/PageNav`.

  It sits below `PageBreadcrumbs` and outside `PageHeader`, giving tab
  navigation the same full-bleed border treatment as the other chrome
  rows while its content stays aligned to the page measure:

      <.page_nav>
        <.nav_menu>
          <.nav_menu_item is_active={@page == "overview"}>
            <button type="button" phx-click="show-page" phx-value-page="overview"
              class="h-full cursor-pointer appearance-none bg-transparent text-inherit"
              aria-pressed={@page == "overview"}>
              Overview
            </button>
          </.nav_menu_item>
          <.nav_menu_item is_active={@page == "logs"}>
            <button type="button" phx-click="show-page" phx-value-page="logs"
              class="h-full cursor-pointer appearance-none bg-transparent text-inherit"
              aria-pressed={@page == "logs"}>
              Logs
            </button>
          </.nav_menu_item>
        </.nav_menu>
      </.page_nav>

  The row stretches the slotted `<.nav_menu>` to the header height and
  neutralizes its own bottom border (`[&>nav]:border-b-0`) so the row's
  border is the only one — the same child-selector CSS the React fragment
  applies to whatever `<nav>` it wraps.

  Presentational only — states (active tab, hover, focus) belong to the
  `nav_menu`/trigger inside.
  """

  use PolarisUI.Component

  import PolarisUI.Components.PageContainer

  # The fragment's pageChromeClassName: chrome rows tighten the page
  # container's padding to a fixed 16px at every breakpoint.
  @chrome_classes "px-4 xl:px-4"
  # The fragment's min-h-(--header-height), with the 44px fallback so the
  # row works before the app defines --header-height.
  @header_height "min-h-[var(--header-height,2.75rem)]"

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the menu wrapper (the fragment's `className` prop)."
  )

  attr(:rest, :global, doc: "Forwarded to the menu wrapper `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The navigation — typically a single `<.nav_menu>` with `<.nav_menu_item>`s."
  )

  def page_nav(assigns) do
    assigns =
      assign(
        assigns,
        row_classes:
          cn([
            "flex #{@header_height} items-center border-b border-surface-border",
            @chrome_classes
          ]),
        menu_classes:
          cn([
            "flex #{@header_height} w-full items-center",
            "[&>nav]:flex [&>nav]:h-[var(--header-height,2.75rem)] [&>nav]:items-center [&>nav]:border-b-0",
            "[&>nav>ul]:h-full [&>nav>ul]:items-center",
            "[&>nav>ul>li]:h-full",
            assigns.class
          ])
      )

    ~H"""
    <.page_container size="full" class={@row_classes} data-polaris-page-nav>
      <div class={@menu_classes} data-polaris-page-nav-menu {@rest}>
        {render_slot(@inner_block)}
      </div>
    </.page_container>
    """
  end
end
