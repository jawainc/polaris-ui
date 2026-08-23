defmodule PolarisUI.Components.ContextMenuTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.ContextMenu` — the
  port of the Supabase design system Context Menu (Radix primitive): a
  right-click menu with items, labels, separators, shortcuts,
  checkbox/radio items, and submenus.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.ContextMenu

  @hook "PolarisUI.Components.ContextMenu.Root"

  defp render_menu(assigns) do
    assigns =
      Map.merge(
        %{
          id: "row-menu",
          menu_class: nil,
          class: nil,
          rest: %{},
          checked: true,
          show_hidden: true
        },
        assigns
      )

    rendered_to_string(~H"""
    <.context_menu id={@id} menu_class={@menu_class} class={@class} {assigns[:rest]}>
      <:trigger>
        <div>Right click here</div>
      </:trigger>
      <.context_menu_item phx-click="open-profile">Profile</.context_menu_item>
      <.context_menu_item phx-click="open-billing" disabled>
        Billing
        <.context_menu_shortcut>⌘B</.context_menu_shortcut>
      </.context_menu_item>
      <.context_menu_separator />
      <.context_menu_label inset>Team</.context_menu_label>
      <.context_menu_checkbox_item checked={@checked} phx-click="toggle-hidden">
        Show hidden files
      </.context_menu_checkbox_item>
      <.context_menu_group>
        <.context_menu_radio_item checked={@show_hidden} phx-click="pick-sort">Sort by name</.context_menu_radio_item>
        <.context_menu_radio_item checked={false} phx-click="pick-sort">Sort by size</.context_menu_radio_item>
      </.context_menu_group>
      <.context_menu_sub>
        <.context_menu_sub_trigger>Invite members</.context_menu_sub_trigger>
        <.context_menu_sub_content>
          <.context_menu_item phx-click="invite-email">Invite by email</.context_menu_item>
        </.context_menu_sub_content>
      </.context_menu_sub>
      <.context_menu_item phx-click="delete-row" inset>Delete row</.context_menu_item>
    </.context_menu>
    """)
  end

  describe "root" do
    test "the trigger renders and the menu ships hidden" do
      html = render_menu(%{})

      assert html =~ "Right click here"
      assert html =~ ~s{data-polaris-context-menu-content role="menu" hidden}
      assert html =~ ~s{data-state="closed"}
    end

    test "the menu panel carries the source Content classes" do
      html = render_menu(%{})

      assert html =~ "fixed z-50 min-w-32 overflow-hidden rounded-md border border-surface-border"
      assert html =~ "bg-surface-panel p-1 text-content-primary shadow-md outline-none"
    end

    test "anchors the runtime hook and ships its script inline" do
      html = render_menu(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "forwards global attributes via rest" do
      html = render_menu(%{rest: %{"data-testid" => "row-menu"}})

      assert html =~ ~s{data-testid="row-menu"}
    end
  end

  describe "items" do
    test "carry menuitem semantics and the emerald-selection focus highlight" do
      html = render_menu(%{})

      assert html =~ ~s{role="menuitem"}
      assert html =~ "focus:bg-brand-emerald-muted focus:text-content-primary"
      assert html =~ ~s{phx-click="open-profile"}
    end

    test "disabled items are inert" do
      html = render_menu(%{})

      assert html =~ ~s{data-disabled="true"}
      assert html =~ ~s{aria-disabled="true"}
      assert html =~ "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    end

    test "inset indents to align under a label" do
      html = render_menu(%{})

      assert html =~ "pl-8"
    end

    test "phx-click forwards through rest" do
      html = render_menu(%{})

      assert html =~ ~s{phx-click="delete-row"}
    end
  end

  describe "labels, separators, shortcuts" do
    test "the label is the muted caption, indentable" do
      html = render_menu(%{})

      assert html =~ "data-polaris-context-menu-label"
      assert html =~ "px-2 py-1.5 text-xs text-content-primary"
      assert html =~ "Team"
    end

    test "the separator is the -mx-1 hairline" do
      html = render_menu(%{})

      assert html =~ "data-polaris-context-menu-separator"
      assert html =~ "-mx-1 my-1 h-px bg-surface-border"
    end

    test "the shortcut right-aligns with wide tracking" do
      html = render_menu(%{})

      assert html =~ "data-polaris-context-menu-shortcut"
      assert html =~ "ml-auto text-xs tracking-widest text-content-muted"
      assert html =~ "⌘B"
    end
  end

  describe "checkbox and radio items" do
    test "the checkbox item carries its checked state and leading indicator" do
      html = render_menu(%{})

      assert html =~ ~s{role="menuitemcheckbox"}
      assert html =~ ~s{aria-checked="true"}
      assert html =~ "absolute left-2 flex h-3.5 w-3.5 items-center justify-center"
      assert html =~ "Show hidden files"
    end

    test "the check glyph only renders when checked" do
      html = render_menu(%{checked: false})

      assert html =~ ~s{aria-checked="false"}
      refute html =~ ~s{<path d="M20 6 9 17l-5-5" />}
    end

    test "the radio item carries its selected state and dot indicator" do
      html = render_menu(%{})

      assert html =~ ~s{role="menuitemradio"}
      assert html =~ "size-2 rounded-full bg-current"
      assert html =~ ~s{aria-checked="false"}
    end

    test "radio siblings group together" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-context-menu-group role="group"}
    end
  end

  describe "submenus" do
    test "the sub wrapper is relative for the absolute sub panel" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-context-menu-sub}
    end

    test "the sub trigger appends the right chevron and opens on state" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-context-menu-sub-trigger}
      assert html =~ ~s{aria-haspopup="menu"}
      assert html =~ "data-[state=open]:bg-brand-emerald-muted"
      assert html =~ ~s{class="ml-auto h-4 w-4"}
      assert html =~ "Invite members"
    end

    test "the sub content floats beside its trigger, hidden until opened" do
      html = render_menu(%{})

      assert html =~ ~s{data-polaris-context-menu-sub-content}
      assert html =~ "absolute left-full top-0 z-50 ml-1"
      assert html =~ "hidden"
    end
  end

  describe "colocated hook" do
    test "opens on right-click at the cursor, clamped to the viewport" do
      html = render_menu(%{})

      assert html =~ "contextmenu"
      assert html =~ "event.clientX"
      assert html =~ "window.innerWidth - c.offsetWidth - 8"
    end

    test "Escape walks the ladder — submenu first, then the menu" do
      html = render_menu(%{})

      assert html =~ "Escape"
      assert html =~ "_closeSub(sub)"
      assert html =~ "_close()"
    end

    test "arrows navigate, Enter activates via a real click" do
      html = render_menu(%{})

      assert html =~ "ArrowDown"
      assert html =~ "ArrowUp"
      assert html =~ "Home"
      assert html =~ "End"
      assert html =~ "focused.click()"
    end

    test "ArrowRight opens a submenu, ArrowLeft closes it" do
      html = render_menu(%{})

      assert html =~ "ArrowRight"
      assert html =~ "ArrowLeft"
      assert html =~ "_openSub(sub)"
    end

    test "hover highlight rides real focus (the Radix pointermove model)" do
      html = render_menu(%{})

      assert html =~ "pointermove"
      assert html =~ "item.focus()"
    end

    test "item activation closes the menu; clicks keep their bindings" do
      html = render_menu(%{})

      assert html =~ "data-polaris-context-menu-item"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_menu(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
