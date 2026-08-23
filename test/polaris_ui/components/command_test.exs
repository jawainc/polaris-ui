defmodule PolarisUI.Components.CommandTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Command` — the port of
  the Supabase design system Command (the cmdk wrapper): a searchable,
  keyboard-driven action list with groups, shortcuts, and an empty state.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Command

  @hook "PolarisUI.Components.Command.Root"

  defp render_command(assigns) do
    assigns = Map.merge(%{id: "actions", class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.command id={@id} class={@class} {assigns[:rest]}>
      <.command_input placeholder="Type a command or search..." />
      <.command_list>
        <.command_empty>No results found.</.command_empty>
        <.command_group heading="Suggestions">
          <.command_item value="calendar" phx-click="open-calendar">
            Calendar
            <:shortcut>⌘P</:shortcut>
          </.command_item>
          <.command_item value="search emoji" keywords={~w(emoji icons)} phx-click="open-emoji">
            Search Emoji
          </.command_item>
        </.command_group>
        <.command_separator />
        <.command_group heading="Settings">
          <.command_item value="billing" disabled phx-click="open-billing">Billing</.command_item>
        </.command_group>
      </.command_list>
    </.command>
    """)
  end

  describe "root" do
    test "carries the source Command classes and the hook" do
      html = render_command(%{})

      assert html =~ ~s{id="actions"}
      assert html =~ "flex h-full w-full flex-col overflow-hidden rounded-md"
      assert html =~ "bg-surface-panel text-content-primary"
      assert html =~ ~s{data-polaris-command}
      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "caller classes merge onto the root" do
      html = render_command(%{class: "rounded-lg border border-surface-border"})

      assert html =~ "rounded-lg"
    end

    test "forwards global attributes via rest" do
      html = render_command(%{rest: %{"data-testid" => "palette"}})

      assert html =~ ~s{data-testid="palette"}
    end
  end

  describe "input" do
    test "renders the bordered search row with the magnifier glyph" do
      html = render_command(%{})

      assert html =~ "data-polaris-command-input-wrapper"
      assert html =~ "flex items-center border-b border-surface-border px-4"
      assert html =~ "size-4 shrink-0 opacity-50"
    end

    test "the field is the source's transparent CommandInput" do
      html = render_command(%{})

      assert html =~ "data-polaris-command-input"
      assert html =~ "flex h-9 w-full rounded-md bg-transparent py-3 text-sm outline-none"
      assert html =~ "placeholder:text-content-muted"
      assert html =~ ~s{placeholder="Type a command or search..."}
    end

    test "the field carries the cmdk combobox semantics" do
      html = render_command(%{})

      assert html =~ ~s{role="combobox"}
      assert html =~ ~s{aria-expanded="true"}
      assert html =~ ~s{aria-autocomplete="list"}
      assert html =~ ~s{autocomplete="off"}
    end

    test "no reset ✕ by default; show_reset_icon renders it dimmed" do
      refute render_command(%{}) =~ ~s{aria-label="Clear search"}

      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.command_input show_reset_icon />
        """)

      assert html =~ "data-polaris-command-reset"
      assert html =~ ~s{aria-label="Clear search"}
      assert html =~ "opacity-0"
      assert html =~ "hover:text-content-primary"
    end

    test "the search glyph can be dropped" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.command_input show_search_icon={false} />
        """)

      refute html =~ "size-4 shrink-0 opacity-50"
    end

    test "disabled dims and locks the field" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.command_input disabled />
        """)

      assert html =~ " disabled"
      assert html =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end
  end

  describe "list and empty" do
    test "the list is the scroll container with listbox semantics" do
      html = render_command(%{})

      assert html =~ "data-polaris-command-list"
      assert html =~ ~s{role="listbox"}
      assert html =~ "max-h-full overflow-y-auto overflow-x-hidden"
    end

    test "the empty state ships hidden until the filter reveals it" do
      html = render_command(%{})

      assert html =~ "data-polaris-command-empty"
      assert html =~ "py-6 text-center text-xs"
      assert html =~ "No results found."
      assert html =~ ~s{<div data-polaris-command-empty role="presentation" hidden}
    end
  end

  describe "groups" do
    test "headings render as the Supabase mono microcopy" do
      html = render_command(%{})

      assert html =~ "data-polaris-command-group-heading"
      assert html =~ "px-2 py-1.5 text-xs font-normal font-mono uppercase tracking-wider text-content-muted"
      assert html =~ "Suggestions"
      assert html =~ "Settings"
    end

    test "groups carry listbox-group semantics" do
      html = render_command(%{})

      assert html =~ ~s{role="group"}
      assert html =~ ~s{aria-label="Suggestions"}
      assert html =~ "overflow-hidden p-1 text-content-primary"
    end

    test "the heading is optional" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.command_group>Items</.command_group>
        """)

      refute html =~ "data-polaris-command-group-heading"
    end

    test "heading_class overrides the mono microcopy" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.command_group heading="Actions" heading_class="font-sans text-sm">Items</.command_group>
        """)

      assert html =~ "font-sans text-sm"
    end
  end

  describe "items" do
    test "carry value, selection, and option semantics" do
      html = render_command(%{})

      assert html =~ ~s{data-polaris-command-item}
      assert html =~ ~s{data-value="calendar"}
      assert html =~ ~s{role="option"}
      assert html =~ ~s{aria-selected="false"}
      assert html =~ ~s{data-selected="false"}
    end

    test "keywords join onto the item for filtering" do
      html = render_command(%{})

      assert html =~ ~s{data-keywords="emoji,icons"}
    end

    test "carry the source CommandItem classes with selected/disabled states" do
      html = render_command(%{})

      assert html =~ "relative flex cursor-default select-none items-center rounded-xs px-2 py-1.5 text-xs outline-none"
      assert html =~ "data-[selected=true]:bg-surface-panel-hover"
      assert html =~ "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    end

    test "phx-click forwards through rest" do
      html = render_command(%{})

      assert html =~ ~s{phx-click="open-calendar"}
      assert html =~ ~s{phx-click="open-billing"}
    end

    test "disabled items mark themselves inert" do
      html = render_command(%{})

      assert html =~ ~s{data-disabled="true"}
      assert html =~ ~s{aria-disabled="true"}
    end

    test "the shortcut slot right-aligns inside the item" do
      html = render_command(%{})

      assert html =~ "ml-auto pl-4"
      assert html =~ "⌘P"
    end
  end

  describe "separator and shortcut" do
    test "the separator is the -mx-1 hairline" do
      html = render_command(%{})

      assert html =~ "data-polaris-command-separator"
      assert html =~ "-mx-1 h-px bg-surface-border"
    end

    test "the standalone shortcut keeps the source classes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.command_shortcut>⌘B</.command_shortcut>
        """)

      assert html =~ "data-polaris-command-shortcut"
      assert html =~ "ml-auto text-xs tracking-widest text-content-muted"
      assert html =~ "⌘B"
    end
  end

  describe "colocated hook" do
    test "filters items by value plus keywords and hides empty groups" do
      html = render_command(%{})

      assert html =~ "_filter()"
      assert html =~ "dataset.keywords"
      assert html =~ "setAttribute(\"hidden\", \"\")"
      assert html =~ "data-polaris-command-group"
    end

    test "keyboard navigation cycles items and Enter dispatches a real click" do
      html = render_command(%{})

      assert html =~ "ArrowDown"
      assert html =~ "ArrowUp"
      assert html =~ "Home"
      assert html =~ "End"
      assert html =~ "item.click()"
      assert html =~ "scrollIntoView"
      assert html =~ "aria-activedescendant"
    end

    test "hover highlight matches cmdk's pointermove model" do
      html = render_command(%{})

      assert html =~ "pointermove"
    end

    test "the reset ✕ clears the query client-side" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.command id="reset-cmd">
          <.command_input show_reset_icon />
        </.command>
        """)

      assert html =~ "data-polaris-command-reset"
      assert html =~ "input.value = \"\""
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_command(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
