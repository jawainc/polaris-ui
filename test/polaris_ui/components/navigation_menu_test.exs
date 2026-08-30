defmodule PolarisUI.Components.NavigationMenuTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.NavigationMenu` — the
  port of the Supabase design system NavigationMenu (shadcn over Radix):
  the nav root with its indicator diamond, the list anatomy, the trigger
  with its rotating chevron, the panel treatment, the link, and the
  colocated runtime hook owning the open/switch/close state machine.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.NavigationMenu

  @hook "PolarisUI.Components.NavigationMenu.Root"

  defp render_menu(assigns) do
    assigns =
      Map.merge(%{id: "site-nav", label: nil, class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.navigation_menu id={@id} label={@label} class={@class} {@rest}>
      <.navigation_menu_list>
        <.navigation_menu_item>
          <.navigation_menu_trigger>Getting started</.navigation_menu_trigger>
          <.navigation_menu_content>
            <ul class="grid gap-3 p-6 md:w-[400px]">
              <li><.navigation_menu_link href="/docs">Introduction</.navigation_menu_link></li>
            </ul>
          </.navigation_menu_content>
        </.navigation_menu_item>
        <.navigation_menu_item>
          <.navigation_menu_link href="/docs">Documentation</.navigation_menu_link>
        </.navigation_menu_item>
      </.navigation_menu_list>
    </.navigation_menu>
    """)
  end

  describe "anatomy" do
    test "renders the nav landmark anchored by the hook" do
      html = render_menu(%{})

      assert html =~ "<nav"
      assert html =~ ~s{id="site-nav"}
      assert html =~ ~s{data-polaris-navigation-menu}
      assert html =~ ~s{phx-hook="#{@hook}"}

      class = class_of(html, ~s{id="site-nav"})
      assert class =~ "relative z-10 flex flex-1 items-center justify-center"
    end

    test "renders the list with the source treatment" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-navigation-menu-list}
      assert html =~ "<ul"

      class = class_of(html, "data-polaris-navigation-menu-list")
      assert class =~ "group flex flex-1 list-none items-center justify-center"
      assert class =~ "space-x-1"
    end

    test "renders items wrapping trigger + content" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-navigation-menu-item}
      assert html =~ "<li"
    end

    test "renders the indicator diamond hidden under the bar" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-navigation-menu-indicator}
      assert html =~ ~s{data-state="hidden"}

      class = class_of(html, "data-polaris-navigation-menu-indicator")
      assert class =~ "absolute top-full z-1 flex h-1.5 items-end justify-center"
      assert class =~ "data-[state=hidden]:opacity-0 data-[state=visible]:opacity-100"

      assert html =~ "top-[60%] h-2 w-2 rotate-45 rounded-tl-sm bg-surface-border shadow-md"
    end

    test "the label attr names the nav landmark" do
      html = render_menu(%{label: "Main"})

      assert html =~ ~s{aria-label="Main"}
    end
  end

  describe "trigger" do
    test "renders the source trigger treatment with the rotating chevron" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-navigation-menu-trigger}
      assert html =~ ~s{aria-haspopup="true"}
      assert html =~ ~s{aria-expanded="false"}
      assert html =~ ~s{data-state="closed"}

      class = class_of(html, "data-polaris-navigation-menu-trigger")

      assert class =~
               "group inline-flex w-max items-center justify-center rounded-md text-sm font-medium"

      assert class =~ "h-10 px-4 py-2 transition-colors"
      assert class =~ "bg-surface-base text-content-primary hover:bg-surface-panel-hover"
      assert class =~ "focus:outline-none focus:bg-surface-panel-hover"
      assert class =~ "data-[state=open]:bg-surface-panel-hover/50"
      assert class =~ "disabled:pointer-events-none disabled:opacity-50"

      assert html =~ ~s{<path d="m6 9 6 6 6-6">}
      assert html =~ "group-data-[state=open]:rotate-180"
    end

    test "disabled locks the trigger" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.navigation_menu id="nav">
          <.navigation_menu_list>
            <.navigation_menu_item>
              <.navigation_menu_trigger disabled>Getting started</.navigation_menu_trigger>
            </.navigation_menu_item>
          </.navigation_menu_list>
        </.navigation_menu>
        """)

      chunk = class_of_chunk(html, "data-polaris-navigation-menu-trigger")
      assert chunk =~ " disabled"
      assert chunk =~ ~s{data-disabled="true"}
    end
  end

  describe "content" do
    test "renders hidden with the viewport panel treatment" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-navigation-menu-content}
      assert html =~ ~s{data-state="closed"}
      assert html =~ " hidden"

      class = class_of(html, "data-polaris-navigation-menu-content")
      assert class =~ "fixed z-50 w-max"
      assert class =~ "origin-top-center overflow-hidden"
      assert class =~ "rounded-md border border-surface-border bg-surface-panel"
      assert class =~ "text-content-primary shadow-lg outline-none"
      assert html =~ "md:w-[400px]"
    end
  end

  describe "link" do
    test "renders an anchor with the trigger treatment minus the chevron" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-navigation-menu-link}
      assert html =~ ~s{href="/docs"}

      class = class_of(html, "data-polaris-navigation-menu-link")

      assert class =~
               "group inline-flex w-max items-center justify-center rounded-md text-sm font-medium"

      assert class =~ "h-10 px-4 py-2"

      link_chunk = class_of_chunk(html, "data-polaris-navigation-menu-link")
      refute link_chunk =~ "<svg"
    end

    test "without href, renders a placeholder anchor for phx-click" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.navigation_menu_link phx-click="open-search">Search</.navigation_menu_link>
        """)

      refute html =~ ~s{href=}
      assert html =~ ~s{phx-click="open-search"}
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_menu(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "positions the panel centered under the bar, clamped to the viewport" do
      html = render_menu(%{})

      assert html =~ "rootRect.bottom + 6"
      assert html =~ "rootRect.left + rootRect.width / 2 - w / 2"
      assert html =~ "Math.max(8, Math.min(left, window.innerWidth - w - 8))"
    end

    test "positions the indicator under the open trigger" do
      html = render_menu(%{})

      assert html =~ "ind.style.left = r.left + r.width / 2 - rootRect.left - 4"
    end

    test "clicks toggle and Escape refocuses the trigger" do
      html = render_menu(%{})

      assert html =~ "if (this._open === item) this._close()"
      assert html =~ "this._close({ refocus: true })"
    end

    test "hover opens on a delay and switches instantly while open" do
      html = render_menu(%{})

      assert html =~ "this._openTimer = setTimeout(() => this._openItem(item), 100)"
      assert html =~ "if (this._open && this._open !== item) {"
    end

    test "leaving the bar closes after a grace period" do
      html = render_menu(%{})

      assert html =~ "pointerleave"
      assert html =~ "this._closeTimer = setTimeout(() => {"
      assert html =~ "if (!this._overNav()) this._close()"
    end

    test "click-outside and focus-outside close" do
      html = render_menu(%{})

      assert html =~ ~s{if (this._open && !root.contains(event.target)) this._close()}
    end

    test "arrows roam triggers and switch open menus" do
      html = render_menu(%{})

      assert html =~ ~s{event.key === "ArrowRight" || event.key === "ArrowLeft"}
      assert html =~ "list[(index + dir + list.length) % list.length]"
    end

    test "ArrowDown opens and focuses the first panel control" do
      html = render_menu(%{})

      assert html =~ ~s{event.key === "ArrowDown"}
      assert html =~ ~s{c.querySelector("a, button")}
    end

    test "switching slides from the trigger's direction (from-start/from-end)" do
      html = render_menu(%{})

      assert html =~ "prevIndex < 0 ? 0 : nextIndex > prevIndex ? 1 : -1"
      assert html =~ ~s{fromDirection > 0}
    end

    test "re-syncs state and position after LiveView patches" do
      html = render_menu(%{})

      assert html =~ "updated()"
      assert html =~ "this._syncDom()"
    end

    test "repositions on resize" do
      html = render_menu(%{})

      assert html =~ ~s{window.addEventListener("resize"}
    end
  end

  describe "customization" do
    test "caller classes merge and globals pass through" do
      html = render_menu(%{class: "max-w-[500px]", rest: %{"data-testid" => "nav"}})

      assert class_of(html, ~s{id="site-nav"}) =~ "max-w-[500px]"
      assert html =~ ~s{data-testid="nav"}
    end

    test "list classes merge (the responsive scroll pattern)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.navigation_menu_list class="w-full p-3">
          <.navigation_menu_item>x</.navigation_menu_item>
        </.navigation_menu_list>
        """)

      assert class_of(html, "data-polaris-navigation-menu-list") =~ "w-full p-3"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_menu(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp class_of_chunk(html, marker) do
    [_, rest] = String.split(html, marker, parts: 2)
    String.split(rest, ">") |> Enum.at(0)
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
