defmodule PolarisUI.Components.MenubarTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Menubar` — the port
  of the Supabase design system Menubar (the Radix Menubar primitive):
  the persistent horizontal bar of menus.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Menubar

  @hook "PolarisUI.Components.Menubar.Root"

  defp render_bar(assigns) do
    assigns = Map.merge(%{id: "app-menubar", class: nil, rest: %{}, content: nil}, assigns)

    rendered_to_string(~H"""
    <.menubar id={@id} class={@class} {assigns[:rest]}>{@content}</.menubar>
    """)
  end

  defp render_menu(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}, content: nil}, assigns)

    rendered_to_string(~H"""
    <.menubar_menu class={@class} {assigns[:rest]}>{@content}</.menubar_menu>
    """)
  end

  defp render_trigger(assigns) do
    assigns =
      Map.merge(%{disabled: false, class: nil, rest: %{}, block: {:safe, "File"}}, assigns)

    rendered_to_string(~H"""
    <.menubar_trigger disabled={@disabled} class={@class} {assigns[:rest]}>{@block}</.menubar_trigger>
    """)
  end

  defp render_content(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}, content: nil}, assigns)

    rendered_to_string(~H"""
    <.menubar_content class={@class} {assigns[:rest]}>{@content}</.menubar_content>
    """)
  end

  defp render_item(assigns) do
    assigns =
      Map.merge(
        %{disabled: false, inset: false, class: nil, rest: %{}, block: {:safe, "New Tab"}},
        assigns
      )

    rendered_to_string(~H"""
    <.menubar_item disabled={@disabled} inset={@inset} class={@class} {assigns[:rest]}>
      {@block}
    </.menubar_item>
    """)
  end

  defp render_label(assigns) do
    assigns =
      Map.merge(%{inset: false, class: nil, rest: %{}, block: {:safe, "Profiles"}}, assigns)

    rendered_to_string(~H"""
    <.menubar_label inset={@inset} class={@class} {assigns[:rest]}>{@block}</.menubar_label>
    """)
  end

  defp render_separator(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.menubar_separator class={@class} {assigns[:rest]} />
    """)
  end

  defp render_shortcut(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}, block: {:safe, "⌘T"}}, assigns)

    rendered_to_string(~H"""
    <.menubar_shortcut class={@class} {assigns[:rest]}>{@block}</.menubar_shortcut>
    """)
  end

  defp render_checkbox_item(assigns) do
    assigns =
      Map.merge(
        %{checked: false, disabled: false, class: nil, rest: %{}, block: {:safe, "Show URLs"}},
        assigns
      )

    rendered_to_string(~H"""
    <.menubar_checkbox_item checked={@checked} disabled={@disabled} class={@class} {assigns[:rest]}>
      {@block}
    </.menubar_checkbox_item>
    """)
  end

  defp render_radio_item(assigns) do
    assigns =
      Map.merge(
        %{checked: false, disabled: false, class: nil, rest: %{}, block: {:safe, "Andy"}},
        assigns
      )

    rendered_to_string(~H"""
    <.menubar_radio_item checked={@checked} disabled={@disabled} class={@class} {assigns[:rest]}>
      {@block}
    </.menubar_radio_item>
    """)
  end

  defp render_radio_group(assigns) do
    assigns = Map.merge(%{value: nil, class: nil, rest: %{}, content: nil}, assigns)

    rendered_to_string(~H"""
    <.menubar_radio_group value={@value} class={@class} {assigns[:rest]}>
      {@content}
    </.menubar_radio_group>
    """)
  end

  defp render_group(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}, content: nil}, assigns)

    rendered_to_string(~H"""
    <.menubar_group class={@class} {assigns[:rest]}>{@content}</.menubar_group>
    """)
  end

  defp render_sub(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}, content: nil}, assigns)

    rendered_to_string(~H"""
    <.menubar_sub class={@class} {assigns[:rest]}>{@content}</.menubar_sub>
    """)
  end

  defp render_sub_trigger(assigns) do
    assigns =
      Map.merge(
        %{disabled: false, inset: false, class: nil, rest: %{}, block: {:safe, "Share"}},
        assigns
      )

    rendered_to_string(~H"""
    <.menubar_sub_trigger disabled={@disabled} inset={@inset} class={@class} {assigns[:rest]}>
      {@block}
    </.menubar_sub_trigger>
    """)
  end

  defp render_sub_content(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}, content: nil}, assigns)

    rendered_to_string(~H"""
    <.menubar_sub_content class={@class} {assigns[:rest]}>{@content}</.menubar_sub_content>
    """)
  end

  describe "root" do
    test "renders the bar — the source's h-10 bordered surface" do
      html = render_bar(%{})

      bar = marker_class(html, "data-polaris-menubar")

      assert bar =~
               "flex h-10 items-center space-x-1 rounded-md border border-surface-border bg-surface-base p-1"
    end

    test "merges the caller's class and forwards global attributes" do
      html = render_bar(%{class: "w-fit", rest: %{"data-testid" => "bar"}})

      assert marker_class(html, "data-polaris-menubar") =~ "w-fit"
      assert html =~ ~s{data-testid="bar"}
    end
  end

  describe "menu" do
    test "groups a trigger with its content under a relative wrapper" do
      html = render_menu(%{content: {:safe, "<button>x</button><div>y</div>"}})

      assert html =~ ~s{<div data-polaris-menubar-menu}
      assert marker_class(html, "data-polaris-menubar-menu") =~ "relative"
    end
  end

  describe "trigger" do
    test "renders a real button with the Radix aria contract, closed by default" do
      html = render_trigger(%{})

      assert html =~ ~s{<button type="button" data-polaris-menubar-trigger}
      assert html =~ ~s{aria-haspopup="menu"}
      assert html =~ ~s{aria-expanded="false"}
      assert html =~ ~s{data-state="closed"}

      trigger = marker_class(html, "data-polaris-menubar-trigger")

      assert trigger =~ "rounded-xs px-3 py-1.5 text-sm font-medium"
      assert trigger =~ "focus:bg-brand-emerald-muted focus:text-content-primary"
      assert trigger =~ "data-[state=open]:bg-brand-emerald-muted"
    end

    test "disabled dims and blocks the trigger" do
      html = render_trigger(%{disabled: true})

      assert html =~ ~s{data-disabled="true"}
      assert html =~ ~s{aria-disabled="true"}

      assert marker_class(html, "data-polaris-menubar-trigger") =~
               "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    end

    test "forwards phx-click via rest" do
      assert render_trigger(%{rest: %{"phx-click" => "open-file"}}) =~ ~s{phx-click="open-file"}
    end
  end

  describe "content" do
    test "renders the hidden role=menu panel — the source's min-w-48 overlay" do
      html = render_content(%{})

      assert html =~ ~s{<div data-polaris-menubar-content data-state="closed" role="menu" hidden}

      panel = marker_class(html, "data-polaris-menubar-content")

      assert panel =~
               "fixed z-50 min-w-48 overflow-hidden rounded-md border border-surface-border"

      assert panel =~ "bg-surface-panel p-1 text-content-primary shadow-md"
    end
  end

  describe "items" do
    test "menubar_item — role=menuitem with the shared treatment" do
      html = render_item(%{rest: %{"phx-click" => "new-tab"}})

      assert html =~ ~s{<div data-polaris-menubar-item}
      assert html =~ ~s{role="menuitem"}
      assert html =~ ~s{tabindex="-1"}
      assert html =~ ~s{phx-click="new-tab"}

      assert marker_class(html, "data-polaris-menubar-item") =~
               "relative flex cursor-default select-none items-center rounded-xs px-2 py-1.5 text-sm outline-none"
    end

    test "menubar_item inset indents and disabled blocks" do
      html = render_item(%{disabled: true, inset: true})

      assert marker_class(html, "data-polaris-menubar-item") =~ "pl-8"
      assert html =~ ~s{data-disabled="true"}
      assert html =~ ~s{aria-disabled="true"}
    end

    test "menubar_label — the font-semibold caption, indented with inset" do
      html = render_label(%{inset: true})

      assert marker_class(html, "data-polaris-menubar-label") =~
               "px-2 py-1.5 text-sm font-semibold pl-8"
    end

    test "menubar_separator — the hairline with separator semantics" do
      html = render_separator(%{})

      assert html =~ ~s{<div data-polaris-menubar-separator role="separator"}

      assert marker_class(html, "data-polaris-menubar-separator") =~
               "-mx-1 my-1 h-px bg-surface-border"
    end

    test "menubar_shortcut — right-aligned, wide tracking" do
      html = render_shortcut(%{})

      assert html =~ ~s{<span data-polaris-menubar-shortcut}

      assert marker_class(html, "data-polaris-menubar-shortcut") =~
               "ml-auto text-xs tracking-widest text-content-muted"

      assert html =~ "⌘T"
    end

    test "menubar_checkbox_item — menuitemcheckbox with the check indicator" do
      html = render_checkbox_item(%{checked: true, rest: %{"phx-click" => "toggle"}})

      assert html =~ ~s{role="menuitemcheckbox"}
      assert html =~ ~s{aria-checked="true"}
      assert html =~ ~s{phx-click="toggle"}
      assert html =~ ~s{<path d="M20 6 9 17l-5-5"}

      assert marker_class(html, "data-polaris-menubar-checkbox-item") =~ "py-1.5 pl-8 pr-2"
    end

    test "menubar_radio_item — menuitemradio with the dot, no dot when unchecked" do
      html = render_radio_item(%{checked: true})

      assert html =~ ~s{role="menuitemradio"}
      assert html =~ ~s{aria-checked="true"}
      assert html =~ ~s{<span class="size-2 rounded-full bg-current"}

      unchecked = render_radio_item(%{checked: false})

      assert unchecked =~ ~s{aria-checked="false"}
      refute unchecked =~ ~s{rounded-full bg-current}
    end

    test "menubar_radio_group carries the value for semantics" do
      html = render_radio_group(%{value: "benoit", content: {:safe, "items"}})

      assert html =~ ~s{<div data-polaris-menubar-radio-group role="group" data-value="benoit"}
    end

    test "menubar_group is a semantics-only wrapper" do
      html = render_group(%{content: {:safe, "items"}})

      assert html =~ ~s{<div data-polaris-menubar-group role="group"}
    end
  end

  describe "submenus" do
    test "menubar_sub wraps trigger and content relatively" do
      html = render_sub(%{content: {:safe, "sub"}})

      assert html =~ ~s{<div data-polaris-menubar-sub}
      assert marker_class(html, "data-polaris-menubar-sub") =~ "relative"
    end

    test "menubar_sub_trigger — menuitem with chevron and open highlight" do
      html = render_sub_trigger(%{})

      assert html =~ ~s{data-polaris-menubar-sub-trigger}
      assert html =~ ~s{aria-haspopup="menu"}
      assert html =~ ~s{<path d="m9 18 6-6-6-6"}

      assert marker_class(html, "data-polaris-menubar-sub-trigger") =~
               "data-[state=open]:bg-brand-emerald-muted"
    end

    test "menubar_sub_content — the hidden absolute nested panel" do
      html = render_sub_content(%{content: {:safe, "nested"}})

      assert html =~
               ~s{<div data-polaris-menubar-sub-content data-state="closed" role="menu" hidden}

      assert marker_class(html, "data-polaris-menubar-sub-content") =~
               "absolute left-full top-0 z-50 ml-1 min-w-32"
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the bar and ships its script inline" do
      html = render_bar(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "trigger clicks toggle; hover switches menus; outside clicks close" do
      html = render_bar(%{})

      assert html =~ "this._openMenu(menu)"
      assert html =~ "this._closeAll()"
      assert html =~ "_onTriggerEnter"
      assert html =~ "!root.contains(event.target)"
    end

    test "the hook positions with the source's pinned Radix offsets and flips" do
      html = render_bar(%{})

      assert html =~ "const sideOffset = 8"
      assert html =~ "const alignOffset = -4"
      assert html =~ "window.innerHeight"
    end

    test "ArrowLeft/ArrowRight roam and switch top-level menus — the Radix model" do
      html = render_bar(%{})

      assert html =~ ~s{event.key === "ArrowRight" || event.key === "ArrowLeft"}
      assert html =~ ~s{event.key === "ArrowDown" || event.key === "ArrowUp"}
      assert html =~ "menus()[(menuIndex + 1) % menus().length]"
    end

    test "submenus open on ArrowRight over a sub-trigger; Escape closes inner first" do
      html = render_bar(%{})

      assert html =~ ~s{focused.matches("[data-polaris-menubar-sub-trigger]")}
      assert html =~ "this._openSub(sub)"
      assert html =~ ~s{event.key === "Escape"}
    end

    test "typeahead jumps to matching items" do
      html = render_bar(%{})

      assert html =~ "this._typeahead"
      assert html =~ "startsWith(this._typeahead)"
    end

    test "item activation closes the whole bar and falls through to phx-click" do
      html = render_bar(%{})

      assert html =~ "_onItemActivate"
      assert html =~ "focused.click()"
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
