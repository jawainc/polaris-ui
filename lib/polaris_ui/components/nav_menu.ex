defmodule PolarisUI.Components.NavMenu do
  @moduledoc """
  The Polaris nav menu: a horizontal tab-style navigation row — the port
  of the Supabase design system `NavMenu` primitive (`packages/ui`) that
  the `PageNav` and `PageHeaderNavigationTabs` fragments wrap.

  ## Anatomy

      <.nav_menu>
        <.nav_menu_item is_active={@page == "overview"}>
          <button type="button" phx-click="show-page" phx-value-page="overview"
            class="h-full cursor-pointer appearance-none bg-transparent text-inherit"
            aria-pressed={@page == "overview"}>
            Overview
          </button>
        </.nav_menu_item>
        <.nav_menu_item is_active={@page == "logs"}>
          <.link navigate={~p"/logs"} class="flex h-full items-center">Logs</.link>
        </.nav_menu_item>
      </.nav_menu>

    * **nav_menu** — the `<nav>` with a bottom border and a flexing
      `role="menu"` list.
    * **nav_menu_item** — one `<li>`; the active item gets the bright
      label and a 2px bottom border in the content color, exactly like
      the Supabase primitive (`data-state` driven, so styling composes
      with `data-[state=active]:` variants).

  Items are *chrome*: labels are plain nouns ("Overview", "Logs"), and
  the interactive element (button or link) is slotted by the caller so
  LiveView navigation stays in the caller's hands.

  ## States

    * **active** — `aria-selected`, bright label, 2px bottom border;
      inactive items brighten on hover.
    * **focus** — slotted triggers own their focus ring; the item passes
      pointer/text styles through (`text-inherit` on the trigger keeps
      the item's state colors in charge).
  """

  use PolarisUI.Component

  attr(:label, :string,
    default: nil,
    doc: "Accessible name for the `<nav>` landmark (falls back to `aria-label` via `rest`)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<nav>`.")
  attr(:rest, :global, doc: "Forwarded to the `<nav>`: `id`, `aria-label`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "One `<.nav_menu_item>` per destination.")

  def nav_menu(assigns) do
    ~H"""
    <nav
      dir="ltr"
      aria-label={@label}
      class={cn(["border-b border-surface-border", @class])}
      data-polaris-nav-menu
      {@rest}
    >
      <ul role="menu" class="flex gap-5" data-polaris-nav-menu-list>
        {render_slot(@inner_block)}
      </ul>
    </nav>
    """
  end

  attr(:is_active, :boolean,
    default: false,
    doc: """
    Selection state (compute from the current route). Sets
    `aria-selected` and `data-state`, driving the bright label and the
    2px bottom border.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the `<li>`.")
  attr(:rest, :global, doc: "Forwarded to the `<li>`: `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The trigger — a `<button>` or `<.link>` filling the item."
  )

  def nav_menu_item(assigns) do
    ~H"""
    <li
      role="none"
      aria-selected={to_string(@is_active)}
      data-state={if(@is_active, do: "active", else: "inactive")}
      class={
        cn([
          "inline-flex items-center justify-center border-b-2 border-transparent whitespace-nowrap",
          "text-sm transition-colors *:py-1.5",
          "text-content-muted hover:text-content-primary",
          "data-[state=active]:text-content-primary data-[state=active]:border-content-primary",
          "disabled:pointer-events-none disabled:opacity-50",
          @class
        ])
      }
      data-polaris-nav-menu-item
      {@rest}
    >
      {render_slot(@inner_block)}
    </li>
    """
  end
end
