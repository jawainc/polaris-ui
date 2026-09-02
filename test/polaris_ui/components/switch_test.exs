defmodule PolarisUI.Components.SwitchTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Switch` — the port of
  the Supabase design system Switch (shadcn over Radix): the pill track
  with its translating thumb on the three-size scale, the paired label,
  the hidden form input, and the colocated runtime hook owning the
  instant toggle cycle.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Switch

  @hook "PolarisUI.Components.Switch.Root"

  defp render_switch(assigns) do
    assigns =
      Map.merge(
        %{
          id: "desktop-notifications",
          name: nil,
          value: "on",
          checked: false,
          disabled: false,
          size: "medium",
          on_change: nil,
          class: nil,
          rest: %{},
          label: "Desktop notifications"
        },
        assigns
      )

    rendered_to_string(~H"""
    <.switch
      id={@id}
      name={@name}
      value={@value}
      checked={@checked}
      disabled={@disabled}
      size={@size}
      on_change={@on_change}
      class={@class}
      {assigns[:rest]}
    >
      {@label}
    </.switch>
    """)
  end

  describe "anatomy" do
    test "renders the role=switch track anchored by the hook" do
      html = render_switch(%{})

      assert html =~ ~s{id="desktop-notifications"}
      assert html =~ ~s{data-polaris-switch-root}
      assert html =~ ~s{role="switch"}
      assert html =~ ~s{aria-checked="false"}
      assert html =~ ~s{data-state="unchecked"}
      assert html =~ ~s{phx-hook="#{@hook}"}
    end

    test "renders the pill track with the source treatment" do
      html = render_switch(%{})

      class = track_class(html)

      assert class =~
               "peer group inline-flex shrink-0 cursor-pointer items-center rounded-full border"

      assert class =~ "transition-colors"
      assert class =~ "data-[state=unchecked]:bg-surface-panel"
      assert class =~ "data-[state=unchecked]:hover:bg-surface-border-hover"
    end

    test "renders the thumb keyed off the track's data-state" do
      html = render_switch(%{})

      assert html =~ ~s{data-polaris-switch-thumb}
      class = thumb_class(html)
      assert class =~ "pointer-events-none block rounded-full"
      assert class =~ "bg-content-primary group-data-[state=checked]:bg-white"
      assert class =~ "shadow-lg ring-0 transition-transform motion-reduce:transition-none"
      assert class =~ "group-data-[state=checked]:translate-x-[15px]"
      assert class =~ "group-data-[state=unchecked]:translate-x-px"
    end

    test "renders the label wired to the track" do
      html = render_switch(%{})

      assert html =~ ~s{<label for="desktop-notifications" id="desktop-notifications-label"}
      assert html =~ "Desktop notifications"
      label_class = label_class(html)
      assert label_class =~ "cursor-pointer text-sm font-medium leading-none"
      assert label_class =~ "peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
      assert html =~ ~s{aria-labelledby="desktop-notifications-label"}
    end

    test "renders without a label when there is no inner block" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.switch id="bare" name="bare" />
        """)

      refute html =~ ~s{id="bare-label"}
      refute html =~ "<label"
    end
  end

  describe "sizes" do
    test "medium (the default) is the 20px x 34px track with the 16px thumb" do
      html = render_switch(%{})

      assert track_class(html) =~ "h-[20px] w-[34px]"
      assert thumb_class(html) =~ "h-[16px] w-[16px]"
    end

    test "small is the 16px x 28px track with the 12px thumb" do
      html = render_switch(%{size: "small"})

      assert track_class(html) =~ "h-[16px] w-[28px]"
      thumb = thumb_class(html)
      assert thumb =~ "h-[12px] w-[12px]"
      assert thumb =~ "group-data-[state=checked]:translate-x-[13px]"
    end

    test "large is the 24px x 44px track with the 18px thumb" do
      html = render_switch(%{size: "large"})

      assert track_class(html) =~ "h-[24px] w-[44px]"
      thumb = thumb_class(html)
      assert thumb =~ "h-[18px] w-[18px]"
      assert thumb =~ "group-data-[state=checked]:translate-x-[22px]"
      assert thumb =~ "group-data-[state=unchecked]:translate-x-[3px]"
    end

    test "rejects sizes outside the source's scale" do
      assert_raise ArgumentError, ~r/invalid value for :size/, fn ->
        render_switch(%{size: "xl"})
      end
    end
  end

  describe "states" do
    test "checked fills the track with brand emerald and slides the thumb" do
      html = render_switch(%{checked: true})

      assert html =~ ~s{data-state="checked"}
      assert html =~ ~s{aria-checked="true"}

      class = track_class(html)
      assert class =~ "data-[state=checked]:bg-brand-emerald"
      assert class =~ "data-[state=checked]:hover:bg-brand-emerald-hover"
    end

    test "the track carries the focus-ring treatment" do
      html = render_switch(%{})

      class = track_class(html)
      assert class =~ "focus-visible:outline-none"
      assert class =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    end

    test "disabled locks the track, drops it from the tab order, and dims the label" do
      html = render_switch(%{disabled: true})

      chunk = track_chunk(html)
      assert chunk =~ " disabled"
      assert chunk =~ ~s{tabindex="-1"}
      assert track_class(html) =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end

    test "enabled tracks render the explicit Safari tabindex" do
      html = render_switch(%{})

      assert track_chunk(html) =~ ~s{tabindex="0"}
    end
  end

  describe "form participation" do
    test "with name, renders the hidden native checkbox" do
      html = render_switch(%{name: "notifications", checked: true})

      assert html =~ ~s{<input type="checkbox" name="notifications" value="on"}
      assert html =~ "checked"
      assert html =~ ~s{class="sr-only"}
      assert html =~ ~s{tabindex="-1"}
      assert html =~ ~s{data-polaris-switch-input}
    end

    test "the hidden input is unchecked when unchecked" do
      html = render_switch(%{name: "notifications"})

      refute html =~ ~s{value="on" checked}
    end

    test "without name, no hidden input renders" do
      html = render_switch(%{})

      refute html =~ ~s{type="checkbox"}
    end

    test "the value rides along for the on_change payload" do
      html = render_switch(%{name: "prefs", value: "enabled"})

      assert track_chunk(html) =~ ~s{data-value="enabled"}
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_switch(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "seeds state from the server-rendered data-state" do
      html = render_switch(%{})

      assert html =~ ~s{this._state = this.el.dataset.state || "unchecked"}
    end

    test "implements the Radix toggle cycle" do
      html = render_switch(%{})

      assert html =~ ~s{this._state = this._state === "checked" ? "unchecked" : "checked"}
    end

    test "syncs the hidden input and mirrors aria-checked" do
      html = render_switch(%{})

      assert html =~ ~s{this._input.checked = this._state === "checked"}
      assert html =~ "this.el.setAttribute(\"aria-checked\""
    end

    test "bubbles input/change so phx-change forms observe the toggle" do
      html = render_switch(%{})

      assert html =~ ~s[new Event("input", { bubbles: true })]
      assert html =~ ~s[new Event("change", { bubbles: true })]
    end

    test "pushes the on_change event when configured" do
      html = render_switch(%{on_change: "toggle-notifications"})

      assert html =~ ~s{data-change-event="toggle-notifications"}

      assert html =~
               ~s[pushEvent(name, { state: this._state, value: this.el.dataset.value })]
    end

    test "no data-change-event attribute without on_change" do
      html = render_switch(%{})

      refute html =~ "data-change-event"
    end

    test "re-applies state after LiveView patches" do
      html = render_switch(%{})

      assert html =~ "updated()"
    end
  end

  describe "accessibility" do
    test "the thumb is aria-hidden decoration" do
      html = render_switch(%{})

      assert html =~ ~s{aria-hidden="true"}
    end

    test "forwards aria-describedby through the global attributes" do
      html = render_switch(%{rest: %{"aria-describedby" => "notifications-hint"}})

      assert html =~ ~s{aria-describedby="notifications-hint"}
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_switch(%{rest: %{"data-testid" => "notifications-switch"}})

      assert html =~ ~s{data-testid="notifications-switch"}
    end

    test "classes merge onto the track and win conflicts via cn/1" do
      html = render_switch(%{class: "h-6 w-10"})

      class = track_class(html)
      assert class =~ "h-6 w-10"
      refute class =~ "h-[20px] w-[34px]"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_switch(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp track_chunk(html) do
    [_, rest | _] = String.split(html, "data-polaris-switch-root", parts: 2)
    String.split(rest, ">") |> Enum.at(0)
  end

  defp track_class(html) do
    track_chunk(html)
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp thumb_class(html) do
    [_, rest | _] = String.split(html, ~s{data-polaris-switch-thumb}, parts: 2)

    rest
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp label_class(html) do
    [_, rest | _] = String.split(html, ~s{id="desktop-notifications-label"}, parts: 2)

    rest
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
