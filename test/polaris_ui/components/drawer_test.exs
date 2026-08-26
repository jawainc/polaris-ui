defmodule PolarisUI.Components.DrawerTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Drawer` — the port of
  the Supabase design system Drawer (vaul): the edge-anchored modal
  panel with drag-to-dismiss, a direction ladder, and the
  header/body/footer anatomy.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Drawer

  @hook "PolarisUI.Components.Drawer.Drawer"

  defp render_drawer(assigns) do
    assigns =
      Map.merge(
        %{
          id: "invite-drawer",
          open: true,
          title: "Invite members",
          description: "Add teammates to this organization.",
          on_close: "close-invite",
          direction: "bottom",
          hide_handle: false,
          class: nil,
          rest: %{},
          body: nil,
          footer: nil
        },
        assigns
      )

    rendered_to_string(~H"""
    <.drawer
      id={@id}
      open={@open}
      title={@title}
      description={@description}
      on_close={@on_close}
      direction={@direction}
      hide_handle={@hide_handle}
      class={@class}
      {assigns[:rest]}
    >
      {assigns[:body]}
      <:footer :if={assigns[:footer]}>{assigns[:footer]}</:footer>
    </.drawer>
    """)
  end

  describe "visibility" do
    test "closed by default: only the hook root and script render" do
      html = render_drawer(%{open: false})

      assert html =~ ~s{data-state="closed"}
      refute html =~ "<div data-polaris-drawer-overlay"
      refute html =~ "<div data-polaris-drawer-panel"
      refute html =~ "Invite members"
    end

    test "open renders overlay and panel" do
      html = render_drawer(%{})

      assert html =~ ~s{data-state="open"}
      assert html =~ "data-polaris-drawer-overlay"
      assert html =~ "data-polaris-drawer-panel"
      assert html =~ "Invite members"
    end

    test "the overlay is the dimmed scrim" do
      html = render_drawer(%{})

      overlay = marker_class(html, "data-polaris-drawer-overlay")
      assert overlay =~ "fixed inset-0 z-50 bg-overlay"
      assert html =~ ~s{aria-hidden="true"}
    end
  end

  describe "directions" do
    test "bottom anchors to the bottom edge, rounded, capped, with drag room" do
      html = render_drawer(%{direction: "bottom"})

      panel = marker_class(html, "data-polaris-drawer-panel")
      assert panel =~ "inset-x-0 bottom-0 mt-24 max-h-[80vh] rounded-t-lg border-t"
    end

    test "top anchors to the top edge with mirrored geometry" do
      html = render_drawer(%{direction: "top"})

      panel = marker_class(html, "data-polaris-drawer-panel")
      assert panel =~ "inset-x-0 top-0 mb-24 max-h-[80vh] rounded-b-lg border-b"
    end

    test "right anchors to the right edge as a side drawer" do
      html = render_drawer(%{direction: "right"})

      panel = marker_class(html, "data-polaris-drawer-panel")
      assert panel =~ "inset-y-0 right-0 w-3/4 border-l border-surface-border sm:max-w-sm"
    end

    test "left anchors to the left edge as a side drawer" do
      html = render_drawer(%{direction: "left"})

      panel = marker_class(html, "data-polaris-drawer-panel")
      assert panel =~ "inset-y-0 left-0 w-3/4 border-r border-surface-border sm:max-w-sm"
    end

    test "the panel is a bordered, shadowed surface column" do
      html = render_drawer(%{})

      panel = marker_class(html, "data-polaris-drawer-panel")
      assert panel =~ "fixed z-50 flex h-auto flex-col bg-surface-panel text-content-primary"
      assert panel =~ "shadow-lg"
    end

    test "the direction rides on the root for the hook's drag axis" do
      html = render_drawer(%{direction: "right"})

      assert html =~ ~s{data-direction="right"}
    end

    test "rejects an unknown direction" do
      assert_raise ArgumentError, ~r/:direction/, fn ->
        render_drawer(%{direction: "diagonal"})
      end
    end
  end

  describe "drag handle" do
    test "bottom drawers ship the vaul pill — 100px wide, 8px tall" do
      html = render_drawer(%{})

      assert html =~ "data-polaris-drawer-handle"

      assert html =~
               "mx-auto mt-4 h-2 w-[100px] shrink-0 cursor-grab rounded-full bg-surface-border"
    end

    test "side and top drawers have no handle, like the source" do
      for direction <- ~w(top left right) do
        html = render_drawer(%{direction: direction})
        refute html =~ "<div data-polaris-drawer-handle"
      end
    end

    test "hide_handle drops the pill on bottom drawers" do
      html = render_drawer(%{hide_handle: true})

      refute html =~ "<div data-polaris-drawer-handle"
    end
  end

  describe "anatomy" do
    test "the header centers on top/bottom drawers, left-aligns from md:" do
      html = render_drawer(%{})

      header = marker_class(html, "data-polaris-drawer-header")
      assert header =~ "flex flex-col gap-0.5 p-4 md:gap-1.5 md:text-left"
      assert header =~ "text-center"
    end

    test "side drawers keep the header left-aligned at every width" do
      html = render_drawer(%{direction: "right"})

      header = marker_class(html, "data-polaris-drawer-header")
      refute header =~ "text-center"
    end

    test "the title is the source's DrawerTitle — semibold" do
      html = render_drawer(%{})

      assert html =~ ~s{id="invite-drawer-title"}
      assert html =~ "text-base leading-none font-semibold"
      assert html =~ "data-polaris-drawer-title"
    end

    test "the description is the muted single sentence" do
      html = render_drawer(%{})

      assert html =~ ~s{id="invite-drawer-description"}
      assert html =~ "text-sm text-content-secondary"
      assert html =~ "Add teammates to this organization."
    end

    test "the description is optional" do
      html = render_drawer(%{description: nil})

      refute html =~ "invite-drawer-description"
    end

    test "the footer pins to the far edge, stacked" do
      html = render_drawer(%{footer: {:safe, "<button type=\"button\">Send invites</button>"}})

      footer = marker_class(html, "data-polaris-drawer-footer")
      assert footer =~ "mt-auto flex flex-col gap-2 p-4"
    end

    test "no footer section without footer content" do
      html = render_drawer(%{})

      refute html =~ ~s{<div data-polaris-drawer-footer}
    end

    test "the body renders inner content" do
      html = render_drawer(%{body: {:safe, "<p>Email field</p>"}})

      assert html =~ "data-polaris-drawer-body"
      assert html =~ "Email field"
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_drawer(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook exposes the close event and answers Escape" do
      html = render_drawer(%{})

      assert html =~ ~s{data-close-event="close-invite"}
      assert html =~ "pushEvent"
      assert html =~ "Escape"
      assert html =~ "preventDefault"
    end

    test "an overlay click dismisses" do
      html = render_drawer(%{})

      assert html =~ "addEventListener(\"click\", this._onOverlayClick)"
      assert html =~ "event.target === overlay"
    end

    test "the hook traps Tab, focuses the first focusable, restores focus, and locks scroll" do
      html = render_drawer(%{})

      assert html =~ "document.activeElement"
      assert html =~ "last.focus()"
      assert html =~ "first.focus()"
      assert html =~ ~s{document.body.style.overflow = "hidden"}
      assert html =~ "previouslyFocused"
    end

    test "drag-to-dismiss follows vaul's threshold, velocity, and easing" do
      html = render_drawer(%{})

      assert html =~ "pointerdown"
      assert html =~ "0.25"
      assert html =~ "0.4"
      assert html =~ "cubic-bezier(0.32, 0.72, 0, 1)"
      assert html =~ "translateY(100%)"
      assert html =~ "translateX(-100%)"
    end
  end

  describe "accessibility" do
    test "the drawer is a modal region labelled by the title" do
      html = render_drawer(%{})

      assert html =~ ~s{role="dialog"}
      assert html =~ ~s{aria-modal="true"}
      assert html =~ ~s{aria-labelledby="invite-drawer-title"}
      assert html =~ ~s{aria-describedby="invite-drawer-description"}
    end

    test "no aria-describedby without a description" do
      html = render_drawer(%{description: nil})

      refute html =~ "aria-describedby"
    end

    test "the panel is focusable as a fallback" do
      html = render_drawer(%{})

      assert html =~ ~s{tabindex="-1"}
    end
  end

  describe "drawer_close" do
    test "renders a button firing the close event" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.drawer_close on_close="close-invite">Cancel</.drawer_close>
        """)

      assert html =~ "data-polaris-drawer-close"
      assert html =~ ~s{phx-click="close-invite"}
      assert html =~ "Cancel"
      assert html =~ ~s{type="button"}
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_drawer(%{rest: %{"data-testid" => "invite-panel"}})

      assert html =~ ~s{data-testid="invite-panel"}
    end

    test "caller classes merge onto the panel" do
      html = render_drawer(%{class: "max-h-60 overflow-y-auto"})

      assert html =~ "max-h-60"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_drawer(%{body: {:safe, "<p>x</p>"}})

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
