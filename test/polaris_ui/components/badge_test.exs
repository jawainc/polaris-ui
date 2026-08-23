defmodule PolarisUI.Components.BadgeTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Badge` — the port of
  the Supabase design system Badge: a 9px uppercase pill annotating
  another item, with the neutral / warning / success / destructive /
  secondary variant formula.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Badge

  defp render_badge(assigns) do
    assigns = Map.merge(%{variant: "default", class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.badge variant={@variant} class={@class} {assigns[:rest]}>
      {assigns[:label] || "Default"}
    </.badge>
    """)
  end

  describe "anatomy" do
    test "renders an inline pill span with the baked-in typography" do
      html = render_badge(%{})

      assert html =~ ~s{<span}
      assert html =~ ~s{data-polaris-badge="default"}

      class = badge_class(html)
      assert class =~ "inline-flex"
      assert class =~ "items-center justify-center"
      assert class =~ "rounded-full"
      assert class =~ "uppercase"
      assert class =~ "font-medium"
      assert class =~ "text-[9px]"
      assert class =~ "leading-none"
      assert class =~ "tracking-[0.07em]"
      assert class =~ "px-[5.5px] py-[3px]"
      assert class =~ "whitespace-nowrap"
      # the 1px border is baked in; variants only pick the color
      assert class =~ "border"
    end

    test "renders the label content" do
      html = render_badge(%{label: "10"})

      assert html =~ ~r{>\s*10\s*</span>}
    end

    test "carries a gap for an optional dot or icon child" do
      html = render_badge(%{})

      assert badge_class(html) =~ "gap-1"
    end
  end

  describe "variants" do
    test "default is the neutral elevated pill" do
      html = render_badge(%{variant: "default"})

      class = badge_class(html)
      assert class =~ "bg-surface-panel"
      assert class =~ "text-content-secondary"
      assert class =~ "border-surface-border"
      assert html =~ ~s{data-polaris-badge="default"}
    end

    test "warning uses the amber tint formula" do
      html = render_badge(%{variant: "warning"})

      class = badge_class(html)
      assert class =~ "bg-warning-muted"
      assert class =~ "text-warning"
      assert class =~ "border-warning-border"
    end

    test "success uses the brand emerald formula" do
      html = render_badge(%{variant: "success"})

      class = badge_class(html)
      assert class =~ "bg-brand-emerald-muted"
      assert class =~ "text-brand-accent"
      assert class =~ "border-brand-border"
    end

    test "destructive uses the red tint formula" do
      html = render_badge(%{variant: "destructive"})

      class = badge_class(html)
      assert class =~ "bg-danger-muted"
      assert class =~ "text-danger"
      assert class =~ "border-danger-border"
    end

    test "secondary is the quiet, borderless hover treatment" do
      html = render_badge(%{variant: "secondary"})

      class = badge_class(html)
      assert class =~ "bg-surface-panel-hover/50"
      assert class =~ "hover:bg-surface-panel-hover/80"
      assert class =~ "border-transparent"
      assert class =~ "text-content-primary"
    end

    test "rejects an unknown variant" do
      assert_raise ArgumentError, ~r/:variant/, fn ->
        render_badge(%{variant: "sparkly"})
      end
    end
  end

  describe "attributes" do
    test "caller classes merge last and win conflicts" do
      html = render_badge(%{class: "px-2"})

      class = badge_class(html)
      assert class =~ "px-2"
      refute class =~ "px-[5.5px]"
    end

    test "forwards global attributes via rest" do
      html = render_badge(%{rest: %{"data-testid" => "row-count", title: "3 rows"}})

      assert html =~ ~s{data-testid="row-count"}
      assert html =~ ~s{title="3 rows"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_badge(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end

    test "renders no interactive affordances of its own" do
      html = render_badge(%{})

      refute html =~ "cursor-pointer"
      refute html =~ "focus-visible"
      refute html =~ "role="
    end
  end

  # The class attribute of the badge span.
  defp badge_class(html) do
    html
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
  end
end
