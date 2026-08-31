defmodule PolarisUI.Components.SkeletonTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Skeleton` — the port
  of the Supabase design system Skeleton: the pulsing muted placeholder
  that ghosts loading content.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Skeleton

  defp render_skeleton(assigns) do
    assigns = Map.merge(%{class: nil, rest: %{}}, assigns)

    rendered_to_string(~H"""
    <.skeleton class={@class} {assigns[:rest]} />
    """)
  end

  describe "the placeholder" do
    test "renders the source's single pulsing div" do
      html = render_skeleton(%{})

      assert html =~ "data-polaris-skeleton"
      assert html =~ "animate-pulse rounded-md bg-surface-muted"
    end

    test "the pulse is the stock Tailwind opacity keyframes — no animation token" do
      html = render_skeleton(%{})

      refute html =~ "animate-progress-indeterminate"
      refute html =~ "animate-caret-blink"
    end

    test "the fill is the muted content wash, not an opaque surface" do
      html = render_skeleton(%{})

      refute html =~ "bg-surface-panel"
      refute html =~ "bg-surface-border"
      assert html =~ "bg-surface-muted"
    end
  end

  describe "shape via class" do
    test "sizes and radii merge for the avatar ghost" do
      html = render_skeleton(%{class: "size-12 rounded-full"})

      assert html =~ "size-12"
      assert html =~ "rounded-full"
    end

    test "text-bar ghosts take explicit widths" do
      html = render_skeleton(%{class: "h-4 w-[250px]"})

      assert html =~ "h-4 w-[250px]"
    end

    test "caller classes never displace the pulse or the wash" do
      html = render_skeleton(%{class: "h-12"})

      assert html =~ "animate-pulse"
      assert html =~ "bg-surface-muted"
    end
  end

  describe "accessibility" do
    test "the placeholder itself is hidden from the a11y tree" do
      html = render_skeleton(%{})

      assert html =~ ~s{aria-hidden="true"}
    end

    test "forwards global attributes for the busy-region contract" do
      html = render_skeleton(%{rest: %{"data-testid" => "members-skeleton"}})

      assert html =~ ~s{data-testid="members-skeleton"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_skeleton(%{class: "h-4 w-40"})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
