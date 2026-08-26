defmodule PolarisUI.Components.DropdownMenuTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.DropdownMenu` — the
  port of the Supabase design system Dropdown Menu (Radix primitive):
  the trigger-anchored action menu with items, checkbox/radio items,
  labels, separators, shortcuts, and submenus.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.DropdownMenu

  @hook "PolarisUI.Components.DropdownMenu.Root"

  defp render_menu(assigns) do
    assigns =
      Map.merge(
        %{
          id: "account-menu",
          side: "bottom",
          align: "center",
          side_offset: 4,
          same_width: false,
          menu_class: nil,
          class: nil,
          rest: %{},
          trigger: {:safe, "<button type=\"button\">Open</button>"},
          content: nil
        },
        assigns
      )

    rendered_to_string(~H"""
    <.dropdown_menu
      id={@id}
      side={@side}
      align={@align}
      side_offset={@side_offset}
      same_width={@same_width}
      menu_class={@menu_class}
      class={@class}
      {assigns[:rest]}
    >
      <:trigger>{@trigger}</:trigger>
      {@content}
    </.dropdown_menu>
    """)
  end

  describe "root" do
    test "renders trigger and a hidden menu, closed by default" do
      html = render_menu(%{})

      assert html =~ ~s{data-state="closed"}
      assert html =~ "data-polaris-dropdown-menu-trigger"
      assert html =~ "<div data-polaris-dropdown-menu-content"
      assert html =~ "hidden"
      refute html =~ ~s{data-state="open"}
    end

    test "the menu is the source's panel: bordered, padded, min-width, shadow" do
      html = render_menu(%{})

      menu = marker_class(html, "data-polaris-dropdown-menu-content")

      assert menu =~
               "fixed z-50 min-w-32 w-64 overflow-hidden rounded-md border border-surface-border"

      assert menu =~ "bg-surface-panel p-1 text-content-primary shadow-md"
      assert html =~ ~s{<div data-polaris-dropdown-menu-content role="menu"}
    end

    test "rejects unknown side and align" do
      assert_raise ArgumentError, ~r/:side/, fn -> render_menu(%{side: "under"}) end
      assert_raise ArgumentError, ~r/:align/, fn -> render_menu(%{align: "justify"}) end
    end

    test "side/align/offset/same_width ride on the root as positioning config" do
      html = render_menu(%{side: "right", align: "start", side_offset: 8, same_width: true})

      assert html =~ ~s{data-side="right"}
      assert html =~ ~s{data-align="start"}
      assert html =~ ~s{data-side-offset="8"}
      assert html =~ ~s{data-same-width="true"}
    end

    test "menu_class merges onto the panel — the docs' w-56 override" do
      html = render_menu(%{menu_class: "w-56"})

      assert html =~ "w-56"
    end

    test "forwards global attributes via rest" do
      html = render_menu(%{rest: %{"data-testid" => "account-menu-root"}})

      assert html =~ ~s{data-testid="account-menu-root"}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_menu(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "trigger clicks toggle; outside clicks and item activation close" do
      html = render_menu(%{})

      assert html =~ "this._show()"
      assert html =~ "this._close()"
      assert html =~ "!root.contains(event.target)"
    end

    test "the hook positions beside the trigger and flips on collision" do
      html = render_menu(%{})

      assert html =~ "getBoundingClientRect()"
      assert html =~ ~s({ bottom: "top", top: "bottom", right: "left", left: "right" })
    end

    test "the keyboard contract: arrows, Home/End, Enter/Space, typeahead, Escape" do
      html = render_menu(%{})

      assert html =~ "ArrowDown"
      assert html =~ "ArrowUp"
      assert html =~ "\"Home\""
      assert html =~ "\"End\""
      assert html =~ "focused.click()"
      assert html =~ "startsWith(this._typeahead)"
      assert html =~ "Escape"
    end

    test "submenus open on ArrowRight and hover, close on ArrowLeft" do
      html = render_menu(%{})

      assert html =~ "ArrowRight"
      assert html =~ "ArrowLeft"
      assert html =~ "_openSub"
    end

    test "closing returns focus to the trigger (Radix onCloseAutoFocus)" do
      html = render_menu(%{})

      assert html =~ "button.focus()"
      assert html =~ "previouslyFocused"
    end

    test "aria-haspopup and aria-expanded are synced onto the trigger" do
      html = render_menu(%{})

      assert html =~ ~s{button.setAttribute("aria-haspopup", "menu")}
      assert html =~ ~s{button.setAttribute("aria-expanded", this._open ? "true" : "false")}
    end
  end

  describe "items" do
    test "dropdown_menu_item carries the source's treatment and phx-click wiring" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_item phx-click="open-profile" data-testid="profile">
          Profile
        </.dropdown_menu_item>
        """)

      assert html =~ "data-polaris-dropdown-menu-item"
      assert html =~ ~s{role="menuitem"}
      assert html =~ ~s{phx-click="open-profile"}

      assert html =~
               "relative flex cursor-pointer select-none items-center rounded-xs px-2 py-1.5 text-xs"

      assert html =~ "focus:bg-brand-emerald-muted focus:text-content-primary"
      assert html =~ "Profile"
    end

    test "inset indents items with pl-8" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_item inset>Profile</.dropdown_menu_item>
        """)

      assert html =~ "pl-8"
    end

    test "disabled items dim, drop out of keyboard flow, and block activation" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_item disabled>API</.dropdown_menu_item>
        """)

      assert html =~ ~s{data-disabled="true"}
      assert html =~ ~s{aria-disabled="true"}
      assert html =~ "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    end
  end

  describe "labels and separators" do
    test "the label is the muted caption with optional inset" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_label>My account</.dropdown_menu_label>
        """)

      assert html =~ "data-polaris-dropdown-menu-label"
      assert html =~ "px-2 py-1.5 text-xs text-content-muted"
      assert html =~ "My account"
    end

    test "the separator is the full-bleed hairline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_separator />
        """)

      assert html =~ "data-polaris-dropdown-menu-separator"
      assert html =~ "-mx-1 my-1 h-px bg-surface-border"
      assert html =~ ~s{role="separator"}
    end
  end

  describe "shortcut" do
    test "right-aligns the ⌘-string inside an item" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_shortcut>⇧⌘P</.dropdown_menu_shortcut>
        """)

      assert html =~ "data-polaris-dropdown-menu-shortcut"
      assert html =~ "ml-auto text-xs tracking-widest"
      assert html =~ "opacity-60"
      assert html =~ "⇧⌘P"
    end
  end

  describe "checkbox items" do
    test "renders the leading check indicator when checked" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_checkbox_item checked phx-click="toggle-status-bar">
          Status bar
        </.dropdown_menu_checkbox_item>
        """)

      assert html =~ "data-polaris-dropdown-menu-checkbox-item"
      assert html =~ ~s{role="menuitemcheckbox"}
      assert html =~ ~s{aria-checked="true"}
      assert html =~ "absolute left-2 flex h-3.5 w-3.5 items-center justify-center"
      assert html =~ "Status bar"
    end

    test "unchecked renders the reserved slot without the check" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_checkbox_item phx-click="toggle-panel">Panel</.dropdown_menu_checkbox_item>
        """)

      assert html =~ ~s{aria-checked="false"}
      refute html =~ "<path d=\"M20 6 9 17l-5-5\""
    end
  end

  describe "radio items" do
    test "renders the dot indicator when checked" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_radio_group value="bottom">
          <.dropdown_menu_radio_item checked phx-click="set-bottom">Bottom</.dropdown_menu_radio_item>
          <.dropdown_menu_radio_item phx-click="set-top">Top</.dropdown_menu_radio_item>
        </.dropdown_menu_radio_group>
        """)

      assert html =~ "data-polaris-dropdown-menu-radio-item"
      assert html =~ ~s{role="menuitemradio"}
      assert html =~ ~s{aria-checked="true"}
      assert html =~ ~s{aria-checked="false"}
      assert html =~ "size-2 rounded-full bg-current"
      assert html =~ ~s{data-value="bottom"}
    end
  end

  describe "groups and submenus" do
    test "the group is a semantics-only wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_group>
          <.dropdown_menu_item>Team</.dropdown_menu_item>
        </.dropdown_menu_group>
        """)

      assert html =~ "data-polaris-dropdown-menu-group"
      assert html =~ ~s{role="group"}
    end

    test "the sub trigger appends the chevron and opens on data-state" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_sub_trigger>Invite users</.dropdown_menu_sub_trigger>
        """)

      assert html =~ "data-polaris-dropdown-menu-sub-trigger"
      assert html =~ ~s{aria-haspopup="menu"}
      assert html =~ "data-[state=open]:bg-brand-emerald-muted"
      assert html =~ ~s{class="ml-auto size-3 shrink-0 text-content-muted"}
      assert html =~ "Invite users"
    end

    test "the sub content is a hidden nested menu floated beside its trigger" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_sub_content>
          <.dropdown_menu_item phx-click="invite-email">Invite by email</.dropdown_menu_item>
        </.dropdown_menu_sub_content>
        """)

      assert html =~ "data-polaris-dropdown-menu-sub-content"
      assert html =~ "absolute left-full top-0 z-50 ml-1 min-w-32"
      assert html =~ "hidden"
      assert html =~ ~s{role="menu"}
      assert html =~ "shadow-lg"
    end

    test "the sub wrapper is relative for the absolute sub panel" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dropdown_menu_sub>
          <.dropdown_menu_sub_trigger>Invite users</.dropdown_menu_sub_trigger>
        </.dropdown_menu_sub>
        """)

      assert html =~ "data-polaris-dropdown-menu-sub"
      assert html =~ ~s{class="relative"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_menu(%{content: {:safe, "<div>x</div>"}})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
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
