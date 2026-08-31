defmodule PolarisUI.Components.SheetTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Sheet` — the port of
  the Supabase design system Sheet: the edge-anchored panel with the
  side/size ladder, header/body/footer anatomy, and the modal vs
  non-modal contracts.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Sheet

  @hook "PolarisUI.Components.Sheet.Sheet"

  defp render_sheet(assigns) do
    assigns =
      Map.merge(
        %{
          id: "edit-profile",
          open: true,
          title: "Edit profile",
          description: "Make changes to your profile here.",
          on_close: "close-edit",
          side: "right",
          size: "default",
          modal: true,
          has_overlay: true,
          show_close: true,
          class: nil,
          rest: %{},
          body: nil,
          footer: nil
        },
        assigns
      )

    rendered_to_string(~H"""
    <.sheet
      id={@id}
      open={@open}
      title={@title}
      description={@description}
      on_close={@on_close}
      side={@side}
      size={@size}
      modal={@modal}
      has_overlay={@has_overlay}
      show_close={@show_close}
      class={@class}
      {assigns[:rest]}
    >
      {assigns[:body]}
      <:footer :if={assigns[:footer]}>{assigns[:footer]}</:footer>
    </.sheet>
    """)
  end

  describe "visibility" do
    test "closed by default: only the hook root and script render" do
      html = render_sheet(%{open: false})

      assert html =~ ~s{data-state="closed"}
      refute html =~ "<div data-polaris-sheet-overlay"
      refute html =~ "<div data-polaris-sheet-panel"
      refute html =~ "Edit profile"
    end

    test "open renders overlay and panel" do
      html = render_sheet(%{})

      assert html =~ ~s{data-state="open"}
      assert html =~ "data-polaris-sheet-overlay"
      assert html =~ "data-polaris-sheet-panel"
      assert html =~ "Edit profile"
    end

    test "the overlay is the dimmed, blurred scrim" do
      html = render_sheet(%{})

      overlay = marker_class(html, "data-polaris-sheet-overlay")
      assert overlay =~ "fixed inset-0 z-50 bg-overlay backdrop-blur-xs"
      assert html =~ ~s{aria-hidden="true"}
    end

    test "has_overlay drops the scrim entirely" do
      html = render_sheet(%{has_overlay: false})

      refute html =~ "<div data-polaris-sheet-overlay"
      assert html =~ "data-polaris-sheet-panel"
    end
  end

  describe "sides" do
    test "right anchors to the right edge with an inner left border" do
      html = render_sheet(%{side: "right"})

      panel = marker_class(html, "data-polaris-sheet-panel")
      assert panel =~ "inset-y-0 right-0 h-full border-l border-surface-border"
    end

    test "left anchors to the left edge with an inner right border" do
      html = render_sheet(%{side: "left"})

      panel = marker_class(html, "data-polaris-sheet-panel")
      assert panel =~ "inset-y-0 left-0 h-full border-r border-surface-border"
    end

    test "top anchors to the top edge" do
      html = render_sheet(%{side: "top"})

      panel = marker_class(html, "data-polaris-sheet-panel")
      assert panel =~ "inset-x-0 top-0 w-full border-b border-surface-border"
    end

    test "bottom anchors to the bottom edge" do
      html = render_sheet(%{side: "bottom"})

      panel = marker_class(html, "data-polaris-sheet-panel")
      assert panel =~ "inset-x-0 bottom-0 w-full border-t border-surface-border"
    end

    test "the panel is a shadowed surface over the page" do
      html = render_sheet(%{})

      panel = marker_class(html, "data-polaris-sheet-panel")
      assert panel =~ "fixed z-50 bg-surface-panel text-content-primary shadow-lg"
    end

    test "the side rides on the root for the hook's slide-in axis" do
      html = render_sheet(%{side: "left"})

      assert html =~ ~s{data-side="left"}
    end

    test "rejects an unknown side" do
      assert_raise ArgumentError, ~r/:side/, fn ->
        render_sheet(%{side: "diagonal"})
      end
    end
  end

  describe "sizes" do
    test "default is a third of the viewport" do
      html = render_sheet(%{})

      panel = marker_class(html, "data-polaris-sheet-panel")
      assert panel =~ "lg:w-1/3"
    end

    test "top/bottom default is a third of the height" do
      html = render_sheet(%{side: "bottom"})

      panel = marker_class(html, "data-polaris-sheet-panel")
      assert panel =~ "h-1/3"
    end

    test "content sizes to the body" do
      for side <- ~w(right bottom) do
        html = render_sheet(%{side: side, size: "content"})

        panel = marker_class(html, "data-polaris-sheet-panel")
        assert panel =~ (side == "bottom" && "max-h-screen" || "max-w-full")
      end
    end

    test "sm, lg, and xl follow the source fractions" do
      html = render_sheet(%{size: "sm"})
      assert marker_class(html, "data-polaris-sheet-panel") =~ "lg:w-1/4"

      html = render_sheet(%{size: "lg"})
      assert marker_class(html, "data-polaris-sheet-panel") =~ "lg:w-1/2"

      html = render_sheet(%{size: "xl"})
      assert marker_class(html, "data-polaris-sheet-panel") =~ "lg:w-4/6"

      html = render_sheet(%{side: "top", size: "xl"})
      assert marker_class(html, "data-polaris-sheet-panel") =~ "h-5/6"
    end

    test "xxl is a side-only five sixths; full takes the screen" do
      html = render_sheet(%{size: "xxl"})
      assert marker_class(html, "data-polaris-sheet-panel") =~ "w-5/6"

      html = render_sheet(%{size: "full"})
      assert marker_class(html, "data-polaris-sheet-panel") =~ "w-screen"

      html = render_sheet(%{side: "bottom", size: "full"})
      assert marker_class(html, "data-polaris-sheet-panel") =~ "h-screen"
    end

    test "rejects an unknown size" do
      assert_raise ArgumentError, ~r/:size/, fn ->
        render_sheet(%{size: "giant"})
      end
    end
  end

  describe "anatomy" do
    test "the header bands the title over a hairline, centered then left" do
      html = render_sheet(%{})

      header = marker_class(html, "data-polaris-sheet-header")
      assert header =~ "px-5 py-4 text-center sm:text-left border-b border-surface-border"
    end

    test "the title is the source's text-lg heading" do
      html = render_sheet(%{})

      assert html =~ ~s{id="edit-profile-title"}
      assert html =~ "text-lg leading-none"
      assert html =~ "data-polaris-sheet-title"
    end

    test "the description is the muted single sentence" do
      html = render_sheet(%{})

      assert html =~ ~s{id="edit-profile-description"}
      assert html =~ "text-sm text-content-secondary"
      assert html =~ "Make changes to your profile here."
    end

    test "the description is optional" do
      html = render_sheet(%{description: nil})

      refute html =~ "edit-profile-description"
    end

    test "the footer right-aligns from sm: up, stacked below" do
      html = render_sheet(%{footer: {:safe, "<button type=\"button\">Save changes</button>"}})

      footer = marker_class(html, "data-polaris-sheet-footer")
      assert footer =~ "px-5 py-3 border-t border-surface-border w-full"
      assert footer =~ "flex flex-col-reverse sm:flex-row sm:justify-end gap-2"
    end

    test "no footer section without footer content" do
      html = render_sheet(%{})

      refute html =~ ~s{<div data-polaris-sheet-footer}
    end

    test "the body renders inner content" do
      html = render_sheet(%{body: {:safe, "<p>Name field</p>"}})

      assert html =~ "data-polaris-sheet-body"
      assert html =~ "Name field"
    end
  end

  describe "the built-in close" do
    test "ships the ✕ at the panel's top-right" do
      html = render_sheet(%{})

      close = marker_class(html, ~s{data-polaris-sheet-close phx-click})
      assert close =~ "absolute right-4 top-4 rounded-xs p-0.5 opacity-70 transition-opacity"
      assert html =~ ~s{phx-click="close-edit"}
      assert html =~ ~s{aria-label="Close"}
      assert html =~ "<span class=\"sr-only\">Close</span>"
    end

    test "show_close drops the ✕" do
      html = render_sheet(%{show_close: false})

      refute html =~ "data-polaris-sheet-close"
      refute html =~ "sr-only\">Close"
    end
  end

  describe "modality" do
    test "modal sheets trap focus, lock scroll, and claim aria-modal" do
      html = render_sheet(%{})

      assert html =~ ~s{aria-modal="true"}
      assert html =~ ~s{data-modal="true"}
      assert html =~ ~s{document.body.style.overflow = "hidden"}
      assert html =~ "previouslyFocused"
      assert html =~ "addEventListener(\"click\", this._onOverlayClick)"
    end

    test "non-modal sheets keep the page interactive — no trap, scrim dismissal, or aria-modal" do
      html = render_sheet(%{modal: false})

      assert html =~ ~s{data-modal="false"}
      refute html =~ ~s{aria-modal="true"}
      hook_source = script_source(html)
      assert hook_source =~ "root.dataset.modal !== \"false\""
    end

    test "Escape closes in both modes" do
      for modal <- [true, false] do
        html = render_sheet(%{modal: modal})

        assert html =~ "Escape"
        assert html =~ "preventDefault"
      end
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_sheet(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook exposes the close event and slides in from the anchored edge" do
      html = render_sheet(%{})

      assert html =~ ~s{data-close-event="close-edit"}
      assert html =~ "pushEvent"
      assert html =~ "translateX(100%)"
      assert html =~ "translateY(100%)"
      assert html =~ "duration: 300"
    end

    test "the hook traps Tab and restores focus" do
      html = render_sheet(%{})

      assert html =~ "document.activeElement"
      assert html =~ "last.focus()"
      assert html =~ "first.focus()"
    end
  end

  describe "accessibility" do
    test "the sheet is a dialog labelled by the title" do
      html = render_sheet(%{})

      assert html =~ ~s{role="dialog"}
      assert html =~ ~s{aria-labelledby="edit-profile-title"}
      assert html =~ ~s{aria-describedby="edit-profile-description"}
    end

    test "no aria-describedby without a description" do
      html = render_sheet(%{description: nil})

      refute html =~ "aria-describedby"
    end

    test "the panel is focusable as a fallback" do
      html = render_sheet(%{})

      assert html =~ ~s{tabindex="-1"}
    end
  end

  describe "sheet_section" do
    test "renders the source's padded band" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sheet_section class="pb-0">Inputs</.sheet_section>
        """)

      assert html =~ "data-polaris-sheet-section"
      assert html =~ "px-5 py-4"
      assert html =~ "pb-0"
      assert html =~ "Inputs"
      _ = assigns
    end
  end

  describe "sheet_close" do
    test "renders a button firing the close event" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sheet_close on_close="close-edit">Cancel</.sheet_close>
        """)

      assert html =~ "data-polaris-sheet-close-button"
      assert html =~ ~s{phx-click="close-edit"}
      assert html =~ "Cancel"
      assert html =~ ~s{type="button"}
      assert html =~ "disabled:pointer-events-none disabled:opacity-50"
      _ = assigns
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_sheet(%{rest: %{"data-testid" => "profile-panel"}})

      assert html =~ ~s{data-testid="profile-panel"}
    end

    test "caller classes merge onto the panel" do
      html = render_sheet(%{class: "flex flex-col gap-0"})

      assert html =~ "flex flex-col gap-0"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_sheet(%{body: {:safe, "<p>x</p>"}})

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

  # The hook's JS body, for behavior-level assertions.
  defp script_source(html) do
    [_, after_hook | _] = String.split(html, @hook, parts: 2)
    after_hook
  end
end
