defmodule PolarisUI.Components.CollapsibleAlertTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.CollapsibleAlert` — every
  variant, attribute, slot, hook, and accessibility behavior, mirroring the
  Supabase design system fragment `ui-patterns/collapsible-alert` 1:1: alert
  chrome tightened to `p-3`, a `font-medium` trigger row, a 26×26 icon-only
  outline toggle with a 200ms chevron rotation, and content hidden outright
  while collapsed.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.CollapsibleAlert

  @hook "PolarisUI.Components.CollapsibleAlert.Toggle"

  describe "anatomy" do
    test "renders the trigger row, toggle button, and collapsible content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="connection-help" trigger="Need help?">
          <p>Try a different browser or disable extensions.</p>
        </.collapsible_alert>
        """)

      assert html =~ "Need help?"
      assert html =~ ~s{id="connection-help"}
      assert html =~ ~s{id="connection-help-content"}
      assert html =~ ~s{data-polaris-collapsible-label}
      assert html =~ ~s{data-polaris-collapsible-trigger}
      assert html =~ ~s{data-polaris-collapsible-content}
      assert html =~ "Try a different browser or disable extensions."

      # the alert chrome carries the tightened p-3 padding of the fragment
      root = root_class(html)
      assert root =~ "p-3"
      assert root =~ "rounded-lg"
      assert root =~ " border-"
      assert root =~ "relative w-full"
      assert root =~ "text-sm"

      # the summary is the fragment's medium-weight span in a justified row
      assert html =~ "flex items-center justify-between gap-2"
      assert html =~ ~s{class="font-medium}
    end

    test "the toggle is a 26px square icon-only outline button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="help" trigger="Details">Detail copy.</.collapsible_alert>
        """)

      # 26x26 square (tiny size + w-[26px], padding zeroed by the icon-only path)
      assert html =~ "w-[26px]"
      assert html =~ "h-[26px]"
      assert html =~ "aspect-square"
      assert html =~ "p-0"
      # outline variant styling from the shared button
      assert html =~ "bg-transparent"
      # chevron glyph rotates 180deg over 200ms while open
      assert html =~ "[&amp;[data-state=open]_svg]:rotate-180"
      assert html =~ "transition-transform duration-200"
      assert html =~ ~s{aria-hidden="true"}
      refute html =~ "transition-transform duration-100"
    end
  end

  describe "variants" do
    test "default (the default) is the neutral surface callout" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Details">Copy.</.collapsible_alert>
        """)

      assert html =~ "border-surface-border"
      assert html =~ "bg-surface-panel/40"
      refute html =~ "bg-danger-muted"
      refute html =~ "bg-warning-muted"
    end

    test "destructive tints red with a matching border" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" variant="destructive" trigger="Migration failed">
          Copy.
        </.collapsible_alert>
        """)

      assert html =~ "border-danger-border"
      assert html =~ "bg-danger-muted"
      refute html =~ "bg-surface-panel/40"
    end

    test "warning tints amber with a matching border" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" variant="warning" trigger="Quota nearly reached">
          Copy.
        </.collapsible_alert>
        """)

      assert html =~ "border-warning-border"
      assert html =~ "bg-warning-muted"
    end

    test "rejects an unknown variant" do
      assigns = %{bad: "explody"}

      assert_raise ArgumentError, ~r/:variant/, fn ->
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Nope" variant={@bad}>Copy.</.collapsible_alert>
        """)
      end
    end
  end

  describe "open state" do
    test "collapses by default: closed data-state and hidden content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Details">Copy.</.collapsible_alert>
        """)

      assert html =~ ~s{data-state="closed"}
      assert html =~ "hidden"
      assert html =~ ~s{aria-expanded="false"}
    end

    test "default_open starts expanded: content visible, aria-expanded true" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Details" default_open>Copy.</.collapsible_alert>
        """)

      assert html =~ ~s{data-state="open"}
      assert html =~ ~s{aria-expanded="true"}
      # hidden must not appear on the content block
      refute html =~ " hidden"
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Details">Copy.</.collapsible_alert>
        """)

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      # the script body registers itself under the fully-qualified name
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
      assert html =~ "data-polaris-collapsible-trigger"
      assert html =~ "aria-expanded"
    end

    test "the hook toggles hidden content and aria-expanded client-side" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Details">Copy.</.collapsible_alert>
        """)

      # toggle wiring: click delegation + state application + patch resilience
      assert html =~ "addEventListener(\"click\""
      assert html =~ "removeAttribute(\"hidden\")"
      assert html =~ "setAttribute(\"hidden\", \"\")"
      assert html =~ "setAttribute(\"aria-expanded\", String(open))"
      assert html =~ "updated()"
    end
  end

  describe "accessibility" do
    test "the icon-only toggle is labeled, typed, and controls the content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Details">Copy.</.collapsible_alert>
        """)

      assert html =~ ~s{aria-label="Toggle"}
      assert html =~ ~s{type="button"}
      assert html =~ ~s{aria-controls="a-content"}
      assert count(html, "aria-label=") == 1
    end

    test "the toggle inherits the shared button focus ring" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Details">Copy.</.collapsible_alert>
        """)

      assert html =~ "focus-visible:ring-2"
      assert html =~ "focus-visible:ring-brand-emerald"
    end

    test "the root is a passive region — no role=alert on the disclosure" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Details">Copy.</.collapsible_alert>
        """)

      refute html =~ ~s{role="alert"}

      root = root_class(html)

      refute root =~ "hover:"
      refute root =~ "cursor-pointer"
      refute root =~ "transition"
    end
  end

  describe "attributes and events" do
    test "forwards global attributes and phx events via rest" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert
          id="quota"
          trigger="Free tier limits"
          data-testid="quota-callout"
          phx-click="open-help"
        >
          Copy.
        </.collapsible_alert>
        """)

      assert html =~ ~s{data-testid="quota-callout"}
      assert html =~ ~s{phx-click="open-help"}
    end

    test "caller classes win over defaults through cn/1" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" trigger="Details" class="rounded-none bg-surface-base">
          Copy.
        </.collapsible_alert>
        """)

      assert html =~ "bg-surface-base"
      assert html =~ "rounded-none"
      refute html =~ "bg-surface-panel/40"
      refute html =~ "rounded-lg"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_alert id="a" variant="warning" trigger="Warning">Copy.</.collapsible_alert>
        """)

      refute html =~ "#[", "arbitrary-value class leaked"
    end

    test "every variant keeps the high-contrast border the dark theme depends on" do
      for variant <- ~w(default destructive warning) do
        assigns = %{variant: variant}

        html =
          rendered_to_string(~H"""
          <.collapsible_alert id="a" variant={@variant} trigger="T">Copy.</.collapsible_alert>
          """)

        assert html =~ " border-", "missing border for #{variant}"
        assert html =~ "bg-", "missing fill for #{variant}"
      end
    end
  end

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  # The class attribute of the alert root (first class= in the output).
  defp root_class(html) do
    [_, class | _] = String.split(html, ~s{class="}, parts: 2)
    class |> String.split(~s{"}) |> List.first()
  end
end
