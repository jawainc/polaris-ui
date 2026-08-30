defmodule PolarisUI.Components.LabelTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Label` — the port of
  the Supabase design system Label (the Radix Label primitive): the
  accessible caption associated with a form control.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Label

  defp render_label(assigns) do
    assigns =
      Map.merge(%{for: nil, class: nil, rest: %{}, block: {:safe, "Email"}}, assigns)

    rendered_to_string(~H"""
    <.label for={@for} class={@class} {assigns[:rest]}>{@block}</.label>
    """)
  end

  describe "label" do
    test "renders a real label with the source's exact treatment" do
      html = render_label(%{})

      assert html =~ ~s{<label data-polaris-label}
      assert html =~ ~s{class="text-sm text-content-primary leading-none}

      assert html =~
               ~s{peer-disabled:cursor-not-allowed peer-disabled:opacity-70}
    end

    test "associates the control via for" do
      html = render_label(%{for: "email"})

      assert html =~ ~s{for="email"}
    end

    test "merges the caller's class after the defaults — later utilities win" do
      html = render_label(%{class: "font-mono text-content-secondary"})

      assert html =~ ~s{font-mono text-content-secondary">}
      # the caller's text color replaces the default content-primary
      refute html =~ "text-content-primary"
    end

    test "forwards global attributes via rest" do
      html = render_label(%{rest: %{"data-testid" => "email-label"}})

      assert html =~ ~s{data-testid="email-label"}
    end

    test "renders the inner block as the caption" do
      html = render_label(%{block: {:safe, "Table name"}})

      assert html =~ "Table name"
    end

    test "never hardcodes raw hex values" do
      html = render_label(%{class: "bg-surface-panel"})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
