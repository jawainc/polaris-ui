defmodule PolarisUI.Components.TooltipTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Tooltip` — the port
  of the Supabase design system Tooltip (Radix primitive): the
  non-interactive tip with hover-intent delays, the skip window, and
  side/align positioning with per-side slide-in entrance.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Tooltip

  @hook "PolarisUI.Components.Tooltip.Tip"

  defp render_tooltip(assigns) do
    assigns =
      Map.merge(
        %{
          id: "logs-tip",
          open_delay: 700,
          skip_delay: 300,
          side: "top",
          align: "center",
          side_offset: 4,
          class: nil,
          rest: %{},
          trigger: {:safe, ~s{<button type="button">Logs</button>}},
          content: {:safe, "Opens the logs"}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.tooltip
      id={@id}
      open_delay={@open_delay}
      skip_delay={@skip_delay}
      side={@side}
      align={@align}
      side_offset={@side_offset}
      class={@class}
      {assigns[:rest]}
    >
      <:trigger>{@trigger}</:trigger>
      <:content>{@content}</:content>
    </.tooltip>
    """)
  end

  describe "rendering" do
    test "renders a wrapped trigger and a hidden tip, closed by default" do
      html = render_tooltip(%{})

      assert html =~ ~s{data-state="closed"}
      assert html =~ "<span data-polaris-tooltip-trigger"
      assert html =~ "inline-flex max-w-full"
      assert html =~ "data-polaris-tooltip-content"
      assert html =~ "hidden"
      assert html =~ "Logs"
      assert html =~ "Opens the logs"
    end

    test "the root is the positioning context, carrying the config" do
      html = render_tooltip(%{})

      root = marker_class(html, ~s{id="logs-tip"})
      assert root =~ "relative inline-flex"
      assert html =~ ~s{data-polaris-tooltip }
    end

    test "the tip is the source's compact panel over Polaris tokens" do
      html = render_tooltip(%{})

      panel = marker_class(html, "data-polaris-tooltip-content")
      assert panel =~ "absolute z-50 overflow-hidden rounded-md border border-surface-border"
      assert panel =~ "bg-surface-panel px-3 py-1.5 text-xs text-content-primary shadow-md"
    end

    test "rejects unknown side and align" do
      assert_raise ArgumentError, ~r/:side/, fn -> render_tooltip(%{side: "under"}) end
      assert_raise ArgumentError, ~r/:align/, fn -> render_tooltip(%{align: "full"}) end
    end

    test "caller classes merge onto the panel" do
      html = render_tooltip(%{class: "max-w-[280px]"})

      assert html =~ "max-w-[280px]"
    end

    test "forwards global attributes via rest" do
      html = render_tooltip(%{rest: %{"data-testid" => "logs-tip-root"}})

      assert html =~ ~s{data-testid="logs-tip-root"}
    end
  end

  describe "timing config" do
    test "side, align, and offset ride on the root" do
      html = render_tooltip(%{side: "bottom", align: "end", side_offset: 8})

      assert html =~ ~s{data-side="bottom"}
      assert html =~ ~s{data-align="end"}
      assert html =~ ~s{data-side-offset="8"}
    end

    test "the Radix defaults: 700ms open, 300ms skip, side top" do
      html = render_tooltip(%{})

      assert html =~ ~s{data-open-delay="700"}
      assert html =~ ~s{data-skip-delay="300"}
      # the Radix Tooltip default, unlike the hover card's bottom
      assert html =~ ~s{data-side="top"}
    end

    test "delays are configurable" do
      html = render_tooltip(%{open_delay: 100, skip_delay: 50})

      assert html =~ ~s{data-open-delay="100"}
      assert html =~ ~s{data-skip-delay="50"}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_tooltip(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "hover intent: the open delay schedules, the skip window opens at once" do
      html = render_tooltip(%{})

      assert html =~ "setTimeout"
      assert html =~ "dataset.openDelay"
      assert html =~ "_scheduleOpen"
      # the skip window keys off a page-wide close timestamp
      assert html =~ "dataset.skipDelay"
      assert html =~ "__polarisTooltipClosedAt"
      assert html =~ "Date.now()"
    end

    test "no grace area: leaving the trigger closes immediately" do
      html = render_tooltip(%{})

      assert html =~ "pointerleave"
      assert html =~ "this._hide()"

      refute html =~ "dataset.closeDelay", "tooltips have no close grace period"
      refute html =~ "_closeTimer"
      refute html =~ "_scheduleClose"
    end

    test "keyboard: focus opens immediately, focus-out and Escape close" do
      html = render_tooltip(%{})

      assert html =~ "focusin"
      assert html =~ "focusout"
      assert html =~ "Escape"
    end

    test "the hook positions beside the trigger and flips on collision" do
      html = render_tooltip(%{})

      assert html =~ "getBoundingClientRect()"
      assert html =~ ~s({ bottom: "top", top: "bottom", right: "left", left: "right" })
    end

    test "the entrance: fade from 50% with the per-side slide, motion-safe" do
      html = render_tooltip(%{})

      assert html =~ "opacity: 0.5"
      assert html =~ "0.25rem"
      assert html =~ "prefers-reduced-motion"
    end

    test "a LiveView patch never snaps an open tip shut" do
      html = render_tooltip(%{})

      assert html =~ "updated()"
      assert html =~ ~s{removeAttribute("hidden")}
    end
  end

  describe "accessibility" do
    test "the tip is a role=tooltip with a derived id, hidden until open" do
      html = render_tooltip(%{})

      assert html =~
               ~s{<div id="logs-tip-content" role="tooltip" data-polaris-tooltip-content hidden}

      assert html =~ "hidden"
    end

    test "the hook describes the trigger with the tip while open" do
      html = render_tooltip(%{})

      assert html =~ ~s{setAttribute("aria-describedby", c.id)}
      assert html =~ ~s{removeAttribute("aria-describedby")}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_tooltip(%{})

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
