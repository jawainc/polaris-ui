defmodule PolarisUI.Components.ErrorDisplayTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.ErrorDisplay` — anatomy,
  the support URL builder, slots, events, states, and accessibility,
  mirroring the Supabase design system fragment
  `ui-patterns/ErrorDisplay/ErrorDisplay` 1:1: a warning-toned card with a
  monospace message block and an always-present support footer.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.ErrorDisplay

  @hook "PolarisUI.Components.ErrorDisplay.Render"

  describe "anatomy" do
    test "renders the alert card with header, message block, and footer" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display
          id="tables-error"
          title="Failed to load tables"
          error_message="ERROR: CONNECTION TERMINATED."
        />
        """)

      assert html =~ ~s{id="tables-error"}
      assert html =~ ~s{role="alert"}
      assert html =~ ~s{aria-labelledby="tables-error-title"}
      assert html =~ ~s{id="tables-error-title"}
      assert html =~ "Failed to load tables"
      assert html =~ "ERROR: CONNECTION TERMINATED."
      assert html =~ "Need help?"
      assert html =~ "Contact support"
      assert html =~ ~s{data-polaris-error-display-header}
      assert html =~ ~s{data-polaris-error-display-message}
      assert html =~ ~s{data-polaris-error-display-footer}
    end

    test "the title is an h3 and the message is a monospaced pre" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="Failed to load tables" error_message="boom" />
        """)

      assert html =~ ~s{<h3 id="err-title"}
      assert html =~ ~s{<pre}
      assert html =~ "font-mono"
      assert html =~ "whitespace-pre-wrap"
      assert html =~ "max-h-32"
      assert html =~ "overflow-auto"
    end

    test "the card chrome mirrors the Supabase Card" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" />
        """)

      root = root_class(html)

      assert root =~ "overflow-hidden"
      assert root =~ "rounded-lg"
      assert root =~ "border-surface-border"
      assert root =~ "bg-surface-panel"
    end

    test "the message block uses the amber warning tint, not destructive red" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" />
        """)

      assert html =~ "bg-warning-muted"
      assert html =~ "border-warning"
      assert html =~ "text-warning"
      refute html =~ "danger"
    end

    test "the header badge is an amber chip with the filled triangle glyph" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" />
        """)

      assert html =~ ~s{data-polaris-error-display-badge}
      assert html =~ "bg-warning"
      assert html =~ "text-surface-ground"
      assert html =~ ~s{viewBox="0 0 22 20"}
      assert html =~ ~s{aria-hidden="true"}
    end
  end

  describe "support url" do
    test "defaults to /support/new with no query" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" />
        """)

      assert html =~ ~s{href="/support/new"}
    end

    test "encodes support_form_params, skipping nil and empty values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display
          id="err"
          title="T"
          error_message="M"
          support_form_params={%{project_ref: "my-project", category: nil, subject: "", message: "boom"}}
        />
        """)

      assert html =~ ~s{href="/support/new?message=boom&amp;project_ref=my-project"}
    end

    test "an empty params map keeps the bare base url" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" support_form_params={%{}} />
        """)

      assert html =~ ~s{href="/support/new"}
    end

    test "support_url overrides the base and support_label the text" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display
          id="err"
          title="T"
          error_message="M"
          support_url="/help/new"
          support_label="Open a ticket"
        />
        """)

      assert html =~ ~s{href="/help/new"}
      assert html =~ "Open a ticket"
      refute html =~ "Contact support"
    end

    test "the link opens in a new tab safely" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" />
        """)

      assert html =~ ~s{target="_blank"}
      assert html =~ ~s{rel="noopener noreferrer"}
    end
  end

  describe "slots" do
    test "the icon slot replaces the default glyph inside the badge" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M">
          <:icon><svg data-icon="custom" /></:icon>
        </.error_display>
        """)

      assert html =~ ~s{data-icon="custom"}
      refute html =~ ~s{viewBox="0 0 22 20"}
    end

    test "the inner block renders troubleshooting content between message and footer" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M">
          <p data-testid="troubleshooting">Check your connection.</p>
        </.error_display>
        """)

      assert html =~ ~s{data-polaris-error-display-body}
      assert html =~ "Check your connection."

      body_index = html |> :binary.match("data-polaris-error-display-body") |> elem(0)
      footer_index = html |> :binary.match("data-polaris-error-display-footer") |> elem(0)
      assert body_index < footer_index
    end

    test "an empty inner block renders no body section" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" />
        """)

      refute html =~ ~s{data-polaris-error-display-body}
    end
  end

  describe "events" do
    test "no hook or script without on_render — telemetry stays JS-free" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" />
        """)

      refute html =~ "phx-hook="
      refute html =~ "<script"
    end

    test "on_render attaches the colocated runtime hook with its event name" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" on_render="error-shown" />
        """)

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-render-event="error-shown"}
      assert html =~ "<script"
    end

    test "on_support_click wires phx-click on the link without blocking navigation" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" on_support_click="track-support" />
        """)

      assert html =~ ~s{phx-click="track-support"}
      assert html =~ ~s{href="/support/new"}
    end
  end

  describe "states and accessibility" do
    test "the support link carries hover and focus-visible states" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" />
        """)

      assert html =~ "hover:text-content-secondary"
      assert html =~ "focus-visible:ring-2"
      assert html =~ "focus-visible:ring-brand-emerald"
    end

    test "decorative glyphs are aria-hidden and the title carries semantics" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" />
        """)

      assert html =~ ~s{aria-hidden="true"}
      assert html =~ ~s{aria-labelledby="err-title"}
    end

    test "caller classes merge onto the root and global attrs pass through" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.error_display id="err" title="T" error_message="M" class="max-w-md" data-track="x" />
        """)

      root = root_class(html)

      assert root =~ "max-w-md"
      assert root =~ "rounded-lg"
      assert html =~ ~s{data-track="x"}
    end
  end

  defp root_class(html) do
    ~r{class="([^"]*)"[^>]*data-polaris-error-display}
    |> Regex.run(html, capture: :all_but_first)
    |> List.first()
  end
end
