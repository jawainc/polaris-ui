defmodule PolarisUI.Components.TabsTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Tabs` — the port of
  the Supabase design system Tabs (shadcn over Radix): the `border-b`
  tablist with underline triggers, the hidden-when-inactive panels,
  the SSR paint + root-seed contract, and the colocated runtime hook
  owning the automatic-activation state machine with the Radix id
  wiring.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Tabs

  @hook "PolarisUI.Components.Tabs.Root"

  defp render_tabs(assigns) do
    assigns =
      Map.merge(
        %{
          id: "settings",
          value: nil,
          on_change: nil,
          orientation: "horizontal",
          class: nil,
          rest: %{},
          account_active: false,
          password_active: false
        },
        assigns
      )

    rendered_to_string(~H"""
    <.tabs
      id={@id}
      value={@value}
      on_change={@on_change}
      orientation={@orientation}
      class={@class}
      {@rest}
    >
      <.tabs_list>
        <.tabs_trigger value="account" active={@account_active}>Account</.tabs_trigger>
        <.tabs_trigger value="password" active={@password_active}>Password</.tabs_trigger>
      </.tabs_list>
      <.tabs_content value="account" active={@account_active}>Account settings</.tabs_content>
      <.tabs_content value="password" active={@password_active}>Password settings</.tabs_content>
    </.tabs>
    """)
  end

  describe "root anatomy" do
    test "renders the hook-anchored root with the dataset" do
      html = render_tabs(%{})

      assert html =~ ~s{id="settings"}
      assert html =~ ~s{data-polaris-tabs }
      assert html =~ ~s{phx-hook="#{@hook}"}
    end

    test "the value seed and orientation ride the dataset" do
      html = render_tabs(%{value: "account"})

      assert html =~ ~s{data-value="account"}
      assert html =~ ~s{data-orientation="horizontal"}
    end

    test "no data-value attribute without a seed" do
      html = render_tabs(%{})

      root = root_chunk(html)
      refute root =~ "data-value="
    end

    test "vertical orientation rides the dataset" do
      html = render_tabs(%{orientation: "vertical"})

      assert html =~ ~s{data-orientation="vertical"}
    end

    test "rejects orientations outside horizontal/vertical" do
      assert_raise ArgumentError, ~r/invalid value for :orientation/, fn ->
        render_tabs(%{orientation: "diagonal"})
      end
    end

    test "root classes and globals forward" do
      html = render_tabs(%{class: "w-[400px]", rest: %{"data-testid" => "settings-tabs"}})

      assert html =~ ~s{data-testid="settings-tabs"}
      assert html =~ "w-[400px]"
    end
  end

  describe "list anatomy" do
    test "renders the tablist landmark with the shared underline" do
      html = render_tabs(%{})

      assert html =~ ~s{role="tablist"}
      assert html =~ ~s{data-polaris-tabs-list}
      assert list_class(html) =~ "flex items-center border-b border-surface-border"
    end

    test "list classes merge and globals forward (the source's grid demo)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.tabs id="settings">
          <.tabs_list class="grid w-full grid-cols-2" aria-label="Settings">
            <.tabs_trigger value="account">Account</.tabs_trigger>
          </.tabs_list>
          <.tabs_content value="account">Account settings</.tabs_content>
        </.tabs>
        """)

      class = list_class(html)
      assert class =~ "grid w-full grid-cols-2"
      assert class =~ "border-b border-surface-border"
      assert html =~ ~s{aria-label="Settings"}
    end
  end

  describe "triggers" do
    test "real role=tab buttons carrying their value" do
      html = render_tabs(%{})

      # Trailing space: the hook's [data-polaris-tabs-trigger] selectors
      # must not count.
      assert count(html, ~s{data-polaris-tabs-trigger }) == 2
      trigger = trigger_chunk(html, "account")
      assert trigger =~ ~s{role="tab"}
      assert trigger =~ ~s{type="button"}
      assert trigger =~ ~s{data-value="account"}
      assert html =~ "Account"
    end

    test "the source's underline treatment" do
      html = render_tabs(%{})

      class = trigger_class(html, "account")

      assert class =~
               "group inline-flex cursor-pointer items-center justify-center whitespace-nowrap"

      assert class =~ "border-b-2 border-transparent py-1.5 text-sm transition-colors"
      assert class =~ "text-content-secondary hover:text-content-primary"

      assert class =~
               "data-[state=active]:text-content-primary data-[state=active]:border-content-primary"

      assert class =~ "data-[state=active]:shadow-xs"
    end

    test "inactive triggers render the unselected SSR state" do
      html = render_tabs(%{})

      trigger = trigger_chunk(html, "account")
      assert trigger =~ ~s{data-state="inactive"}
      assert trigger =~ ~s{aria-selected="false"}
      assert trigger =~ ~s{tabindex="-1"}
    end

    test "active triggers paint the selected SSR state and the tab stop" do
      html = render_tabs(%{account_active: true})

      trigger = trigger_chunk(html, "account")
      assert trigger =~ ~s{data-state="active"}
      assert trigger =~ ~s{aria-selected="true"}
      assert trigger =~ ~s{tabindex="0"}
    end

    test "triggers carry the focus-ring and disabled treatments" do
      html = render_tabs(%{})

      class = trigger_class(html, "account")

      assert class =~
               "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"

      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
      assert class =~ "disabled:pointer-events-none disabled:opacity-50"
    end

    test "disabled triggers lock and drop from the tab order" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.tabs id="settings">
          <.tabs_list>
            <.tabs_trigger value="account">Account</.tabs_trigger>
            <.tabs_trigger value="password" disabled>Password</.tabs_trigger>
          </.tabs_list>
          <.tabs_content value="account">Account settings</.tabs_content>
          <.tabs_content value="password">Password settings</.tabs_content>
        </.tabs>
        """)

      trigger = trigger_chunk(html, "password")
      assert trigger =~ " disabled"
      assert trigger =~ ~s{data-disabled="true"}
      assert trigger =~ ~s{tabindex="-1"}
    end

    test "trigger classes and globals forward" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.tabs id="settings">
          <.tabs_list>
            <.tabs_trigger value="account" class="font-mono" data-testid="account-trigger">
              Account
            </.tabs_trigger>
          </.tabs_list>
          <.tabs_content value="account">Account settings</.tabs_content>
        </.tabs>
        """)

      assert trigger_class(html, "account") =~ "font-mono"
      assert html =~ ~s{data-testid="account-trigger"}
    end
  end

  describe "panels" do
    test "role=tabpanel regions paired by value" do
      html = render_tabs(%{})

      # Trailing space: the hook's [data-polaris-tabs-content] selectors
      # must not count.
      assert count(html, ~s{data-polaris-tabs-content }) == 2
      # role="tabpanel" is the split marker of panel_chunk/2 below.
      panel = panel_chunk(html, "account")
      assert panel =~ ~s{tabindex="0"}
      assert panel =~ ~s{data-value="account"}
      assert html =~ "Account settings"
    end

    test "the source's panel treatment: spaced below the list, focusable" do
      html = render_tabs(%{})

      class = panel_class(html, "account")
      assert class =~ "mt-4"

      assert class =~
               "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"
    end

    test "inactive panels hide; active panels show" do
      html = render_tabs(%{account_active: true})

      assert panel_chunk(html, "account") =~ ~s{data-state="active"}
      refute panel_chunk(html, "account") =~ " hidden"
      assert panel_chunk(html, "password") =~ ~s{data-state="inactive"}
      assert panel_chunk(html, "password") =~ " hidden"
    end

    test "panel classes and globals forward" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.tabs id="settings">
          <.tabs_list>
            <.tabs_trigger value="account">Account</.tabs_trigger>
          </.tabs_list>
          <.tabs_content value="account" class="pt-2" data-testid="account-panel">
            Account settings
          </.tabs_content>
        </.tabs>
        """)

      assert panel_class(html, "account") =~ "pt-2"
      assert html =~ ~s{data-testid="account-panel"}
    end
  end

  describe "events" do
    test "on_change rides the root dataset" do
      html = render_tabs(%{on_change: "set-tab"})

      assert html =~ ~s{data-change-event="set-tab"}
    end

    test "omit the dataset entry when no event is set" do
      html = render_tabs(%{})

      refute html =~ "data-change-event="
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_tabs(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
      assert html =~ "updated()"
      assert html =~ "destroyed()"
    end

    test "seeds from the root value, falling back to the painted trigger" do
      html = render_tabs(%{})

      assert html =~ "this._value = root.dataset.value ||"
      assert html =~ ~s{el.dataset.state === "active"}
    end

    test "applies state, aria-selected, the roving tab stop, and hidden" do
      html = render_tabs(%{})

      assert html =~ ~s{el.dataset.state = active ? "active" : "inactive"}
      assert html =~ ~s{el.setAttribute("aria-selected", String(active))}
      assert html =~ "el.tabIndex = el === tabstop ? 0 : -1"
      assert html =~ "el.hidden = !active"
    end

    test "the roving tab stop is the active trigger, else the first enabled" do
      html = render_tabs(%{})

      assert html =~
               "(activeTrigger && enabled.indexOf(activeTrigger) !== -1 && activeTrigger) || enabled[0]"
    end

    test "wires the Radix id contract between value-matched pairs" do
      html = render_tabs(%{})

      assert html =~ ~s{trigger.id = root.id + "-trigger-" + trigger.dataset.value}
      assert html =~ ~s{panel.id = root.id + "-content-" + panel.dataset.value}
      assert html =~ ~s{trigger.setAttribute("aria-controls", panel.id)}
      assert html =~ ~s{panel.setAttribute("aria-labelledby", trigger.id)}
    end

    test "caller-provided ids are respected" do
      html = render_tabs(%{})

      assert html =~ "if (!trigger.id)"
      assert html =~ "if (!panel.id)"
    end

    test "the list's aria-orientation follows the root dataset" do
      html = render_tabs(%{})

      assert html =~
               ~s{list.setAttribute("aria-orientation", this._vertical() ? "vertical" : "horizontal")}
    end

    test "selection pushes the on_change event" do
      html = render_tabs(%{})

      assert html =~ "typeof this.pushEvent === \"function\""
      assert html =~ "this.pushEvent(name, { value: value })"
    end

    test "clicks are delegated on the root and skip disabled triggers" do
      html = render_tabs(%{})

      assert html =~ ~s{root.addEventListener("click", this._onClick)}
      assert html =~ ~s{event.target.closest("[data-polaris-tabs-trigger]")}
      assert html =~ ~s{trigger.dataset.disabled !== "true"}
    end

    test "keyboard contract: orientation-aware arrows wrap with automatic activation" do
      html = render_tabs(%{})

      assert html =~
               ~s{event.key === (this._vertical() ? "ArrowDown" : "ArrowRight")}

      assert html =~
               ~s{event.key === (this._vertical() ? "ArrowUp" : "ArrowLeft")}

      assert html =~ "this._select(next.dataset.value)"
      assert html =~ "next.focus()"
      assert html =~ "move((index + 1) % enabled.length)"
      assert html =~ "move((index - 1 + enabled.length) % enabled.length)"
    end

    test "Home and End jump to the first and last enabled triggers" do
      html = render_tabs(%{})

      assert html =~ ~s{event.key === "Home"}
      assert html =~ "move(0)"
      assert html =~ ~s{event.key === "End"}
      assert html =~ "move(enabled.length - 1)"
    end

    test "disabled triggers are skipped by the keyboard contract" do
      html = render_tabs(%{})

      assert html =~
               ~s{this._enabled = () => this._triggers().filter((el) => el.dataset.disabled !== "true")}
    end

    test "re-applies its state after LiveView patches" do
      html = render_tabs(%{})

      updated =
        html
        |> String.split("updated() {")
        |> Enum.at(1)
        |> String.split("destroyed")
        |> List.first()

      assert updated =~ "this._wireIds()"
      assert updated =~ "this._apply()"
    end

    test "cleans up every listener on destroy" do
      html = render_tabs(%{})

      destroyed =
        html
        |> String.split("destroyed() {")
        |> Enum.at(1)
        |> String.split("},", parts: 2)
        |> List.first()

      for listener <- ~w(click keydown) do
        assert destroyed =~ "removeEventListener(\"#{listener}\""
      end
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_tabs(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  # ── helpers ──────────────────────────────────────────────────

  defp count(html, str), do: length(String.split(html, str)) - 1

  defp root_chunk(html) do
    [_, rest | _] = String.split(html, ~s{data-polaris-tabs }, parts: 2)
    String.split(rest, ">") |> Enum.at(0)
  end

  defp list_class(html) do
    [_, rest | _] = String.split(html, ~s{data-polaris-tabs-list}, parts: 2)

    rest
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  # The <button …> opening tag of the trigger whose data-value matches,
  # bounded at </button> so one trigger never bleeds into the next.
  defp trigger_chunk(html, value) do
    html
    |> String.split("<button")
    |> Enum.drop(1)
    |> Enum.map(&(String.split(&1, "</button>", parts: 2) |> List.first()))
    |> Enum.find(&(&1 =~ ~s{data-value="#{value}"}))
    |> String.split(">", parts: 2)
    |> List.first()
  end

  defp trigger_class(html, value) do
    trigger_chunk(html, value)
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  # The <div …> opening tag of the panel whose data-value matches.
  defp panel_chunk(html, value) do
    html
    |> String.split("<div role=\"tabpanel\"")
    |> Enum.drop(1)
    |> Enum.map(&(String.split(&1, ">", parts: 2) |> List.first()))
    |> Enum.find(&(&1 =~ ~s{data-value="#{value}"}))
  end

  defp panel_class(html, value) do
    panel_chunk(html, value)
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
