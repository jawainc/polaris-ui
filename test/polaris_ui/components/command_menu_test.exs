defmodule PolarisUI.Components.CommandMenuTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.CommandMenu` — the
  port of the Supabase design system Command Menu (ui-patterns): the
  app-wide ⌘K palette composing the Dialog shell around the Command,
  with a search-box trigger and data-driven sections.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.CommandMenu

  @hook "PolarisUI.Components.CommandMenu.Root"

  @sections [
    %{
      heading: "Actions",
      commands: [
        %{id: "alert", name: "Alert"},
        %{id: "invite", name: "Invite member", shortcut: "⌘I"}
      ]
    },
    %{
      heading: "Route commands",
      commands: [
        %{
          id: "supabase-website",
          name: "Go to Supabase website",
          value: "supabase website, docs, www",
          keywords: ["site"],
          disabled: true
        }
      ]
    }
  ]

  defp render_menu(assigns) do
    assigns =
      Map.merge(
        %{
          id: "app-menu",
          open: true,
          on_open_change: "toggle-menu",
          on_command: "run-command",
          sections: @sections,
          open_key: "k",
          placeholder: "Run a command or search...",
          empty_label: "No results found.",
          trigger_label: "Search...",
          show_shortcut: true,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.command_menu
      id={@id}
      open={@open}
      on_open_change={@on_open_change}
      on_command={@on_command}
      sections={@sections}
      open_key={@open_key}
      placeholder={@placeholder}
      empty_label={@empty_label}
      trigger_label={@trigger_label}
      show_shortcut={@show_shortcut}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "visibility" do
    test "closed by default: only the trigger renders" do
      html = render_menu(%{open: false})

      assert html =~ ~s{data-state="closed"}
      assert html =~ "data-polaris-command-menu-trigger"
      refute html =~ ~s{id="app-menu-panel"}
      refute html =~ "Go to Supabase website"
    end

    test "open renders overlay, dialog container, and palette" do
      html = render_menu(%{})

      assert html =~ ~s{data-state="open"}
      assert html =~ "data-polaris-command-menu-overlay"
      assert html =~ "data-polaris-command-menu-container"
      assert html =~ "data-polaris-command-menu-content"
    end
  end

  describe "trigger" do
    test "renders the search-box trigger with glyph, label, and ⌘K badge" do
      html = render_menu(%{})

      assert html =~ ~s{id="app-menu-trigger"}
      assert html =~ "h-[30px]"
      assert html =~ "Search..."
      assert html =~ "⌘K"
      assert html =~ "hidden md:inline-flex"
    end

    test "carries dialog-popup semantics wired to the panel" do
      html = render_menu(%{})

      assert html =~ ~s{aria-haspopup="dialog"}
      assert html =~ ~s{aria-expanded="true"}
      assert html =~ ~s{aria-controls="app-menu-panel"}
    end

    test "the badge can be dropped, and a custom open key relabels it" do
      refute render_menu(%{show_shortcut: false}) =~ "⌘K"
      assert render_menu(%{open_key: "j"}) =~ "⌘J"
    end

    test "the trigger slot replaces the default inner content" do
      assigns = %{sections: @sections}

      html =
        rendered_to_string(~H"""
        <.command_menu
          id="slot-menu"
          open={false}
          on_open_change="toggle"
          on_command="run"
          sections={@sections}
        >
          <:trigger>Open command menu</:trigger>
        </.command_menu>
        """)

      assert html =~ "Open command menu"
      refute html =~ "Search..."
    end
  end

  describe "panel" do
    test "is the mobile bottom sheet that centers on desktop" do
      html = render_menu(%{})

      content = marker_class(html, "data-polaris-command-menu-content")
      assert content =~ "h-[85dvh] w-full flex-col overflow-hidden rounded-t-lg"
      assert content =~ "md:h-auto md:max-h-[500px] md:max-w-lg md:rounded-lg"
    end

    test "is a modal dialog with the source's hidden a11y labels" do
      html = render_menu(%{})

      assert html =~ ~s{role="dialog"}
      assert html =~ ~s{aria-modal="true"}
      assert html =~ ~s{aria-labelledby="app-menu-title"}
      assert html =~ ~s{aria-describedby="app-menu-description"}
      assert html =~ "sr-only"
      assert html =~ "Command menu"
      assert html =~ "Type a command or search"
    end

    test "the overlay dims with the theme-invariant scrim" do
      html = render_menu(%{})

      assert html =~ "bg-overlay"
      assert html =~ "backdrop-blur-xs"
    end
  end

  describe "palette" do
    test "composes the Command parts inside the panel" do
      html = render_menu(%{})

      assert html =~ ~s{id="app-menu-command"}
      assert html =~ "data-polaris-command"
      assert html =~ "data-polaris-command-input"
      assert html =~ ~s{placeholder="Run a command or search..."}
      assert html =~ "data-polaris-command-list"
      assert html =~ "data-polaris-command-empty"
      assert html =~ "No results found."
    end

    test "sections render with the fragment's group rhythm" do
      html = render_menu(%{})

      assert html =~ "Actions"
      assert html =~ "Route commands"
      assert html =~ "py-3 px-2"
      assert html =~ "pb-1.5 font-sans text-sm normal-case tracking-normal"
    end

    test "a separator splits consecutive sections" do
      html = render_menu(%{})

      assert html =~ "data-polaris-command-separator"
    end

    test "commands carry their activation wiring and shortcuts" do
      html = render_menu(%{})

      assert html =~ "Alert"
      assert html =~ ~s{phx-click="run-command"}
      assert html =~ ~s{phx-value-id="invite"}
      assert html =~ "⌘I"
    end

    test "the filter value defaults to the name and joins keywords" do
      html = render_menu(%{})

      assert html =~ ~s{data-value="supabase website, docs, www"}
      assert html =~ ~s{data-keywords="site"}
      assert html =~ ~s{data-value="Alert"}
    end

    test "disabled commands ship inert" do
      html = render_menu(%{})

      assert html =~ ~s{data-disabled="true"}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook and ships its script inline" do
      html = render_menu(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
      assert html =~ ~s{data-open-event="toggle-menu"}
    end

    test "⌘K / Ctrl+K toggles from anywhere, honoring open_key and opt-out" do
      html = render_menu(%{})

      assert html =~ ~s{data-open-key="k"}
      assert html =~ "metaKey || event.ctrlKey"
      assert html =~ "!event.altKey && !event.shiftKey"

      assert render_menu(%{open_key: ""}) =~ ~s{data-open-key=""}
    end

    test "Escape and overlay clicks dismiss; Tab is trapped" do
      html = render_menu(%{})

      assert html =~ "Escape"
      assert html =~ "event.target === container"
      assert html =~ "last.focus()"
      assert html =~ "first.focus()"
    end

    test "open locks scroll and focuses the palette field" do
      html = render_menu(%{})

      assert html =~ ~s{document.body.style.overflow = "hidden"}
      assert html =~ "input.focus()"
    end
  end

  describe "validation" do
    test "rejects sections without a :commands list" do
      assert_raise ArgumentError, ~r/:commands/, fn ->
        render_menu(%{sections: [%{heading: "Broken"}]})
      end
    end

    test "rejects commands without :id or :name" do
      assert_raise ArgumentError, ~r/:id and :name/, fn ->
        render_menu(%{sections: [%{commands: [%{name: "No id"}]}]})
      end
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_menu(%{rest: %{"data-testid" => "app-menu"}})

      assert html =~ ~s{data-testid="app-menu"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_menu(%{})

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
