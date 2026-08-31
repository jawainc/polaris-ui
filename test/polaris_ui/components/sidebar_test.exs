defmodule PolarisUI.Components.SidebarTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Sidebar` — the port
  of the Supabase design system Sidebar family: the provider, the
  collapsible rail with its side/variant ladder, the mobile sheet, and
  the group/menu primitives.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Sidebar

  @hook "PolarisUI.Components.Sidebar.Sidebar"

  defp render_sidebar(assigns) do
    assigns =
      Map.merge(
        %{
          id: "app-sidebar",
          open: true,
          open_mobile: false,
          on_toggle: "toggle-sidebar",
          on_close_mobile: nil,
          shortcut: false,
          side: "left",
          variant: "sidebar",
          collapsible: "offcanvas",
          overflowing: false,
          class: nil,
          rest: %{},
          inner: {:safe, "<div data-sidebar=\"header\">Brand</div>"}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.sidebar
      id={@id}
      open={@open}
      open_mobile={@open_mobile}
      on_toggle={@on_toggle}
      on_close_mobile={@on_close_mobile}
      shortcut={@shortcut}
      side={@side}
      variant={@variant}
      collapsible={@collapsible}
      overflowing={@overflowing}
      class={@class}
      {assigns[:rest]}
    >
      {@inner}
    </.sidebar>
    """)
  end

  describe "sidebar_provider" do
    test "renders the flex shell owning the width variables" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_provider id="app-shell">Content</.sidebar_provider>
        """)

      assert html =~ ~s{id="app-shell"}
      assert html =~ "group/sidebar-wrapper flex min-h-svh w-full"
      assert html =~ "--sidebar-width: 13rem; --sidebar-width-icon: 3rem;"
      _ = assigns
    end

    test "widths are caller-tunable, the Supabase defaults overridable" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_provider id="app-shell" width="20rem" width_icon="4rem">x</.sidebar_provider>
        """)

      assert html =~ "--sidebar-width: 20rem; --sidebar-width-icon: 4rem;"
      _ = assigns
    end

    test "the shell paints itself when an inset sidebar lives inside" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_provider id="app-shell">x</.sidebar_provider>
        """)

      assert html =~ "has-[[data-variant=inset]]:bg-surface-base"
      _ = assigns
    end
  end

  describe "sidebar root state" do
    test "expanded is the default state" do
      html = render_sidebar(%{})

      assert html =~ ~s{data-state="expanded"}
      assert html =~ ~s{data-collapsible=""}
    end

    test "collapsed rides the collapsible mode" do
      html = render_sidebar(%{open: false, collapsible: "icon"})

      assert html =~ ~s{data-state="collapsed"}
      assert html =~ ~s{data-collapsible="icon"}
    end

    test "variant and side ride the root for descendant styling" do
      html = render_sidebar(%{variant: "floating", side: "right"})

      assert html =~ ~s{data-variant="floating"}
      assert html =~ ~s{data-side="right"}
    end

    test "rejects unknown side, variant, and collapsible" do
      assert_raise ArgumentError, ~r/:side/, fn -> render_sidebar(%{side: "up"}) end
      assert_raise ArgumentError, ~r/:variant/, fn -> render_sidebar(%{variant: "glass"}) end

      assert_raise ArgumentError, ~r/:collapsible/, fn ->
        render_sidebar(%{collapsible: "fold"})
      end
    end
  end

  describe "sidebar geometry" do
    test "the root is the peer group the inset keys off" do
      html = render_sidebar(%{})

      root = marker_class(html, "data-polaris-sidebar data-state")
      assert root =~ "relative group peer hidden md:block shrink-0"
    end

    test "the gap div reserves the width and collapses offcanvas" do
      html = render_sidebar(%{})

      assert html =~ "h-full w-(--sidebar-width) bg-transparent transition-[width] ease-linear"
      assert html =~ "group-data-[collapsible=offcanvas]:w-0"
      assert html =~ "group-data-[collapsible=icon]:w-(--sidebar-width-icon)"
    end

    test "the panel is absolutely positioned and slides out negative" do
      html = render_sidebar(%{})

      # tailwind-merge folds `top-0` into `inset-y-0`, like the source's stack.
      assert html =~ "absolute h-full duration-100 inset-y-0 z-10 hidden"
      assert html =~ "w-(--sidebar-width) transition-[left,right,width] ease-linear md:flex"
      assert html =~ "left-0 group-data-[collapsible=offcanvas]:-left-(--sidebar-width)"
      assert html =~ "group-data-[side=left]:border-r"
    end

    test "the right side mirrors the offsets and border" do
      html = render_sidebar(%{side: "right"})

      assert html =~ "right-0 group-data-[collapsible=offcanvas]:-right-(--sidebar-width)"
      assert html =~ "group-data-[side=right]:border-l"
    end

    test "floating and inset pad the panel and widen the icon rail" do
      html = render_sidebar(%{variant: "floating"})

      assert html =~ "p-2 group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+1rem+2px)]"
      assert html =~ "group-data-[variant=floating]:rounded-lg group-data-[variant=floating]:border"
      assert html =~ "group-data-[variant=floating]:shadow-sm"
    end

    test "the inner surface is the sidebar background" do
      html = render_sidebar(%{})

      assert html =~ ~s{data-sidebar="sidebar"}
      assert html =~ "flex h-full w-full flex-col bg-surface-base"
    end

    test "overflowing reserves the 3rem stub and overlays" do
      html = render_sidebar(%{overflowing: true})

      root = marker_class(html, "data-polaris-sidebar data-state")
      assert root =~ "w-12"
      assert html =~ "absolute top-0 duration-100 h-full w-(--sidebar-width)"
    end

    test "collapsible=none renders the static rail with no state machine" do
      html = render_sidebar(%{collapsible: "none"})

      assert html =~ "flex h-full w-(--sidebar-width) flex-col bg-surface-base text-content-primary"
      refute html =~ ~s{data-state="expanded"}
      refute html =~ "phx-hook"
    end
  end

  describe "the mobile rung" do
    test "no sheet below md unless open_mobile" do
      html = render_sidebar(%{})

      refute html =~ ~s{role="dialog"}
      refute html =~ "w-[18rem]"
    end

    test "open_mobile renders the scrim and the 18rem sheet" do
      html = render_sidebar(%{open_mobile: true})

      assert html =~ ~s{data-mobile-open="true"}
      assert html =~ "fixed inset-0 z-50 bg-overlay"
      assert html =~ "flex w-[18rem] flex-col bg-surface-base p-0 text-content-primary shadow-lg"
      assert html =~ "md:hidden"
    end

    test "the sheet hugs the same side as the desktop rail" do
      html = render_sidebar(%{open_mobile: true, side: "right"})

      panel = marker_class(html, "data-polaris-sidebar-mobile-panel")
      assert panel =~ "right-0 border-l"
      refute panel =~ "border-r"
    end

    test "the sheet is a labelled modal dialog" do
      html = render_sidebar(%{open_mobile: true})

      assert html =~ ~s{role="dialog"}
      assert html =~ ~s{aria-modal="true"}
      assert html =~ ~s{aria-label="Sidebar"}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook and ships its script inline" do
      html = render_sidebar(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "persists state to the source's cookie contract" do
      html = render_sidebar(%{})

      assert html =~ ~s{data-cookie-max-age="604800"}
      assert html =~ ~s{sidebar:state=}
      assert html =~ "path=/"
      assert html =~ "max-age=${maxAge}"
    end

    test "the shortcut is opt-in, off like the Supabase source" do
      html = render_sidebar(%{})

      assert html =~ ~s{data-shortcut="false"}
      assert html =~ ~s{if (this.el.dataset.shortcut === "true")}

      html = render_sidebar(%{shortcut: true})
      assert html =~ ~s{data-shortcut="true"}
      assert html =~ ~s{event.key.toLowerCase() === "b"}
      assert html =~ "event.metaKey || event.ctrlKey"
    end

    test "toggle and mobile-close events ride the root" do
      html = render_sidebar(%{})

      assert html =~ ~s{data-toggle-event="toggle-sidebar"}
      assert html =~ ~s{data-close-mobile-event="toggle-sidebar"}
    end

    test "on_close_mobile overrides the fallback" do
      html = render_sidebar(%{on_close_mobile: "close-sidebar-mobile"})

      assert html =~ ~s{data-close-mobile-event="close-sidebar-mobile"}
    end

    test "the mobile sheet traps focus, answers Escape and scrim clicks" do
      html = render_sidebar(%{})

      assert html =~ "Escape"
      assert html =~ "this._onOverlayClick"
      assert html =~ "document.body.style.overflow"
      assert html =~ "previouslyFocused"
      assert html =~ "translateX(-100%)"
    end
  end

  describe "sidebar_trigger" do
    test "renders the PanelLeft ghost toggle with its label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_trigger on_toggle="toggle-sidebar" />
        """)

      assert html =~ ~s{data-sidebar="trigger"}
      assert html =~ ~s{phx-click="toggle-sidebar"}
      assert html =~ ~s{<span class="sr-only">Toggle Sidebar</span>}
      assert html =~ "size-7"
      assert html =~ "M9 3v18"
      assert html =~ "disabled:pointer-events-none disabled:opacity-50"
      _ = assigns
    end
  end

  describe "sidebar_rail" do
    test "renders the invisible mouse-only toggle strip" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_rail on_toggle="toggle-sidebar" />
        """)

      assert html =~ ~s{data-sidebar="rail"}
      assert html =~ ~s{aria-label="Toggle Sidebar"}
      assert html =~ ~s{tabindex="-1"}
      assert html =~ ~s{phx-click="toggle-sidebar"}
      assert html =~ "after:w-[2px] hover:after:bg-surface-border"
      assert html =~ "group-data-[side=left]:-right-4 group-data-[side=right]:left-0"
      _ = assigns
    end
  end

  describe "sidebar_inset" do
    test "renders the main that rounds under the inset variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_inset>Page</.sidebar_inset>
        """)

      assert html =~ "<main"
      assert html =~ "relative flex min-h-svh flex-1 flex-col bg-surface-ground"
      assert html =~ "peer-data-[variant=inset]:min-h-[calc(100svh-1rem)]"
      assert html =~ "md:peer-data-[variant=inset]:rounded-xl md:peer-data-[variant=inset]:shadow-sm"
      assert html =~ "md:peer-data-[state=collapsed]:peer-data-[variant=inset]:ml-2"
      assert html =~ "Page"
      _ = assigns
    end
  end

  describe "bands" do
    test "header and footer stack with the source rhythm" do
      assigns = %{}

      header =
        rendered_to_string(~H"""
        <.sidebar_header>Brand</.sidebar_header>
        """)

      footer =
        rendered_to_string(~H"""
        <.sidebar_footer>User</.sidebar_footer>
        """)

      assert header =~ ~s{data-sidebar="header"}
      assert header =~ "flex flex-col gap-2 p-2"
      assert footer =~ ~s{data-sidebar="footer"}
      assert footer =~ "flex flex-col gap-2 p-2"
      _ = assigns
    end

    test "content scrolls and locks in icon mode" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_content>Groups</.sidebar_content>
        """)

      assert html =~ ~s{data-sidebar="content"}
      assert html =~ "flex min-h-0 flex-1 flex-col gap-2 overflow-auto"
      assert html =~ "group-data-[collapsible=icon]:overflow-hidden"
      _ = assigns
    end

    test "separator is the mx-2 hairline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_separator />
        """)

      assert html =~ ~s{data-sidebar="separator"}
      assert html =~ "mx-2 h-px w-auto bg-surface-border"
      _ = assigns
    end

    test "input is the compact search field" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_input placeholder="Search projects" />
        """)

      assert html =~ ~s{data-sidebar="input"}
      assert html =~ "h-8 w-full rounded-md border border-surface-border bg-surface-ground px-2.5 text-sm"
      assert html =~ ~s{placeholder="Search projects"}
      assert html =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      _ = assigns
    end
  end

  describe "groups" do
    test "group is the padded relative cluster" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_group>Body</.sidebar_group>
        """)

      assert html =~ ~s{data-sidebar="group"}
      assert html =~ "relative flex w-full min-w-0 flex-col p-2"
      _ = assigns
    end

    test "the label collapses away in icon mode" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_group_label>Platform</.sidebar_group_label>
        """)

      assert html =~ ~s{data-sidebar="group-label"}
      assert html =~ "flex h-8 shrink-0 items-center rounded-md px-2 text-xs font-medium"
      assert html =~ "text-content-secondary"
      assert html =~ "group-data-[collapsible=icon]:-mt-8 group-data-[collapsible=icon]:opacity-0"
      _ = assigns
    end

    test "the group action pins to the label row and hides in icon mode" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_group_action phx-click="add-project">+</.sidebar_group_action>
        """)

      assert html =~ ~s{data-sidebar="group-action"}
      assert html =~ ~s{phx-click="add-project"}
      assert html =~ "absolute right-3 top-3.5 flex aspect-square w-5"
      assert html =~ "hover:bg-surface-panel-hover/50"
      assert html =~ "group-data-[collapsible=icon]:hidden"
      _ = assigns
    end

    test "group content holds the menus" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_group_content>Menu</.sidebar_group_content>
        """)

      assert html =~ ~s{data-sidebar="group-content"}
      assert html =~ "w-full text-sm"
      _ = assigns
    end
  end

  describe "menus" do
    test "menu and item compose the list and the named row group" do
      assigns = %{}

      menu =
        rendered_to_string(~H"""
        <.sidebar_menu><.sidebar_menu_item>Row</.sidebar_menu_item></.sidebar_menu>
        """)

      assert menu =~ ~s{data-sidebar="menu"}
      assert menu =~ "flex w-full min-w-0 flex-col gap-1"
      assert menu =~ ~s{data-sidebar="menu-item"}
      assert menu =~ "group/menu-item relative"
      _ = assigns
    end

    test "the button carries the source's cva base" do
      html = render_menu_button(%{})

      assert html =~ ~s{data-sidebar="menu-button"}
      assert html =~ "peer/menu-button flex w-full items-center gap-2 overflow-hidden rounded-md"
      assert html =~ "py-2 px-1.5 text-left"
      assert html =~ "text-sm"
      assert html =~ "hover:bg-surface-panel-hover/50"
      assert html =~ "data-[active=true]:bg-surface-panel-hover data-[active=true]:font-medium"
      assert html =~ "text-content-muted data-[active=true]:text-content-primary"
      # Arbitrary-variant selectors render HTML-escaped inside the class attribute.
      assert html =~
               "[&amp;&gt;span:last-child]:truncate [&amp;&gt;svg]:size-5 [&amp;&gt;svg]:shrink-0"
      assert html =~ "disabled:pointer-events-none disabled:opacity-50"
    end

    test "size, active, and has-icon ride as data attributes" do
      html = render_menu_button(%{size: "lg", active: true, has_icon: true})

      assert html =~ ~s{data-size="lg"}
      assert html =~ ~s{data-active="true"}
      assert html =~ ~s{data-has-icon="true"}
    end

    test "the icon-mode square comes from has_icon" do
      html = render_menu_button(%{})

      assert html =~
               "group-data-[collapsible=icon]:size-8! group-data-[collapsible=icon]:pl-1.5! group-data-[collapsible=icon]:pr-2!"

      html = render_menu_button(%{has_icon: false})
      refute html =~ "group-data-[collapsible=icon]:size-8!"
    end

    test "the size scale follows the source heights" do
      html = render_menu_button(%{size: "sm"})
      assert html =~ "h-7 text-xs"

      html = render_menu_button(%{size: "lg"})
      assert html =~ "h-12 text-sm group-data-[collapsible=icon]:p-0!"
    end

    test "the outline variant rings the row with a border shadow" do
      html = render_menu_button(%{variant: "outline"})

      assert html =~ "bg-surface-ground"
      assert html =~ "shadow-[0_0_0_1px_var(--color-surface-border)]"
      assert html =~ "hover:shadow-[0_0_0_1px_var(--color-surface-panel-hover)]"
    end

    test "disabled dead-ends the row; loading keeps it bright" do
      html = render_menu_button(%{disabled: true})
      assert html =~ ~s{disabled}

      html = render_menu_button(%{loading: true})
      assert html =~ "disabled:opacity-100"
    end

    test "tooltip becomes the native title — the icon-collapsed label" do
      html = render_menu_button(%{tooltip: "Tables"})

      assert html =~ ~s{title="Tables"}
    end

    test "href renders the link flavor" do
      html = render_menu_button(%{href: "/projects"})

      assert html =~ ~s{href="/projects"}
      assert html =~ "<a"
      refute html =~ "<button"
    end

    test "phx-click rides the button flavor" do
      html = render_menu_button(%{rest: %{"phx-click" => "go-tables"}})

      assert html =~ ~s{phx-click="go-tables"}
      assert html =~ "<button"
    end

    test "menu_action pins right and follows the button size" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_menu_action phx-click="delete-project">x</.sidebar_menu_action>
        """)

      assert html =~ ~s{data-sidebar="menu-action"}
      assert html =~ "absolute right-1 top-1.5 flex aspect-square w-5"
      assert html =~ "peer-data-[size=default]/menu-button:top-1.5"
      assert html =~ "group-data-[collapsible=icon]:hidden"
      _ = assigns
    end

    test "show_on_hover reveals on row hover and focus" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_menu_action show_on_hover>x</.sidebar_menu_action>
        """)

      assert html =~ "md:opacity-0 group-focus-within/menu-item:opacity-100 group-hover/menu-item:opacity-100"
      _ = assigns
    end

    test "menu_badge is the pointerless count" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_menu_badge>12</.sidebar_menu_badge>
        """)

      assert html =~ ~s{data-sidebar="menu-badge"}
      assert html =~ "text-xs font-medium tabular-nums"
      assert html =~ "pointer-events-none"
      assert html =~ "group-data-[collapsible=icon]:hidden"
      assert html =~ "12"
      _ = assigns
    end

    test "menu_skeleton ghosts the row with the random width bar" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_menu_skeleton show_icon />
        """)

      assert html =~ ~s{data-sidebar="menu-skeleton"}
      assert html =~ "flex h-8 items-center gap-2 rounded-md px-2"
      assert html =~ ~s{data-sidebar="menu-skeleton-icon"}
      assert html =~ ~s{data-sidebar="menu-skeleton-text"}
      assert html =~ "max-w-(--skeleton-width) flex-1 animate-pulse rounded-md bg-surface-muted"
      assert Regex.match?(~r{--skeleton-width: \d+%}, html)
      _ = assigns
    end

    test "the sub tree indents under the item and hides in icon mode" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_menu_sub><.sidebar_menu_sub_item>x</.sidebar_menu_sub_item></.sidebar_menu_sub>
        """)

      assert html =~ ~s{data-sidebar="menu-sub"}
      assert html =~ "mx-3.5 flex min-w-0 translate-x-px flex-col gap-1 border-l border-surface-border px-2.5 py-0.5"
      assert html =~ "group-data-[collapsible=icon]:hidden"
      _ = assigns
    end

    test "sub_button defaults to the anchor flavor with the size scale" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_menu_sub_button href="/projects/tables" size="sm" active>Tables</.sidebar_menu_sub_button>
        """)

      assert html =~ ~s{data-sidebar="menu-sub-button"}
      assert html =~ ~s{data-size="sm"}
      assert html =~ ~s{data-active="true"}
      assert html =~ ~s{href="/projects/tables"}
      assert html =~ "flex h-6 min-w-0 -translate-x-px items-center gap-2"
      assert html =~ "text-xs"
      assert html =~ "data-[active=true]:bg-surface-panel-hover"
      _ = assigns
    end

    test "sub_button renders a button for liveview events" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sidebar_menu_sub_button phx-click="open-tables">Tables</.sidebar_menu_sub_button>
        """)

      assert html =~ "<button"
      assert html =~ ~s{phx-click="open-tables"}
      assert html =~ "text-sm"
      _ = assigns
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_sidebar(%{inner: {:safe, "<div data-sidebar=\"header\">x</div>"}})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp render_menu_button(assigns) do
    assigns =
      Map.merge(
        %{
          active: false,
          variant: "default",
          size: "default",
          has_icon: true,
          loading: false,
          tooltip: nil,
          href: nil,
          disabled: false,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.sidebar_menu_button
      active={@active}
      variant={@variant}
      size={@size}
      has_icon={@has_icon}
      loading={@loading}
      tooltip={@tooltip}
      href={@href}
      disabled={@disabled}
      class={@class}
      {assigns[:rest]}
    >
      <svg /><span>Tables</span>
    </.sidebar_menu_button>
    """)
  end

  # The class attribute of the element carrying the given marker.
  defp marker_class(html, marker) do
    [_, after_marker | _] = String.split(html, marker, parts: 2)

    class =
      case :binary.match(after_marker, ~s{class="}) do
        {index, _} -> binary_part(after_marker, index + 7, byte_size(after_marker) - index - 7)
        :nomatch -> ""
      end

    class |> String.split(~s{"}) |> List.first()
  end
end
