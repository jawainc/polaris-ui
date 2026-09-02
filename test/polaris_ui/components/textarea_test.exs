defmodule PolarisUI.Components.TextareaTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Textarea` — the port
  of the Supabase design system Textarea (`textarea.tsx`): the
  shadcn-style multi-line text field with the 80px height floor and
  the danger treatment keyed off `aria-invalid`.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Textarea

  defp render_textarea(assigns) do
    assigns =
      Map.merge(
        %{
          name: nil,
          value: nil,
          placeholder: nil,
          rows: nil,
          disabled: false,
          readonly: false,
          loading: false,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.textarea
      name={@name}
      value={@value}
      placeholder={@placeholder}
      rows={@rows}
      disabled={@disabled}
      readonly={@readonly}
      loading={@loading}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "rest state" do
    test "renders the source's base treatment over Polaris tokens" do
      html = render_textarea(%{})

      assert html =~ ~s{<textarea data-polaris-textarea}

      textarea = textarea_class(html)

      assert textarea =~
               "flex min-h-[80px] w-full rounded-md border border-surface-border bg-surface-panel"

      assert textarea =~ "px-3 py-2 text-base md:text-sm text-content-primary"
      assert textarea =~ "placeholder:text-content-muted"
      assert textarea =~ "transition-colors duration-200"
    end

    test "forwards name and placeholder; value renders as the content" do
      html = render_textarea(%{name: "bio", value: "Hello", placeholder: "Add a description"})

      assert html =~ ~s{name="bio"}
      assert html =~ ~s{placeholder="Add a description"}
      assert html =~ ">Hello</textarea>"
    end

    test "rows is omitted by default and forwarded when set" do
      refute render_textarea(%{}) =~ ~s{rows=}

      assert render_textarea(%{rows: 4}) =~ ~s{rows="4"}
    end

    test "forwards global attributes via rest — id, phx-change, aria-invalid" do
      html =
        render_textarea(%{
          rest: %{
            "id" => "bio",
            "phx-change" => "validate",
            "phx-blur" => "format",
            "aria-invalid" => "true",
            "maxlength" => "280"
          }
        })

      assert html =~ ~s{id="bio"}
      assert html =~ ~s{phx-change="validate"}
      assert html =~ ~s{phx-blur="format"}
      assert html =~ ~s{aria-invalid="true"}
      assert html =~ ~s{maxlength="280"}
    end

    test "purely presentational — no colocated hook" do
      refute render_textarea(%{}) =~ "phx-hook"
      refute render_textarea(%{loading: true}) =~ "phx-hook"
    end
  end

  describe "states" do
    test "hover and focus ring — the source's focus-ring utility expanded" do
      textarea = render_textarea(%{}) |> textarea_class()

      assert textarea =~ "hover:border-surface-border-hover"
      assert textarea =~ "focus:border-surface-border-hover focus:outline-none"

      assert textarea =~
               "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"

      assert textarea =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    end

    test "invalid — aria-invalid drives the danger treatment" do
      textarea = render_textarea(%{}) |> textarea_class()

      assert textarea =~
               "aria-[invalid=true]:bg-danger-muted aria-[invalid=true]:border-danger-border"

      assert textarea =~ "aria-[invalid=true]:hover:border-danger"

      assert textarea =~
               "aria-[invalid=true]:focus:border-danger aria-[invalid=true]:focus-visible:border-danger"
    end

    test "read-only — flat border, secondary text" do
      textarea = render_textarea(%{}) |> textarea_class()

      assert textarea =~ "read-only:border-surface-border read-only:text-content-secondary"
      assert render_textarea(%{readonly: true}) =~ ~s{readonly}
    end

    test "disabled — not-allowed cursor, half-opacity field" do
      html = render_textarea(%{disabled: true})

      assert html =~ ~s{disabled}
      assert textarea_class(html) =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end

    test "loading — locks the field and overlays the brand spinner" do
      html = render_textarea(%{loading: true})

      assert html =~ ~s{data-polaris-textarea-loading}
      assert html =~ ~s{class="relative w-full"}
      assert html =~ ~s{aria-busy="true"}
      assert html =~ ~s{disabled}

      assert html =~
               ~s{class="absolute right-3 top-3 size-4 animate-spin text-brand-accent"}

      assert html =~ ~s{data-polaris-textarea-spinner}
      # room for the spinner on the first line without losing the left padding
      assert textarea_class(html) =~ "pr-9"
      assert textarea_class(html) =~ "min-h-[80px]"
    end
  end

  describe "customization" do
    test "merges the caller's class — later utilities win" do
      html = render_textarea(%{class: "max-h-64 bg-surface-base"})

      textarea = textarea_class(html)

      assert textarea =~ "max-h-64 bg-surface-base"
      refute textarea =~ "bg-surface-panel", "caller bg should override the default fill"
    end

    test "never hardcodes raw hex values" do
      refute render_textarea(%{}) =~ "#[", "arbitrary-value class leaked"
    end
  end

  # The textarea's class — `data-polaris-textarea ` (trailing space) pins the
  # textarea itself so the loading wrapper (`data-polaris-textarea-loading`)
  # never matches first.
  defp textarea_class(html), do: marker_class(html, "data-polaris-textarea ")

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
