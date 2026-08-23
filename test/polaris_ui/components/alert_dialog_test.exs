defmodule PolarisUI.Components.AlertDialogTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.AlertDialog` — the
  port of the Supabase design system AlertDialog (Radix primitive): a
  critical-confirmation modal that cannot be dismissed from outside, with
  a bordered title bar, single-paragraph description, flattened alert
  body, and a cancel-first footer of tiny buttons.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.AlertDialog

  @hook "PolarisUI.Components.AlertDialog.Dialog"

  defp render_dialog(assigns) do
    assigns =
      Map.merge(
        %{
          id: "delete-fn",
          open: true,
          title: "Delete hello-world?",
          description: "This action cannot be undone.",
          variant: "default",
          size: "small",
          loading: false,
          disabled: false,
          action_label: "Delete",
          action_label_loading: nil,
          cancel_label: "Cancel",
          on_confirm: "delete-fn",
          on_cancel: "close-delete",
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.alert_dialog
      id={@id}
      open={@open}
      title={@title}
      description={@description}
      variant={@variant}
      size={@size}
      loading={@loading}
      disabled={@disabled}
      action_label={@action_label}
      action_label_loading={@action_label_loading}
      cancel_label={@cancel_label}
      on_confirm={@on_confirm}
      on_cancel={@on_cancel}
      class={@class}
      {assigns[:rest]}
    >
      {assigns[:body]}
    </.alert_dialog>
    """)
  end

  describe "visibility" do
    test "closed by default: only the hook root and script render" do
      html = render_dialog(%{open: false})

      assert html =~ ~s{data-state="closed"}
      refute html =~ "<div data-polaris-alert-dialog-overlay"
      refute html =~ "<div data-polaris-alert-dialog-container"
      refute html =~ "<div data-polaris-alert-dialog-panel"
      refute html =~ "Delete hello-world?"
    end

    test "open renders overlay, alertdialog, and panel" do
      html = render_dialog(%{})

      assert html =~ ~s{data-state="open"}
      assert html =~ "data-polaris-alert-dialog-overlay"
      assert html =~ "data-polaris-alert-dialog-container"
      assert html =~ "data-polaris-alert-dialog-panel"
      assert html =~ "Delete hello-world?"
    end
  end

  describe "anatomy" do
    test "the title is a full-bleed header bar over its own border" do
      html = render_dialog(%{})

      assert html =~ ~s{id="delete-fn-title"}
      assert html =~ "border-b border-surface-border px-5 py-3 text-base"
      assert html =~ "data-polaris-alert-dialog-title"
    end

    test "the description is a single padded paragraph" do
      html = render_dialog(%{})

      assert html =~ ~s{id="delete-fn-description"}
      assert html =~ "px-5 pb-4 pt-3.5 text-sm text-content-secondary"
      assert html =~ "This action cannot be undone."
    end

    test "the description is optional" do
      html = render_dialog(%{description: nil})

      refute html =~ "delete-fn-description"
    end

    test "there is no close ✕ button — unlike the confirmation modal" do
      html = render_dialog(%{})

      refute html =~ ~s{aria-label="Close"}
    end

    test "the overlay dims with the theme-invariant scrim" do
      html = render_dialog(%{})

      assert html =~ "bg-overlay"
      assert html =~ "backdrop-blur-xs"
      assert html =~ ~s{aria-hidden="true"}
    end

    test "the panel is a bordered rounded surface at the small width" do
      html = render_dialog(%{})

      panel = marker_class(html, "data-polaris-alert-dialog-panel")
      assert panel =~ "border shadow-md sm:rounded-lg"
      assert panel =~ "bg-surface-panel"
      assert panel =~ "sm:max-w-sm"
      assert panel =~ "relative z-50 w-full"
    end

    test "the body flattens a full-bleed alert child" do
      html = render_dialog(%{body: {:safe, ~s{<div role="alert">Failed</div>}}})

      body = marker_class(html, "data-polaris-alert-dialog-body")
      assert body =~ "[&>[role=alert]]:mb-0"
      assert body =~ "[&>[role=alert]]:rounded-none [&>[role=alert]]:border-x-0"
      assert html =~ "Failed"
    end

    test "no body section without body content" do
      html = render_dialog(%{})

      # the footer's :has() selector mentions the marker — match the div itself
      refute html =~ ~s{<div data-polaris-alert-dialog-body}
    end
  end

  describe "footer buttons" do
    test "cancel first, action after — tiny buttons over a top border" do
      html = render_dialog(%{})

      cancel = position(html, ~s{phx-click="close-delete"})
      action = position(html, ~s{phx-click="delete-fn"})
      assert is_integer(cancel) and is_integer(action) and cancel < action

      footer = marker_class(html, "data-polaris-alert-dialog-footer")
      assert footer =~ "flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2"
      assert footer =~ "border-t border-surface-border py-3 px-5"

      assert html =~ "h-[26px]"
      assert html =~ "text-xs"
    end

    test "an alert in the body owns the footer separator (the :has selector)" do
      html = render_dialog(%{body: {:safe, ~s{<div role="alert">Failed</div>}}})

      footer = marker_class(html, "data-polaris-alert-dialog-footer")
      assert footer =~ "has(>[role=alert])+&]:border-t-0"
    end

    test "default variant confirms with the emerald primary button" do
      html = render_dialog(%{})

      assert html =~ "bg-brand-fill"
      assert html =~ "border-brand-border"
    end

    test "destructive variant confirms with the danger button" do
      html = render_dialog(%{variant: "destructive"})

      assert html =~ "bg-danger-fill"
      assert html =~ "border-danger-border"
    end

    test "warning variant confirms with the warning button" do
      html = render_dialog(%{variant: "warning"})

      assert html =~ "bg-warning-fill"
      assert html =~ "border-warning-border"
    end

    test "rejects an unknown variant" do
      assert_raise ArgumentError, ~r/:variant/, fn ->
        render_dialog(%{variant: "sassy"})
      end
    end

    test "rejects an unknown size" do
      assert_raise ArgumentError, ~r/:size/, fn ->
        render_dialog(%{size: "gigantic"})
      end
    end

    test "omitting action_label renders the close-only acknowledgement" do
      html = render_dialog(%{action_label: nil, cancel_label: "Close"})

      refute html =~ ~s{phx-click="delete-fn"}
      assert html =~ ~r{>\s*Close\s*</span>}
      assert count(html, "<button") == 1
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
  end

  describe "states" do
    test "loading spins the action, swaps to the gerund, and locks both buttons" do
      html = render_dialog(%{loading: true, action_label_loading: "Deleting"})

      assert html =~ "data-polaris-spinner"
      assert html =~ ~s{aria-busy="true"}
      assert html =~ "Deleting"
      refute html =~ ~r{>\s*Delete\s*</span>}
      assert html =~ " disabled"
      assert html =~ "pointer-events-none"
    end

    test "loading without a loading label keeps the action label" do
      html = render_dialog(%{loading: true})

      assert html =~ ~r{>\s*Delete\s*</span>}
    end

    test "disabled locks the action button only" do
      html = render_dialog(%{disabled: true})

      assert html =~ " disabled"
      refute html =~ "data-polaris-spinner"
    end

    test "the footer buttons carry hover and focus-ring states" do
      html = render_dialog(%{})

      assert html =~ "focus-visible:ring-2"
      assert html =~ "hover:bg-surface-panel-hover"
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

    test "the hook exposes the cancel event and answers Escape" do
      html = render_dialog(%{})

      assert html =~ ~s{data-cancel-event="close-delete"}
      assert html =~ "pushEvent"
      assert html =~ "Escape"
      assert html =~ "preventDefault"
    end

    test "a pending action blocks Escape dismissal" do
      html = render_dialog(%{})

      assert html =~ ~s{data-loading="false"}
      assert html =~ ~s{root.dataset.loading === "true"}
    end

    test "there is no outside-click dismissal path" do
      html = render_dialog(%{})

      refute html =~ "addEventListener(\"click\""
    end

    test "initial focus lands on the cancel button" do
      html = render_dialog(%{})

      assert html =~ "querySelector(\"[data-polaris-alert-dialog-cancel]\")"
    end

    test "the hook traps Tab, restores focus, and locks scroll" do
      html = render_dialog(%{})

      assert html =~ "document.activeElement"
      assert html =~ "last.focus()"
      assert html =~ "first.focus()"
      assert html =~ ~s{document.body.style.overflow = "hidden"}
      assert html =~ "previouslyFocused"
    end
  end

  describe "accessibility" do
    test "the dialog is an alertdialog region labelled by the title" do
      html = render_dialog(%{})

      assert html =~ ~s{role="alertdialog"}
      assert html =~ ~s{aria-modal="true"}
      assert html =~ ~s{aria-labelledby="delete-fn-title"}
      assert html =~ ~s{aria-describedby="delete-fn-description"}
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

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_dialog(%{rest: %{"data-testid" => "confirm-delete"}})

      assert html =~ ~s{data-testid="confirm-delete"}
    end

    test "caller classes merge onto the panel" do
      html = render_dialog(%{class: "max-h-80 overflow-y-auto"})

      panel = marker_class(html, "data-polaris-alert-dialog-panel")
      assert panel =~ "max-h-80"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_dialog(%{body: {:safe, "<div role=\"alert\">x</div>"}, variant: "warning"})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  # First byte offset of `pattern` in `html`, or nil — for ordering checks.
  defp position(html, pattern) do
    case :binary.match(html, pattern) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  # The class attribute of the element carrying the given marker (the marker
  # precedes the element's own class= in the rendered output).
  defp marker_class(html, marker) do
    [_, after_marker | _] = String.split(html, marker, parts: 2)

    class =
      case :binary.match(after_marker, ~s{class="}) do
        {index, _} -> binary_part(after_marker, index + 7, byte_size(after_marker) - index - 7)
        :nomatch -> ""
      end

    class |> String.split(~s{"}) |> List.first() |> unescape()
  end

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
