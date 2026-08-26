defmodule PolarisUI.Components.HoverCardTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.HoverCard` — the
  port of the Supabase design system Hover Card (Radix primitive):
  the hover-intent preview panel with side/align positioning and the
  zoom-in / slide-in entrances.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.HoverCard

  @hook "PolarisUI.Components.HoverCard.Root"

  defp render_card(assigns) do
    assigns =
      Map.merge(
        %{
          id: "nextjs-card",
          open_delay: 700,
          close_delay: 300,
          side: "bottom",
          align: "center",
          side_offset: 4,
          animate: "zoom-in",
          class: nil,
          rest: %{},
          trigger: {:safe, ~s{<a href="https://nextjs.org">@nextjs</a>}},
          content: {:safe, "<p>The React Framework.</p>"}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.hover_card
      id={@id}
      open_delay={@open_delay}
      close_delay={@close_delay}
      side={@side}
      align={@align}
      side_offset={@side_offset}
      animate={@animate}
      class={@class}
      {assigns[:rest]}
    >
      <:trigger>{@trigger}</:trigger>
      <:content>{@content}</:content>
    </.hover_card>
    """)
  end

  describe "rendering" do
    test "renders trigger and a hidden content panel, closed by default" do
      html = render_card(%{})

      assert html =~ ~s{data-state="closed"}
      assert html =~ "data-polaris-hover-card-trigger"
      assert html =~ "<div data-polaris-hover-card-content"
      assert html =~ "hidden"
      assert html =~ "@nextjs"
      assert html =~ "The React Framework."
    end

    test "the panel is the source's card: bordered, padded, 16rem wide" do
      html = render_card(%{})

      panel = marker_class(html, "data-polaris-hover-card-content")
      assert panel =~ "absolute z-50 w-64 rounded-md border border-surface-border"
      assert panel =~ "bg-surface-panel p-4 text-content-primary shadow-md outline-none"
    end

    test "rejects unknown side, align, and animate" do
      assert_raise ArgumentError, ~r/:side/, fn -> render_card(%{side: "under"}) end
      assert_raise ArgumentError, ~r/:align/, fn -> render_card(%{align: "full"}) end
      assert_raise ArgumentError, ~r/:animate/, fn -> render_card(%{animate: "fade"}) end
    end

    test "caller classes merge onto the panel — the docs' w-80 override" do
      html = render_card(%{class: "w-80"})

      assert html =~ "w-80"
    end

    test "forwards global attributes via rest" do
      html = render_card(%{rest: %{"data-testid" => "preview-card"}})

      assert html =~ ~s{data-testid="preview-card"}
    end
  end

  describe "positioning config" do
    test "side, align, offset, and animate ride on the root" do
      html = render_card(%{side: "top", align: "start", side_offset: 8, animate: "slide-in"})

      assert html =~ ~s{data-side="top"}
      assert html =~ ~s{data-align="start"}
      assert html =~ ~s{data-side-offset="8"}
      assert html =~ ~s{data-animate="slide-in"}
    end

    test "the Radix delay defaults: 700ms open, 300ms close" do
      html = render_card(%{})

      assert html =~ ~s{data-open-delay="700"}
      assert html =~ ~s{data-close-delay="300"}
    end

    test "delays are configurable" do
      html = render_card(%{open_delay: 200, close_delay: 100})

      assert html =~ ~s{data-open-delay="200"}
      assert html =~ ~s{data-close-delay="100"}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_card(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the grace-area contract: enter schedules open, leave schedules close" do
      html = render_card(%{})

      assert html =~ "setTimeout"
      assert html =~ "dataset.openDelay"
      assert html =~ "dataset.closeDelay"
      assert html =~ "_scheduleOpen"
      assert html =~ "_scheduleClose"
      assert html =~ "clearTimeout(this._closeTimer)"
    end

    test "both trigger and content keep the card open (pointer + focus)" do
      html = render_card(%{})

      assert html =~ "wrap.contains(event.target)"
      assert html =~ "c.contains(event.target)"
      assert html =~ "focusin"
      assert html =~ "focusout"
    end

    test "the hook positions beside the trigger and flips on collision" do
      html = render_card(%{})

      assert html =~ "getBoundingClientRect()"
      assert html =~ ~s({ bottom: "top", top: "bottom", right: "left", left: "right" })
    end

    test "the two entrances: zoom-in scales from 99%, slide-in fades with a nudge" do
      zoom = render_card(%{animate: "zoom-in"})
      slide = render_card(%{animate: "slide-in"})

      assert zoom =~ "scale(0.99)"
      assert slide =~ "opacity: 0.5"
      assert slide =~ "translateY(-0.25rem)"
    end

    test "Escape closes" do
      html = render_card(%{})

      assert html =~ "Escape"
    end

    test "a LiveView patch never snaps an open card shut" do
      html = render_card(%{})

      assert html =~ "updated()"
      assert html =~ "removeAttribute(\"hidden\")"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_card(%{})

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
