defmodule PolarisUI.Components.SuccessCheckTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.SuccessCheck` — the
  port of the Supabase design system SuccessCheck: the static emerald
  disc + check that marks selection and completion.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.SuccessCheck

  defp render_check(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.success_check class={@class} {assigns[:rest]} />
    """)
  end

  describe "the disc" do
    test "renders the source's 20px emerald circle" do
      html = render_check(%{})

      assert html =~ "data-polaris-success-check"
      assert html =~ "inline-flex size-5 shrink-0 items-center justify-center rounded-full"
    end

    test "filled and ringed in brand emerald" do
      html = render_check(%{})

      assert html =~ "border border-brand-emerald bg-brand-emerald"
    end

    test "the check stroke rides the ground color — white on emerald in light, black in dark" do
      html = render_check(%{})

      assert html =~ "text-surface-ground"
    end
  end

  describe "the check glyph" do
    test "draws the Lucide Check path at 12px with a 3px stroke" do
      html = render_check(%{})

      assert html =~ ~s{viewBox="0 0 24 24"}
      assert html =~ "M20 6 9 17l-5-5"
      assert html =~ ~s{stroke-width="3"}
      assert html =~ ~s{class="size-3"}
    end

    test "round caps and joins, stroke only — no fill" do
      html = render_check(%{})

      assert html =~ ~s{fill="none"}
      assert html =~ ~s{stroke="currentColor"}
      assert html =~ ~s{stroke-linecap="round"}
      assert html =~ ~s{stroke-linejoin="round"}
    end
  end

  describe "static by design" do
    test "ships no animation — the state change is the signal" do
      html = render_check(%{})

      refute html =~ "animate-"
      refute html =~ "transition-"
    end
  end

  describe "positioning" do
    test "caller classes merge for the trailing-corner placement" do
      html = render_check(%{class: "absolute right-3 top-1/2 -translate-y-1/2"})

      assert html =~ "absolute right-3 top-1/2 -translate-y-1/2"
    end

    test "the disc keeps its footprint when classes merge" do
      html = render_check(%{class: "ml-2"})

      assert html =~ "size-5"
      assert html =~ "rounded-full"
      assert html =~ "ml-2"
    end
  end

  describe "accessibility" do
    test "the glyph is a visual echo — hidden from the a11y tree" do
      html = render_check(%{})

      assert html =~ ~s{aria-hidden="true"}
    end

    test "forwards global attributes" do
      html = render_check(%{rest: %{"data-testid" => "row-check"}})

      assert html =~ ~s{data-testid="row-check"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_check(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
