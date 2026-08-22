defmodule PolarisUI.Components.ConfirmationModalTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.ConfirmationModal` —
  anatomy, variants, sizes, states (loading/disabled), slots, hook, and
  accessibility behavior, mirroring the Supabase design system fragment
  `ui-patterns/Dialogs/ConfirmationModal` 1:1: a bordered header over an
  overlay, an optional admonition banner bleeding to full width, a separated
  body section, and a two-button footer where the confirm button mirrors the
  modal variant.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.ConfirmationModal

  @hook "PolarisUI.Components.ConfirmationModal.Modal"

  defp modal(assigns) do
    base = %{
      id: "resume-project",
      open: true,
      title: "Resume this project",
      on_confirm: "resume-project",
      on_cancel: "close-resume"
    }

    assigns = Map.merge(base, assigns)

    rendered_to_string(~H"""
    <.confirmation_modal
      id={@id}
      open={@open}
      title={@title}
      description={assigns[:description]}
      alert_title={assigns[:alert_title]}
      alert_description={assigns[:alert_description]}
      variant={assigns[:variant] || "default"}
      size={assigns[:size] || "small"}
      loading={assigns[:loading] || false}
      disabled={assigns[:disabled] || false}
      confirm_label={assigns[:confirm_label] || "Resume"}
      confirm_label_loading={assigns[:confirm_label_loading]}
      class={assigns[:class]}
      on_confirm={@on_confirm}
      on_cancel={@on_cancel}
    >
      {assigns[:body]}
    </.confirmation_modal>
    """)
  end

  describe "visibility" do
    test "closed by default: only the hook root and script render" do
      html = modal(%{open: false})

      assert html =~ ~s{data-state="closed"}
      # the script body mentions the markers; assert the DOM never renders them
      refute html =~ ~s{<div data-polaris-modal-overlay}
      refute html =~ ~s{<div data-polaris-modal-container}
      refute html =~ ~s{<div data-polaris-modal-panel}
      refute html =~ "Resume this project"
    end

    test "open renders overlay, dialog, and panel" do
      html = modal(%{})

      assert html =~ ~s{data-state="open"}
      assert html =~ "data-polaris-modal-overlay"
      assert html =~ "data-polaris-modal-container"
      assert html =~ "data-polaris-modal-panel"
      assert html =~ "Resume this project"
    end
  end

  describe "anatomy" do
    test "the header carries the title over a bottom border with small padding" do
      html = modal(%{description: "The project will be restored to its previous state."})

      assert html =~ ~s{id="resume-project-title"}
      assert html =~ "max-w-[calc(100%-1rem)] text-base font-normal leading-none"
      assert html =~ "border-b border-surface-border px-4 py-4 md:px-5"
      assert html =~ ~s{id="resume-project-description"}
      assert html =~ "text-sm text-content-secondary"

      # title renders before the footer buttons
      title = position(html, "Resume this project")
      footer = position(html, "data-polaris-modal-footer")
      assert is_integer(title) and is_integer(footer) and title < footer
    end

    test "the header description is optional" do
      html = modal(%{})

      refute html =~ "resume-project-description"
    end

    test "the overlay dims with the theme-invariant scrim token" do
      html = modal(%{})

      assert html =~ "bg-overlay"
      assert html =~ "backdrop-blur-[2px]"
      assert html =~ ~s{aria-hidden="true"}
    end

    test "the panel is a bordered rounded surface with pb-5 and the small width" do
      html = modal(%{})

      panel = panel_class(html)

      assert panel =~ "rounded-lg"
      assert panel =~ "border-surface-border"
      assert panel =~ "bg-surface-panel"
      assert panel =~ "pb-5"
      assert panel =~ "sm:max-w-sm"
    end

    test "a ghost close button sits at the panel's top-right corner" do
      html = modal(%{})

      assert html =~ "absolute right-3.5 top-3.5"
      assert html =~ "opacity-20"
      assert html =~ "hover:opacity-100"
      assert html =~ "sr-only\">Close</span>"
      assert html =~ ~s{phx-click="close-resume"}
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
        html = modal(%{size: size})
        assert html =~ width, "missing #{width} for size #{size}"
      end
    end

    test "rejects an unknown size" do
      assert_raise ArgumentError, ~r/:size/, fn ->
        modal(%{size: "gigantic"})
      end
    end
  end

  describe "alert banner" do
    test "renders the admonition sandwiched under the header when configured" do
      html =
        modal(%{
          alert_title: "This action cannot be undone",
          alert_description: "Paused projects older than 90 days are deleted."
        })

      assert html =~ "data-polaris-modal-alert"
      assert html =~ "This action cannot be undone"
      assert html =~ "Paused projects older than 90 days are deleted."
      # bleeds to full width, tucked under the header border like the fragment
      assert html =~ "rounded-none border-x-0 -mt-px"

      header = position(html, "data-polaris-modal-title")
      alert = position(html, "data-polaris-modal-alert")
      assert is_integer(header) and is_integer(alert) and header < alert
    end

    test "the banner type follows the modal variant" do
      html =
        modal(%{
          variant: "destructive",
          alert_title: "Danger zone",
          alert_description: "Careful."
        })

      assert html =~ ~s{aria-label="Danger"}
      assert html =~ "bg-danger-muted"
      assert html =~ "border-danger-border"
    end

    test "no banner without alert props" do
      html = modal(%{})

      refute html =~ "data-polaris-modal-alert"
    end
  end

  describe "body section" do
    test "renders inside a padded section closed by a 1px separator" do
      html = modal(%{body: {:safe, "<p>Pick the restore point below.</p>"}})

      assert html =~ "Pick the restore point below."
      assert html =~ "data-polaris-modal-body"
      assert html =~ "overflow-hidden px-4 py-4 md:px-5"
      assert html =~ ~s{class="h-px w-full bg-surface-border"}
      assert html =~ "data-polaris-modal-separator"
    end

    test "no body section or separator without body content" do
      html = modal(%{})

      refute html =~ "data-polaris-modal-body"
      refute html =~ "data-polaris-modal-separator"
    end

    test "the class attribute lands on the body section, not the panel" do
      html = modal(%{body: {:safe, "<p>Body.</p>"}, class: "max-h-64 overflow-y-auto"})

      body = body_class(html)
      assert body =~ "max-h-64"
      assert body =~ "overflow-y-auto"

      panel = panel_class(html)
      refute panel =~ "max-h-64"
    end
  end

  describe "footer buttons" do
    test "cancel first, confirm after — both full width at medium size" do
      html = modal(%{})

      cancel = position(html, ~s{phx-click="close-resume"})
      confirm = position(html, ~s{phx-click="resume-project"})
      assert is_integer(cancel) and is_integer(confirm) and cancel < confirm
      assert count(html, "w-full") >= 2
      assert html =~ "flex gap-2 px-5 pt-5"
    end

    test "default variant confirms with the emerald primary button" do
      html = modal(%{})

      assert html =~ "bg-brand-fill"
      assert html =~ "border-brand-border"
    end

    test "destructive variant confirms with the danger button and tints the labels" do
      html = modal(%{variant: "destructive", confirm_label: "Delete project"})

      assert html =~ "bg-danger-fill"
      assert html =~ "border-danger-border"
      assert html =~ "Delete project"
    end

    test "warning variant confirms with the warning button" do
      html = modal(%{variant: "warning"})

      assert html =~ "bg-warning-fill"
      assert html =~ "border-warning-border"
    end

    test "rejects an unknown variant" do
      assert_raise ArgumentError, ~r/:variant/, fn ->
        modal(%{variant: "sassy"})
      end
    end

    test "label defaults follow the fragment" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.confirmation_modal id="m" open title="Are you sure?" />
        """)

      assert html =~ ~r{>\s*Submit\s*</span>}
      assert html =~ ~r{>\s*Cancel\s*</span>}
    end
  end

  describe "states" do
    test "loading spins the confirm button, swaps its label, and locks both buttons" do
      html = modal(%{loading: true, confirm_label_loading: "Resuming"})

      assert html =~ "data-polaris-spinner"
      assert html =~ ~s{aria-busy="true"}
      assert html =~ "Resuming"
      refute html =~ ~r{>\s*Resume\s*</span>}
      # cancel disables while loading; confirm locks via its own loading path
      assert html =~ " disabled"
      assert html =~ "pointer-events-none"
    end

    test "loading without a loading label keeps the confirm label" do
      html = modal(%{loading: true})

      assert html =~ ~r{>\s*Resume\s*</span>}
    end

    test "disabled locks the confirm button only" do
      html = modal(%{disabled: true})

      assert html =~ " disabled"
      refute html =~ "data-polaris-spinner"
    end

    test "the footer buttons carry hover and focus-ring states" do
      html = modal(%{})

      assert html =~ "focus-visible:ring-2"
      assert html =~ "hover:bg-brand-fill-hover"
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = modal(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook exposes the cancel event and wires dismiss + focus behavior" do
      html = modal(%{})

      assert html =~ ~s{data-cancel-event="close-resume"}
      assert html =~ "pushEvent"
      assert html =~ "Escape"
      assert html =~ "preventDefault"
      # focus trap: cycle + initial focus + restore + scroll lock
      assert html =~ "document.activeElement"
      assert html =~ "last.focus()"
      assert html =~ "first.focus()"
      assert html =~ ~s{document.body.style.overflow = "hidden"}
      assert html =~ "previouslyFocused"
    end

    test "the outside-click path cancels only when the panel is not hit" do
      html = modal(%{})

      assert html =~ "data-polaris-modal-container"
      assert html =~ "panel.contains(event.target)"
    end
  end

  describe "accessibility" do
    test "the dialog is a labelled modal region" do
      html = modal(%{description: "The project will be restored."})

      assert html =~ ~s{role="dialog"}
      assert html =~ ~s{aria-modal="true"}
      assert html =~ ~s{aria-labelledby="resume-project-title"}
      assert html =~ ~s{aria-describedby="resume-project-description"}
    end

    test "no aria-describedby without a description" do
      html = modal(%{})

      refute html =~ "aria-describedby"
    end

    test "the panel is focusable as a fallback for the initial focus" do
      html = modal(%{})

      assert html =~ ~s{tabindex="-1"}
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.confirmation_modal id="m" open title="T" data-testid="confirm-dialog" />
        """)

      assert html =~ ~s{data-testid="confirm-dialog"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html =
        modal(%{alert_title: "A", alert_description: "B", body: {:safe, "C"}, variant: "warning"})

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
  # always precedes the element's own class= in the rendered output).
  defp marker_class(html, marker) do
    [_, after_marker | _] = String.split(html, marker, parts: 2)

    class =
      case :binary.match(after_marker, ~s{class="}) do
        {index, _} -> binary_part(after_marker, index + 7, byte_size(after_marker) - index - 7)
        :nomatch -> ""
      end

    class |> String.split(~s{"}) |> List.first()
  end

  defp panel_class(html), do: marker_class(html, "data-polaris-modal-panel")
  defp body_class(html), do: marker_class(html, "data-polaris-modal-body")
end
