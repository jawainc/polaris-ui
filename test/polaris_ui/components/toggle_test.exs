defmodule PolarisUI.Components.ToggleTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Toggle` — the port of
  the Supabase design system Toggle (shadcn over Radix): the standalone
  `aria-pressed` two-state trigger with the ghost/outline variants and
  the shared size scale, and the colocated runtime hook owning the
  press cycle. No form participation, like the source.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Toggle

  @hook "PolarisUI.Components.Toggle.Root"

  defp render_toggle(assigns) do
    assigns =
      Map.merge(
        %{
          id: "bold",
          value: "bold",
          pressed: false,
          variant: "default",
          size: "default",
          disabled: false,
          on_change: nil,
          class: nil,
          rest: %{},
          label: "Bold"
        },
        assigns
      )

    rendered_to_string(~H"""
    <.toggle
      id={@id}
      value={@value}
      pressed={@pressed}
      variant={@variant}
      size={@size}
      disabled={@disabled}
      on_change={@on_change}
      class={@class}
      {assigns[:rest]}
    >
      {@label}
    </.toggle>
    """)
  end

  describe "anatomy" do
    test "renders the aria-pressed button anchored by the hook" do
      html = render_toggle(%{})

      assert html =~ ~s{id="bold"}
      assert html =~ ~s{data-polaris-toggle}
      assert html =~ ~s{aria-pressed="false"}
      assert html =~ ~s{data-state="off"}
      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ "Bold"
    end

    test "renders the source's ghost button vocabulary" do
      html = render_toggle(%{})

      class = toggle_class(html)

      assert class =~
               "inline-flex items-center justify-center gap-1 rounded-md text-sm font-medium"

      assert class =~ "transition-colors text-content-secondary"
      assert class =~ "hover:text-content-primary hover:bg-surface-muted"
      assert class =~ "bg-transparent"
      assert class =~ "data-[state=on]:bg-surface-muted data-[state=on]:text-content-primary"

      assert class =~
               "aria-[pressed=true]:bg-surface-muted aria-[pressed=true]:text-content-primary"
    end

    test "the paint mirrors under aria-pressed, not just data-state" do
      html = render_toggle(%{})

      assert toggle_class(html) =~ "aria-[pressed=true]:"
    end
  end

  describe "variants" do
    test "default stays the borderless ghost" do
      html = render_toggle(%{variant: "default"})

      refute toggle_class(html) =~ "border"
    end

    test "outline adds the frame that brightens when on" do
      html = render_toggle(%{variant: "outline"})

      class = toggle_class(html)
      assert class =~ "border border-surface-border"
      assert class =~ "data-[state=on]:border-surface-border-hover"
      assert class =~ "aria-[pressed=true]:border-surface-border-hover"
    end

    test "rejects variants outside the source's pair" do
      assert_raise ArgumentError, ~r/invalid value for :variant/, fn ->
        render_toggle(%{variant: "solid"})
      end
    end
  end

  describe "sizes" do
    test "default is the 40px shared-scale size" do
      html = render_toggle(%{})

      assert toggle_class(html) =~ "h-10 px-3"
    end

    test "tiny is the 26px compact size with xs text" do
      html = render_toggle(%{size: "tiny"})

      class = toggle_class(html)
      assert class =~ "h-[26px] px-2.5 text-xs"
      refute class =~ "h-10"
    end

    test "sm is the 34px size" do
      html = render_toggle(%{size: "sm"})

      assert toggle_class(html) =~ "h-[34px] px-2.5"
    end

    test "lg is the 44px size" do
      html = render_toggle(%{size: "lg"})

      assert toggle_class(html) =~ "h-11 px-5"
    end

    test "rejects sizes outside the source's scale" do
      assert_raise ArgumentError, ~r/invalid value for :size/, fn ->
        render_toggle(%{size: "xl"})
      end
    end
  end

  describe "states" do
    test "pressed flips data-state and aria-pressed" do
      html = render_toggle(%{pressed: true})

      assert html =~ ~s{data-state="on"}
      assert html =~ ~s{aria-pressed="true"}
    end

    test "the button carries the focus-ring treatment" do
      html = render_toggle(%{})

      class = toggle_class(html)
      assert class =~ "focus-visible:outline-none"
      assert class =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    end

    test "disabled blocks presses, dims, and drops the tab stop" do
      html = render_toggle(%{disabled: true})

      chunk = toggle_chunk(html)
      assert chunk =~ " disabled"
      assert chunk =~ ~s{tabindex="-1"}

      class = toggle_class(html)
      assert class =~ "disabled:pointer-events-none disabled:opacity-50"
    end

    test "enabled toggles render the explicit Safari tabindex" do
      html = render_toggle(%{})

      assert toggle_chunk(html) =~ ~s{tabindex="0"}
    end
  end

  describe "form participation" do
    test "no hidden input, by design — the state is not a form payload" do
      html = render_toggle(%{})

      refute html =~ ~s{type="checkbox"}
      refute html =~ ~s{type="hidden"}
      refute html =~ ~s{class="sr-only"}
    end

    test "the value rides along for the on_change payload" do
      html = render_toggle(%{value: "text-bold"})

      assert toggle_chunk(html) =~ ~s{data-value="text-bold"}
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_toggle(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "seeds state from the server-rendered data-state" do
      html = render_toggle(%{})

      assert html =~ ~s{this._state = this.el.dataset.state || "off"}
    end

    test "implements the Radix press cycle" do
      html = render_toggle(%{})

      assert html =~ ~s{this._state = this._state === "on" ? "off" : "on"}
    end

    test "mirrors aria-pressed from the owned state" do
      html = render_toggle(%{})

      assert html =~
               ~s{this.el.setAttribute("aria-pressed", this._state === "on" ? "true" : "false")}
    end

    test "pushes the on_change event when configured" do
      html = render_toggle(%{on_change: "toggle-bold"})

      assert html =~ ~s{data-change-event="toggle-bold"}

      assert html =~
               ~s[pushEvent(name, { state: this._state, value: this.el.dataset.value })]
    end

    test "no data-change-event attribute without on_change" do
      html = render_toggle(%{})

      refute html =~ "data-change-event"
    end

    test "re-applies state after LiveView patches" do
      html = render_toggle(%{})

      assert html =~ "updated()"
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest (e.g. icon-only aria-label)" do
      html = render_toggle(%{rest: %{"aria-label" => "Toggle bold", "data-testid" => "bold"}})

      assert html =~ ~s{aria-label="Toggle bold"}
      assert html =~ ~s{data-testid="bold"}
    end

    test "classes merge onto the button and win conflicts via cn/1" do
      html = render_toggle(%{class: "h-9"})

      class = toggle_class(html)
      assert class =~ "h-9"
      refute class =~ "h-10"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_toggle(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp toggle_chunk(html) do
    [_, rest | _] = String.split(html, "data-polaris-toggle ", parts: 2)
    String.split(rest, ">") |> Enum.at(0)
  end

  defp toggle_class(html) do
    toggle_chunk(html)
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
