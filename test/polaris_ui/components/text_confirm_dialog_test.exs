defmodule PolarisUI.Components.TextConfirmDialogTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.TextConfirmDialog` —
  anatomy, the typed-intent validation flow, variants, sizes, states,
  copy interaction, slots, hook, and accessibility behavior, mirroring
  the Supabase design system fragment `ui-patterns/Dialogs/TextConfirmModal`
  1:1: a bordered header over an overlay (no ghost close button — the
  source has none), an optional admonition banner bleeding to full width,
  separated body sections, and a typed-confirmation form whose button row
  lives inside the form element with the confirm disabled until the typed
  draft trims to a match.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.TextConfirmDialog

  @hook "PolarisUI.Components.TextConfirmDialog.Modal"

  defp dialog(assigns) do
    base = %{
      id: "delete-bucket",
      open: true,
      title: "Delete bucket",
      confirm_string: "profile-pictures",
      confirm_placeholder: "profile-pictures",
      on_confirm: "delete-bucket",
      on_cancel: "close-delete"
    }

    assigns = Map.merge(base, assigns)

    rendered_to_string(~H"""
    <.text_confirm_dialog
      id={@id}
      open={@open}
      title={@title}
      confirm_string={@confirm_string}
      confirm_placeholder={@confirm_placeholder}
      confirm_value={assigns[:confirm_value] || ""}
      on_change={assigns[:on_change]}
      on_confirm={@on_confirm}
      on_cancel={@on_cancel}
      text={assigns[:text]}
      alert_title={assigns[:alert_title]}
      alert_description={assigns[:alert_description]}
      variant={assigns[:variant] || "default"}
      size={assigns[:size] || "small"}
      loading={assigns[:loading] || false}
      confirm_label={assigns[:confirm_label] || "Delete bucket"}
      cancel_label={assigns[:cancel_label] || "Cancel"}
      block_cancel_button={Map.get(assigns, :block_cancel_button, true)}
      mismatch_error={assigns[:mismatch_error] || "Value entered does not match"}
      enable_copy={assigns[:enable_copy] || false}
      description={assigns[:description]}
      class={assigns[:class]}
    >
      {assigns[:body]}
    </.text_confirm_dialog>
    """)
  end

  describe "visibility" do
    test "closed by default: only the hook root and script render" do
      html = dialog(%{open: false})

      assert html =~ ~s{data-state="closed"}
      # the script body mentions the markers; assert the DOM never renders them
      refute html =~ ~s{<div data-polaris-tcd-overlay}
      refute html =~ ~s{<div data-polaris-tcd-container}
      refute html =~ ~s{<div data-polaris-tcd-panel}
      refute html =~ "Delete bucket"
    end

    test "open renders overlay, dialog, and panel" do
      html = dialog(%{})

      assert html =~ ~s{data-state="open"}
      assert html =~ "data-polaris-tcd-overlay"
      assert html =~ "data-polaris-tcd-container"
      assert html =~ "data-polaris-tcd-panel"
      assert html =~ "Delete bucket"
    end
  end

  describe "anatomy" do
    test "the header carries the title over a bottom border" do
      html = dialog(%{})

      assert html =~ ~s{id="delete-bucket-title"}
      assert html =~ "max-w-[calc(100%-1rem)] text-base font-normal leading-none"
      assert html =~ "border-b border-surface-border px-4 py-4 md:px-5"

      # title renders before the form footer
      title = position(html, "data-polaris-tcd-title")
      footer = position(html, "data-polaris-tcd-footer")
      assert is_integer(title) and is_integer(footer) and title < footer
    end

    test "the overlay dims with the theme-invariant scrim token" do
      html = dialog(%{})

      assert html =~ "bg-overlay"
      assert html =~ "backdrop-blur-[2px]"
      assert html =~ ~s{aria-hidden="true"}
    end

    test "the panel is a bordered rounded surface with pb-5 and the small width" do
      html = dialog(%{})

      panel = panel_class(html)

      assert panel =~ "rounded-lg"
      assert panel =~ "border-surface-border"
      assert panel =~ "bg-surface-panel"
      assert panel =~ "pb-5"
      assert panel =~ "sm:max-w-sm"
    end

    test "no ghost close button — the fragment has none" do
      html = dialog(%{})

      refute html =~ "absolute right-3.5 top-3.5"
      refute html =~ ~s{aria-label="Close"}
    end

    test "the form wraps label, input, and the button row inside it" do
      html = dialog(%{})

      assert html =~ "data-polaris-tcd-form"
      assert html =~ ~s{autocomplete="off"}
      assert html =~ ~s{phx-submit="delete-bucket"}
      assert html =~ "px-5 flex flex-col gap-y-3 pt-3"
      assert html =~ "flex flex-col gap-y-2"

      # the footer button row is the last child of the form, like the fragment
      form = position(html, "<form")
      footer = position(html, "data-polaris-tcd-footer")
      form_close = position(html, "</form>")
      assert is_integer(form) and is_integer(footer) and is_integer(form_close)
      assert form < footer and footer < form_close
    end

    test "the label ports the sentence: Type <confirm string> to confirm." do
      html = dialog(%{})

      assert html =~ "data-polaris-tcd-label"
      assert html =~ ~s{id="delete-bucket-label"}

      typed = position(html, "Type")
      string = position(html, "profile-pictures")
      confirm = position(html, "to confirm.")
      assert is_integer(typed) and is_integer(string) and is_integer(confirm)
      assert typed < string and string < confirm
    end

    test "the confirm string renders as a selectable span by default" do
      html = dialog(%{})

      assert html =~ ~s{class="text-content-primary break-all whitespace-pre"}
      # the hook script mentions the marker; the DOM must not carry the button
      refute html =~ "data-copy-value"
    end

    test "the input carries the draft contract: id/name, placeholder, no autocomplete" do
      html = dialog(%{confirm_value: "profile"})

      assert html =~ ~s{id="delete-bucket-confirm-value"}
      assert html =~ ~s{name="delete-bucket-confirm-value"}
      assert html =~ ~s{placeholder="profile-pictures"}
      assert html =~ ~s{value="profile"}
      assert html =~ "data-polaris-tcd-input"

      input = marker_class(html, "data-polaris-tcd-input")
      assert input =~ "rounded-md"
      assert input =~ "focus:ring-2 focus:ring-brand-emerald"
    end
  end

  describe "alert banner" do
    test "renders the admonition sandwiched under the header when configured" do
      html =
        dialog(%{
          alert_title: "This action cannot be undone",
          alert_description: "The bucket and all of its contents will be removed."
        })

      assert html =~ "data-polaris-tcd-alert"
      assert html =~ "This action cannot be undone"
      assert html =~ "The bucket and all of its contents will be removed."
      # bleeds to full width, tucked under the header border like the fragment
      assert html =~ "rounded-none border-x-0 -mt-px"

      header = position(html, "data-polaris-tcd-title")
      alert = position(html, "data-polaris-tcd-alert")
      assert is_integer(header) and is_integer(alert) and header < alert
    end

    test "the banner type follows the dialog variant" do
      html =
        dialog(%{
          variant: "destructive",
          alert_title: "Danger zone",
          alert_description: "Careful."
        })

      assert html =~ ~s{aria-label="Danger"}
      assert html =~ "bg-danger-muted"
      assert html =~ "border-danger-border"
    end

    test "no banner without alert props" do
      html = dialog(%{})

      refute html =~ "data-polaris-tcd-alert"
    end
  end

  describe "body sections" do
    test "the inner block renders inside a padded section closed by a 1px separator" do
      html = dialog(%{body: {:safe, "<p>The bucket holds 1,204 objects.</p>"}})

      assert html =~ "The bucket holds 1,204 objects."
      assert html =~ "data-polaris-tcd-body"
      assert html =~ "overflow-hidden px-4 py-4 md:px-5"
      assert html =~ ~s{class="h-px w-full bg-surface-border"}
      assert html =~ "data-polaris-tcd-separator"
    end

    test "the older text prop renders as its own separated paragraph section" do
      html = dialog(%{text: "This is a permanent action."})

      assert html =~ "This is a permanent action."
      assert html =~ ~s{class="text-sm text-content-secondary"}
      assert count(html, "data-polaris-tcd-body") == 1
      assert count(html, "data-polaris-tcd-separator") == 1
    end

    test "inner block and text may both render, each with its own separator" do
      html = dialog(%{body: {:safe, "<p>Body.</p>"}, text: "This is a permanent action."})

      assert html =~ "Body."
      assert html =~ "This is a permanent action."
      assert count(html, "data-polaris-tcd-separator") == 2

      inner = position(html, "Body.")
      text = position(html, "This is a permanent action.")
      assert is_integer(inner) and is_integer(text) and inner < text
    end

    test "no body sections or separators without body content" do
      html = dialog(%{})

      refute html =~ "data-polaris-tcd-body"
      refute html =~ "data-polaris-tcd-separator"
    end

    test "the class attribute lands on the inner-block body section, not the panel" do
      html = dialog(%{body: {:safe, "<p>Body.</p>"}, class: "max-h-64 overflow-y-auto"})

      body = body_class(html)
      assert body =~ "max-h-64"
      assert body =~ "overflow-y-auto"

      panel = panel_class(html)
      refute panel =~ "max-h-64"
    end
  end

  describe "validation flow" do
    test "a non-empty unmatched draft shows the mismatch error and disables confirm" do
      html = dialog(%{confirm_value: "profile-pictures-2"})

      assert html =~ "data-polaris-tcd-error"
      assert html =~ "Value entered does not match"
      assert html =~ ~s{id="delete-bucket-error"}
      assert html =~ " disabled"
    end

    test "a matching draft clears the error and enables confirm" do
      html = dialog(%{confirm_value: "profile-pictures"})

      refute html =~ "data-polaris-tcd-error"
      refute html =~ "Value entered does not match"
      refute html =~ " disabled"
    end

    test "both sides are trimmed before comparing, like the zod preprocess" do
      html = dialog(%{confirm_value: "  profile-pictures  "})
      refute html =~ " disabled"

      html = dialog(%{confirm_string: " profile-pictures ", confirm_value: "profile-pictures"})
      refute html =~ " disabled"
      refute html =~ "data-polaris-tcd-error"
    end

    test "an empty draft disables confirm without showing the error" do
      html = dialog(%{confirm_value: ""})

      refute html =~ "data-polaris-tcd-error"
      assert html =~ " disabled"
    end

    test "a custom mismatch_error overrides the default message" do
      html = dialog(%{confirm_value: "nope", mismatch_error: "The bucket name does not match"})

      assert html =~ "The bucket name does not match"
      refute html =~ "Value entered does not match"
    end
  end

  describe "footer buttons" do
    test "block_cancel_button (the default) hides cancel for a single full-width confirm" do
      html = dialog(%{})

      refute html =~ "Cancel"
      refute html =~ ~s{phx-click="close-delete"}
      # a single full-width confirm button — nothing else in the footer
      assert count(html, ~s{type="submit"}) == 1
      refute html =~ ~s{<button type="button"}
    end

    test "block_cancel_button=false renders cancel before the confirm, side by side" do
      html = dialog(%{block_cancel_button: false})

      cancel = position(html, ~s{phx-click="close-delete"})
      confirm = position(html, ~s{type="submit"})
      assert is_integer(cancel) and is_integer(confirm) and cancel < confirm
      assert count(html, "w-full") >= 2
      assert html =~ "Cancel"
      assert html =~ "Delete bucket"
    end

    test "default variant confirms with the emerald primary button" do
      html = dialog(%{})

      assert html =~ "bg-brand-fill"
      assert html =~ "border-brand-border"
    end

    test "destructive variant confirms with the danger button" do
      html = dialog(%{variant: "destructive"})

      assert html =~ "bg-danger-fill"
      assert html =~ "border-danger-border"
    end

    test "warning variant confirms with the warning button" do
      html = dialog(%{variant: "warning"})

      assert html =~ "bg-warning-fill"
      assert html =~ "border-warning-border"
    end

    test "rejects an unknown variant" do
      assert_raise ArgumentError, ~r/:variant/, fn ->
        dialog(%{variant: "sassy"})
      end
    end

    test "label defaults follow the fragment" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.text_confirm_dialog
          id="m"
          open
          title="Are you sure?"
          confirm_string="x"
          confirm_placeholder="x"
          block_cancel_button={false}
        />
        """)

      assert html =~ ~r{>\s*Submit\s*</span>}
      assert html =~ ~r{>\s*Cancel\s*</span>}
    end

    test "labels can be overridden" do
      html =
        dialog(%{
          block_cancel_button: false,
          confirm_label: "Delete bucket",
          cancel_label: "Keep bucket"
        })

      assert html =~ "Delete bucket"
      assert html =~ "Keep bucket"
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
        html = dialog(%{size: size})
        assert html =~ width, "missing #{width} for size #{size}"
      end
    end

    test "rejects an unknown size" do
      assert_raise ArgumentError, ~r/:size/, fn ->
        dialog(%{size: "gigantic"})
      end
    end
  end

  describe "states" do
    test "loading spins the confirm button and locks both buttons" do
      html =
        dialog(%{loading: true, confirm_value: "profile-pictures", block_cancel_button: false})

      assert html =~ "data-polaris-spinner"
      assert html =~ ~s{aria-busy="true"}
      assert count(html, " disabled") >= 2
      assert html =~ "pointer-events-none"
    end

    test "the unmatched state disables confirm without a spinner" do
      html = dialog(%{confirm_value: "wrong"})

      assert html =~ " disabled"
      refute html =~ "data-polaris-spinner"
    end

    test "the input never disables, even while loading" do
      html = dialog(%{loading: true})
      input = marker_class(html, "data-polaris-tcd-input")
      refute input =~ "disabled"
    end

    test "the input and footer buttons carry hover and focus-ring states" do
      html = dialog(%{block_cancel_button: false})

      assert html =~ "focus-visible:ring-2"
      assert html =~ "hover:bg-brand-fill-hover"
      input = marker_class(html, "data-polaris-tcd-input")
      assert input =~ "hover:border-surface-border-hover"
      assert input =~ "focus:ring-offset-2 focus:ring-offset-surface-ground"
    end
  end

  describe "enable_copy" do
    test "renders the confirm string as a small copy button with both toggle icons" do
      html = dialog(%{enable_copy: true})

      assert html =~ "data-polaris-tcd-copy"
      assert html =~ ~s{data-copy-value="profile-pictures"}
      assert html =~ ~s{data-copied="false"}

      button = marker_class(html, "data-polaris-tcd-copy")
      assert button =~ "h-[23px]"
      assert button =~ "px-1.5 py-0"
      assert button =~ "whitespace-pre break-all"

      # Copy icon hides while copied; Check icon (brand-tinted) shows while copied
      assert html =~ "group-data-[copied=true]:hidden"
      assert html =~ "group-data-[copied=true]:block"
      assert html =~ "text-brand-accent"
    end

    test "without enable_copy the string stays a selectable span" do
      html = dialog(%{enable_copy: false})

      # the hook script mentions the marker; the DOM must not carry the button
      refute html =~ "data-copy-value"
      assert html =~ ~s{class="text-content-primary break-all whitespace-pre"}
    end
  end

  describe "events" do
    test "input edits push on_change under the derived name key" do
      html = dialog(%{on_change: "delete-draft-change"})

      assert html =~ ~s{phx-change="delete-draft-change"}
      assert html =~ ~s{name="delete-bucket-confirm-value"}
    end

    test "confirm submits the form; cancel clicks its own event" do
      html = dialog(%{block_cancel_button: false})

      assert html =~ ~s{phx-submit="delete-bucket"}
      assert html =~ ~s{phx-click="close-delete"}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = dialog(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook exposes the cancel event and wires dismiss + focus behavior" do
      html = dialog(%{})

      assert html =~ ~s{data-cancel-event="close-delete"}
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
      html = dialog(%{})

      assert html =~ "data-polaris-tcd-container"
      assert html =~ "panel.contains(event.target)"
    end

    test "the hook copies the confirm string and resets the copied state" do
      html = dialog(%{enable_copy: true})

      assert html =~ "navigator.clipboard.writeText"
      assert html =~ "dataset.copyValue"
      assert html =~ ~s{setAttribute("data-copied", "true")}
      assert html =~ "2000"
      assert html =~ "clearTimeout"
      assert html =~ "removeEventListener"
    end
  end

  describe "accessibility" do
    test "the dialog is a labelled modal region" do
      html = dialog(%{})

      assert html =~ ~s{role="dialog"}
      assert html =~ ~s{aria-modal="true"}
      assert html =~ ~s{aria-labelledby="delete-bucket-title"}
    end

    test "the input is named by the label sentence" do
      html = dialog(%{})

      assert html =~ ~s{<label for="delete-bucket-confirm-value"}
      assert html =~ ~s{aria-labelledby="delete-bucket-label"}
    end

    test "aria-describedby joins the hint and the mismatch error when present" do
      html =
        dialog(%{
          description: "You'll find it on the bucket settings page.",
          confirm_value: "wrong"
        })

      assert html =~
               ~s{aria-describedby="delete-bucket-description delete-bucket-error"}

      assert html =~ ~s{id="delete-bucket-description"}
      assert html =~ "text-xs text-content-secondary"
    end

    test "aria-describedby covers only what exists" do
      html = dialog(%{description: "Hint."})
      assert html =~ ~s{aria-describedby="delete-bucket-description"}

      html = dialog(%{confirm_value: "wrong"})
      assert html =~ ~s{aria-describedby="delete-bucket-error"}

      html = dialog(%{})
      refute html =~ "aria-describedby"
    end

    test "the panel is focusable as a fallback for the initial focus" do
      html = dialog(%{})

      assert html =~ ~s{tabindex="-1"}
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.text_confirm_dialog
          id="m"
          open
          title="T"
          confirm_string="x"
          confirm_placeholder="x"
          data-testid="text-confirm-dialog"
        />
        """)

      assert html =~ ~s{data-testid="text-confirm-dialog"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html =
        dialog(%{
          alert_title: "A",
          alert_description: "B",
          body: {:safe, "C"},
          text: "D",
          description: "E",
          confirm_value: "wrong",
          variant: "warning",
          enable_copy: true
        })

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

  defp panel_class(html), do: marker_class(html, "data-polaris-tcd-panel")
  defp body_class(html), do: marker_class(html, "data-polaris-tcd-body")
end
