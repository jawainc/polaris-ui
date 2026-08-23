defmodule PolarisUI.Components.DialogTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Dialog` — the port of
  the Supabase design system Dialog (Radix primitive): the generic,
  dismissible modal with a header/body/footer anatomy, size ladder, and
  padding variants.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Dialog

  @hook "PolarisUI.Components.Dialog.Dialog"

  defp render_dialog(assigns) do
    assigns =
      Map.merge(
        %{
          id: "edit-profile",
          open: true,
          title: "Edit profile",
          description: "Make changes to your profile here.",
          on_close: "close-edit",
          size: "medium",
          padding: "small",
          centered: true,
          hide_close: false,
          class: nil,
          rest: %{},
          body: nil,
          footer: nil
        },
        assigns
      )

    rendered_to_string(~H"""
    <.dialog
      id={@id}
      open={@open}
      title={@title}
      description={@description}
      on_close={@on_close}
      size={@size}
      padding={@padding}
      centered={@centered}
      hide_close={@hide_close}
      class={@class}
      {assigns[:rest]}
    >
      {assigns[:body]}
      <:footer :if={assigns[:footer]}>{assigns[:footer]}</:footer>
    </.dialog>
    """)
  end

  describe "visibility" do
    test "closed by default: only the hook root and script render" do
      html = render_dialog(%{open: false})

      assert html =~ ~s{data-state="closed"}
      refute html =~ "<div data-polaris-dialog-overlay"
      refute html =~ "<div data-polaris-dialog-container"
      refute html =~ "<div data-polaris-dialog-panel"
      refute html =~ "Edit profile"
    end

    test "open renders overlay, dialog, and panel" do
      html = render_dialog(%{})

      assert html =~ ~s{data-state="open"}
      assert html =~ "data-polaris-dialog-overlay"
      assert html =~ "data-polaris-dialog-container"
      assert html =~ "data-polaris-dialog-panel"
      assert html =~ "Edit profile"
    end
  end

  describe "anatomy" do
    test "the header stacks title and description left-aligned from sm: up" do
      html = render_dialog(%{})

      header = marker_class(html, "data-polaris-dialog-header")
      assert header =~ "flex flex-col gap-1.5 text-center sm:text-left"
      assert header =~ "py-4 px-4 md:px-5"
    end

    test "the title is the source's DialogTitle — normal weight, close-button room" do
      html = render_dialog(%{})

      assert html =~ ~s{id="edit-profile-title"}
      assert html =~ "text-base leading-none font-normal max-w-[calc(100%-1.5rem)]"
      assert html =~ "data-polaris-dialog-title"
    end

    test "the description is the muted single sentence" do
      html = render_dialog(%{})

      assert html =~ ~s{id="edit-profile-description"}
      assert html =~ "text-sm text-content-secondary"
      assert html =~ "Make changes to your profile here."
    end

    test "the description is optional" do
      html = render_dialog(%{description: nil})

      refute html =~ "edit-profile-description"
    end

    test "the footer is right-aligned from sm:, stacked on mobile, over a border" do
      html = render_dialog(%{footer: {:safe, "<button type=\"button\">Save changes</button>"}})

      footer = marker_class(html, "data-polaris-dialog-footer")
      assert footer =~ "flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2"
      assert footer =~ "border-t border-surface-border"
      assert footer =~ "py-4 px-4 md:px-5"
    end

    test "no footer section without footer content" do
      html = render_dialog(%{})

      refute html =~ ~s{<div data-polaris-dialog-footer}
    end

    test "the body renders inner content" do
      html = render_dialog(%{body: {:safe, "<p>Name field</p>"}})

      assert html =~ "data-polaris-dialog-body"
      assert html =~ "Name field"
    end

    test "the panel is a bordered rounded surface" do
      html = render_dialog(%{})

      assert html =~ "relative z-50 w-full border shadow-md sm:rounded-lg"
      assert html =~ "bg-surface-panel text-content-primary"
    end

    test "centered panels sit mid-viewport; centered=false anchors top" do
      assert render_dialog(%{}) =~ "grid place-items-center"

      top = render_dialog(%{centered: false})
      assert top =~ "flex flex-col justify-start"
      assert top =~ "sm:pt-12 md:pt-20 lg:pt-32 xl:pt-40"
    end
  end

  describe "close button" do
    test "the ✕ sits top-right, dimmed until hover, firing on_close" do
      html = render_dialog(%{})

      assert html =~ "data-polaris-dialog-close"
      assert html =~ ~s{aria-label="Close"}
      assert html =~ ~s{phx-click="close-edit"}
      assert html =~ "absolute p-0.5 right-3.5 top-3.5 rounded-xs opacity-20 transition-opacity"
      assert html =~ "hover:opacity-100"
    end

    test "hide_close drops the ✕" do
      html = render_dialog(%{hide_close: true})

      refute html =~ "data-polaris-dialog-close"
    end

    test "unlike the alert dialog, there is a dismiss path besides the buttons" do
      html = render_dialog(%{})

      assert html =~ "aria-label=\"Close\""
    end
  end

  describe "sizes" do
    test "maps every Supabase dialog width" do
      widths = %{
        "tiny" => "sm:max-w-xs",
        "small" => "sm:max-w-sm",
        "medium" => "sm:max-w-lg",
        "large" => "md:max-w-xl",
        "xlarge" => "md:max-w-3xl",
        "xxlarge" => "md:max-w-6xl",
        "xxxlarge" => "md:max-w-7xl"
      }

      for {size, width} <- widths do
        html = render_dialog(%{size: size})
        assert html =~ width, "missing #{width} for size #{size}"
      end
    end

    test "the default is the source's medium" do
      html = render_dialog(%{})

      assert html =~ "sm:max-w-lg"
    end

    test "rejects an unknown size" do
      assert_raise ArgumentError, ~r/:size/, fn ->
        render_dialog(%{size: "gigantic"})
      end
    end
  end

  describe "padding variants" do
    test "medium widens the header/footer rhythm" do
      html = render_dialog(%{padding: "medium", footer: {:safe, "x"}})

      assert html =~ "py-6 px-4 md:px-7"
      refute html =~ "py-4 px-4 md:px-5"
    end

    test "rejects an unknown padding" do
      assert_raise ArgumentError, ~r/:padding/, fn ->
        render_dialog(%{padding: "roomy"})
      end
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_dialog(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook exposes the close event and answers Escape" do
      html = render_dialog(%{})

      assert html =~ ~s{data-close-event="close-edit"}
      assert html =~ "pushEvent"
      assert html =~ "Escape"
      assert html =~ "preventDefault"
    end

    test "unlike the alert dialog, an overlay click dismisses" do
      html = render_dialog(%{})

      assert html =~ "addEventListener(\"click\", this._onOverlayClick)"
      assert html =~ "event.target === overlay"
    end

    test "the hook traps Tab, focuses the first focusable, restores focus, and locks scroll" do
      html = render_dialog(%{})

      assert html =~ "document.activeElement"
      assert html =~ "last.focus()"
      assert html =~ "first.focus()"
      assert html =~ ~s{document.body.style.overflow = "hidden"}
      assert html =~ "previouslyFocused"
    end
  end

  describe "accessibility" do
    test "the dialog is a modal region labelled by the title" do
      html = render_dialog(%{})

      assert html =~ ~s{role="dialog"}
      assert html =~ ~s{aria-modal="true"}
      assert html =~ ~s{aria-labelledby="edit-profile-title"}
      assert html =~ ~s{aria-describedby="edit-profile-description"}
    end

    test "no aria-describedby without a description" do
      html = render_dialog(%{description: nil})

      refute html =~ "aria-describedby"
    end

    test "the panel is focusable as a fallback" do
      html = render_dialog(%{})

      assert html =~ ~s{tabindex="-1"}
    end
  end

  describe "sections" do
    test "dialog_section carries the padding variant and clips overflow" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dialog_section>Body</.dialog_section>
        """)

      assert html =~ "data-polaris-dialog-section"
      assert html =~ "overflow-hidden py-4 px-4 md:px-5"
    end

    test "dialog_section_separator renders the hairline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dialog_section_separator />
        """)

      assert html =~ "data-polaris-dialog-section-separator"
      assert html =~ "w-full h-px bg-surface-border"
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_dialog(%{rest: %{"data-testid" => "edit-dialog"}})

      assert html =~ ~s{data-testid="edit-dialog"}
    end

    test "caller classes merge onto the panel" do
      html = render_dialog(%{class: "max-h-80 overflow-y-auto"})

      assert html =~ "max-h-80"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_dialog(%{body: {:safe, "<p>x</p>"}, padding: "medium"})

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
