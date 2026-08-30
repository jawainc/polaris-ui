defmodule PolarisUI.Components.PopoverTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Popover` — the port of
  the Supabase design system Popover (Radix primitive): a floating panel
  anchored to a trigger, with server-driven visibility and a hook that
  positions, flips, toggles, and dismisses.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Popover

  @hook "PolarisUI.Components.Popover.Root"

  defp render_popover(assigns) do
    assigns =
      Map.merge(
        %{
          id: "share",
          open: true,
          on_open_change: "toggle-share",
          side: "bottom",
          align: "center",
          side_offset: 4,
          same_width: false,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.popover
      id={@id}
      open={@open}
      on_open_change={@on_open_change}
      side={@side}
      align={@align}
      side_offset={@side_offset}
      same_width={@same_width}
      class={@class}
      {assigns[:rest]}
    >
      <:trigger>Share project</:trigger>
      <:content>Anyone with the link can view.</:content>
    </.popover>
    """)
  end

  describe "visibility" do
    test "closed by default: only the trigger wrapper renders" do
      html = render_popover(%{open: false})

      assert html =~ ~s{data-state="closed"}
      assert html =~ "Share project"
      refute html =~ "<div data-polaris-popover-content"
      refute html =~ "Anyone with the link can view."
    end

    test "open renders the floating content panel" do
      html = render_popover(%{})

      assert html =~ ~s{data-state="open"}
      assert html =~ "data-polaris-popover-content"
      assert html =~ "Anyone with the link can view."
    end
  end

  describe "anatomy" do
    test "the panel carries the source PopoverContent classes" do
      html = render_popover(%{})

      assert html =~ "z-50 w-72 rounded-md border border-surface-border"
      assert html =~ "bg-surface-panel p-4 text-content-primary shadow-md outline-none"
    end

    test "the trigger renders inside a wrapper the hook can target" do
      html = render_popover(%{})

      assert html =~ "data-polaris-popover-trigger"
      assert html =~ "Share project"
    end

    test "the root is a relative inline wrapper carrying the config" do
      html = render_popover(%{})

      assert html =~ ~s{data-open-event="toggle-share"}
      assert html =~ ~s{data-side="bottom"}
      assert html =~ ~s{data-align="center"}
      assert html =~ ~s{data-side-offset="4"}
      assert html =~ ~s{data-same-width="false"}
      assert html =~ ~s{data-polaris-popover}
    end

    test "same_width is mirrored onto the root" do
      html = render_popover(%{same_width: true})

      assert html =~ ~s{data-same-width="true"}
    end
  end

  describe "validation" do
    test "rejects an unknown side" do
      assert_raise ArgumentError, ~r/:side/, fn ->
        render_popover(%{side: "diagonal"})
      end
    end

    test "rejects an unknown align" do
      assert_raise ArgumentError, ~r/:align/, fn ->
        render_popover(%{align: "justify"})
      end
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_popover(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook pushes the open event on toggle, Escape, and click-outside" do
      html = render_popover(%{})

      assert html =~ "pushEvent"
      assert html =~ "Escape"
      assert html =~ "root.contains(event.target)"
    end

    test "the hook positions by side and align and flips on collision" do
      html = render_popover(%{})

      assert html =~ "_position()"
      assert html =~ "offsetWidth"
      assert html =~ "getBoundingClientRect()"
      assert html =~ ~s/{ bottom: "top", top: "bottom", right: "left", left: "right" }/
      assert html =~ "sameWidth"
    end

    test "the panel enters with the source's per-side slide animation" do
      html = render_popover(%{})

      assert html =~ "_animateIn(this._content(), root.dataset.side)"
      assert html =~ ~s{side === "top"}
      assert html =~ "translateY(0.5rem)"
      assert html =~ "translateY(-0.5rem)"
      assert html =~ "translateX(-0.5rem)"
      assert html =~ "translateX(0.5rem)"
    end

    test "the animation only replays on closed→open transitions" do
      html = render_popover(%{})

      assert html =~ "const wasOpen = this._open"
      assert html =~ "if (!wasOpen) this._animateIn(this._content(), this.el.dataset.side)"
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_popover(%{rest: %{"data-testid" => "share-popover"}})

      assert html =~ ~s{data-testid="share-popover"}
    end

    test "caller classes merge onto the content panel" do
      html = render_popover(%{class: "w-auto p-0"})

      assert html =~ "w-auto p-0"
      refute html =~ ~s{ w-72 }
    end
  end

  describe "separator" do
    test "renders the full-width hairline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.popover_separator />
        """)

      assert html =~ ~s{data-polaris-popover-separator}
      assert html =~ "w-full h-px bg-surface-border"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_popover(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
