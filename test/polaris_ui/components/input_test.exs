defmodule PolarisUI.Components.InputTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Input` — the port of
  the Supabase design system Input (`input.tsx`): the shadcn-style
  single-line text field with the shared size scale.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Input

  defp render_input(assigns) do
    assigns =
      Map.merge(
        %{
          type: "text",
          name: nil,
          value: nil,
          placeholder: nil,
          size: "small",
          disabled: false,
          readonly: false,
          loading: false,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.input
      type={@type}
      name={@name}
      value={@value}
      placeholder={@placeholder}
      size={@size}
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
      html = render_input(%{})

      assert html =~ ~s{<input data-polaris-input}

      input = input_class(html)

      assert input =~
               "flex w-full rounded-md border border-surface-border bg-surface-panel"

      assert input =~ "text-content-primary"
      # every size variant carries its own text scale, which wins over the
      # base text-sm — exactly the source's tailwind-merge behavior
      assert input =~ "text-base md:text-sm"
      assert input =~ "placeholder:text-content-muted"
      assert input =~ "file:border-0 file:bg-transparent file:text-sm file:font-medium"
    end

    test "forwards type, name, value, and placeholder" do
      html = render_input(%{type: "email", name: "email", value: "a@b.c", placeholder: "Email"})

      assert html =~ ~s{type="email"}
      assert html =~ ~s{name="email"}
      assert html =~ ~s{value="a@b.c"}
      assert html =~ ~s{placeholder="Email"}
    end

    test "forwards global attributes via rest — id, phx-change, aria-invalid" do
      html =
        render_input(%{
          rest: %{"id" => "email", "phx-change" => "validate", "aria-invalid" => "true"}
        })

      assert html =~ ~s{id="email"}
      assert html =~ ~s{phx-change="validate"}
      assert html =~ ~s{aria-invalid="true"}
    end
  end

  describe "sizes" do
    test "small is the default — the source's SIZE_VARIANTS_DEFAULT" do
      html = render_input(%{})

      assert marker_class(html, "data-polaris-input") =~
               "text-base md:text-sm leading-4 px-3 py-2 h-[34px]"
    end

    test "renders every size on the source's scale" do
      assert render_input(%{size: "tiny"}) |> input_class() =~ "text-xs px-2.5 py-1 h-[26px]"

      assert render_input(%{size: "medium"}) |> input_class() =~
               "text-base md:text-sm px-4 py-2 h-[38px]"

      assert render_input(%{size: "large"}) |> input_class() =~ "text-base px-4 py-2 h-[42px]"
      assert render_input(%{size: "xlarge"}) |> input_class() =~ "text-base px-6 py-3 h-[50px]"
    end

    test "the size height wins over the base h-10 fallback" do
      refute render_input(%{}) |> input_class() =~ "h-10"
    end

    test "rejects unknown sizes" do
      assert_raise ArgumentError, ~r/:size/, fn -> render_input(%{size: "giant"}) end
    end
  end

  describe "states" do
    test "hover and focus ring — the source's focus-ring utility expanded" do
      input = render_input(%{}) |> input_class()

      assert input =~ "hover:border-surface-border-hover"
      assert input =~ "focus:border-surface-border-hover focus:outline-none"
      assert input =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert input =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    end

    test "invalid — aria-invalid drives the danger treatment" do
      input = render_input(%{}) |> input_class()

      assert input =~
               "aria-[invalid=true]:bg-danger-muted aria-[invalid=true]:border-danger-border"

      assert input =~ "aria-[invalid=true]:hover:border-danger"

      assert input =~
               "aria-[invalid=true]:focus:border-danger aria-[invalid=true]:focus-visible:border-danger"
    end

    test "read-only — flat border, secondary text" do
      input = render_input(%{}) |> input_class()

      assert input =~ "read-only:border-surface-border read-only:text-content-secondary"
    end

    test "disabled — not-allowed cursor, muted text" do
      html = render_input(%{disabled: true})

      assert html =~ ~s{disabled}
      assert input_class(html) =~ "disabled:cursor-not-allowed disabled:text-content-muted"
    end

    test "loading — locks the field and overlays the brand spinner" do
      html = render_input(%{loading: true})

      assert html =~ ~s{data-polaris-input-loading}
      assert html =~ ~s{aria-busy="true"}
      assert html =~ ~s{disabled}

      assert html =~
               ~s{class="absolute right-3 top-1/2 size-4 -translate-y-1/2 animate-spin text-brand-accent}

      assert html =~ ~s{data-polaris-input-spinner}
      # room for the spinner without losing the size scale's left padding
      assert input_class(html) =~ "pr-9"
      assert input_class(html) =~ "h-[34px]"
    end
  end

  describe "customization" do
    test "merges the caller's class — later utilities win" do
      html = render_input(%{class: "max-w-xs bg-surface-base"})

      input = input_class(html)

      assert input =~ "max-w-xs bg-surface-base"
      refute input =~ "bg-surface-panel", "caller bg should override the default fill"
    end

    test "never hardcodes raw hex values" do
      refute render_input(%{}) =~ "#[", "arbitrary-value class leaked"
    end
  end

  # The input's class — `data-polaris-input type=` pins the input itself
  # so the loading wrapper (`data-polaris-input-loading`) never matches first.
  defp input_class(html), do: marker_class(html, "data-polaris-input type=")

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
