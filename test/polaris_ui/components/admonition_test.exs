defmodule PolarisUI.Components.AdmonitionTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Admonition` — every type,
  layout, slot, and attribute passthrough, plus the composed interactive
  states. Styling follows the Supabase design system fragment
  `ui-patterns/Admonition` 1:1: tinted translucent fills with visible
  borders, 23px badge chips, paragraph titles, and actions arranged per
  layout.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Admonition
  import PolarisUI.Components.Button

  @all_types ~w(note caution danger deprecation default destructive success warning)

  describe "types" do
    test "note (the default) is the neutral surface callout with an info badge" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition>Connection pooling is enabled by default.</.admonition>
        """)

      assert html =~ ~s{role="alert"}
      assert html =~ ~s{aria-label="Note"}
      assert html =~ "border-surface-border"
      assert html =~ "bg-surface-panel/40"
      assert html =~ "text-content-primary"
      assert html =~ ~s{data-polaris-icon="default"}
      assert html =~ "bg-content-muted"
      assert html =~ "M12 11v5"
      refute html =~ "bg-warning-muted"
      refute html =~ "bg-danger-muted"
    end

    test "type=default renders identically to note" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition type="default">Free tier limits apply.</.admonition>
        """)

      assert html =~ ~s{aria-label="Note"}
      assert html =~ "bg-surface-panel/40"
      assert html =~ ~s{data-polaris-icon="default"}
    end

    test "caution, warning, and deprecation share the amber treatment with their own labels" do
      labels = %{"caution" => "Caution", "warning" => "Warning", "deprecation" => "Deprecated"}

      for {type, label} <- labels do
        assigns = %{type: type}

        html =
          rendered_to_string(~H"""
          <.admonition type={@type}>This operation cannot be undone.</.admonition>
          """)

        assert html =~ ~s{aria-label="#{label}"}, "wrong label for #{type}"
        assert html =~ "bg-warning-muted", "missing amber fill for #{type}"
        assert html =~ "border-warning-border", "missing amber border for #{type}"
        assert html =~ ~s{data-polaris-icon="warning"}, "missing warning glyph for #{type}"
        assert html =~ "bg-warning", "missing amber badge chip for #{type}"
        # the triangle glyph
        assert html =~ "m21.73 18-8-14", "missing triangle glyph for #{type}"
      end
    end

    test "danger and destructive share the red treatment with the triangle glyph" do
      for type <- ~w(danger destructive) do
        assigns = %{type: type}

        html =
          rendered_to_string(~H"""
          <.admonition type={@type}>Deleting the project removes all data.</.admonition>
          """)

        assert html =~ ~s{aria-label="Danger"}, "wrong label for #{type}"
        assert html =~ "bg-danger-muted", "missing red fill for #{type}"
        assert html =~ "border-danger-border", "missing red border for #{type}"
        assert html =~ "bg-danger", "missing red badge chip for #{type}"
        # danger reuses the warning triangle with destructive chip colors
        assert html =~ ~s{data-polaris-icon="destructive"}, "wrong glyph marker for #{type}"
        assert html =~ "m21.73 18-8-14", "missing triangle glyph for #{type}"
      end
    end

    test "success is the emerald treatment with a check glyph for completed states" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition type="success">Project transfer complete.</.admonition>
        """)

      assert html =~ ~s{aria-label="Success"}
      assert html =~ "bg-brand-emerald-muted"
      assert html =~ "border-brand-border"
      assert html =~ ~s{data-polaris-icon="success"}
      assert html =~ "bg-brand-emerald"
      assert html =~ "m8.5 12.2 2.4 2.4 4.6-4.9"
    end

    test "rejects an unknown type" do
      assigns = %{bad: "explody"}

      assert_raise ArgumentError, ~r/:type/, fn ->
        rendered_to_string(~H"""
        <.admonition type={@bad}>Nope</.admonition>
        """)
      end
    end
  end

  describe "layouts" do
    test "vertical (the default) stacks actions below the copy" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition title="OAuth Server is disabled">
          <:description>Enable OAuth Server to use your project as an identity provider.</:description>
          <:action><button>Open OAuth settings</button></:action>
        </.admonition>
        """)

      assert html =~ "flex min-w-0 flex-1 flex-col"
      assert html =~ "mt-3 flex flex-row items-start gap-2"
      refute html =~ "@container"
    end

    test "horizontal puts content and actions in one row, actions right-aligned" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition layout="horizontal" title="OAuth Server is disabled">
          <:description>Enable OAuth Server to use your project as an identity provider.</:description>
          <:action><button>Open OAuth settings</button></:action>
        </.admonition>
        """)

      assert html =~ "flex-row items-center justify-between gap-x-6 lg:gap-x-8"
      assert html =~ "flex flex-row items-center gap-2"
      refute html =~ "mt-3 flex"

      label = position(html, "OAuth Server is disabled")
      action = position(html, "Open OAuth settings")
      assert is_integer(label) and is_integer(action) and label < action
    end

    test "responsive switches at container breakpoints, independent of page width" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition layout="responsive" title="OAuth Server is disabled">
          <:description>Enable OAuth Server to use your project as an identity provider.</:description>
          <:action><button>Open OAuth settings</button></:action>
        </.admonition>
        """)

      # the root becomes the container-query context
      assert html =~ "@container"
      assert html =~ "flex-col @md:flex-row @md:items-center @md:justify-between"
      assert html =~ "@md:gap-x-6 @lg:gap-x-8"
      assert html =~ "mt-3 flex flex-row items-start gap-2 @md:mt-0 @md:items-center"
    end

    test "rejects an unknown layout" do
      assigns = %{bad: "diagonal"}

      assert_raise ArgumentError, ~r/:layout/, fn ->
        rendered_to_string(~H"""
        <.admonition layout={@bad}>Nope</.admonition>
        """)
      end
    end
  end

  describe "title and body" do
    test "the title is a styled paragraph, never a heading" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition title="Point-in-time recovery is off">
          <:description>
            Enable it to restore your database to any moment in the last 7 days.
          </:description>
        </.admonition>
        """)

      assert html =~ ~s{<p class="mb-0.5 mt-0 font-medium text-content-primary"}
      assert html =~ "Point-in-time recovery is off"
      # headings are reserved for the surrounding page, per the Supabase rules
      refute html =~ "<h1"
      refute html =~ "<h2"
      refute html =~ "<h3"
    end

    test "description renders rich content with the callout paragraph rhythm" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition title="Restart required">
          <:description>
            <p>Schema changes apply after a restart.</p>
            <p>Connections drain first.</p>
          </:description>
        </.admonition>
        """)

      assert html =~ "Schema changes apply after a restart."
      assert html =~ "text-sm text-content-secondary"
      assert html =~ "[&amp;_p]:mb-1.5"
      assert html =~ "[&amp;_p:last-child]:mb-0"
      assert html =~ "[&amp;_ul]:my-1.5"
    end

    test "the inner block is the plain drop-in body (the children slot)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition title="Restart required">Changes apply after a restart.</.admonition>
        """)

      assert html =~ "Changes apply after a restart."
      assert html =~ "[&amp;_p]:mb-1.5"
    end

    test "dynamic body content (closure inner blocks) still renders as a body" do
      assigns = %{body: "Connections drain first."}

      html =
        rendered_to_string(~H"""
        <.admonition title="Restart required">{@body}</.admonition>
        """)

      assert html =~ "Connections drain first."
      assert html =~ "[&amp;_p]:mb-1.5"
    end

    test "a dynamic blank body is not a body" do
      assigns = %{body: "  "}

      html =
        rendered_to_string(~H"""
        <.admonition title="Restart required">{@body}</.admonition>
        """)

      assert html =~ "Restart required"
      refute html =~ "[&amp;_p]:mb-1.5"
    end

    test "description and inner block may combine; description leads" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition title="Restart required">
          <:description>
            <p>From the description slot.</p>
          </:description>
          From the inner block.
        </.admonition>
        """)

      desc = position(html, "From the description slot.")
      inner = position(html, "From the inner block.")
      assert is_integer(desc) and is_integer(inner) and desc < inner
    end

    test "whitespace-only inner block is not a body (action-only admonition)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition title="Transfer project ownership">
          <:action><button>Transfer project</button></:action>
        </.admonition>
        """)

      assert html =~ "Transfer project ownership"
      refute html =~ "[&amp;_p]:mb-1.5"
    end

    test "description-only copy aligns with the badge; a title or hidden icon cancels it" do
      assigns = %{}

      aligned =
        rendered_to_string(~H"""
        <.admonition>Free tier limits reset at the start of each month.</.admonition>
        """)

      assert aligned =~ ~s{class="min-w-0 my-0.5"}

      assigns = %{}

      with_title =
        rendered_to_string(~H"""
        <.admonition title="Free tier">Limits reset monthly.</.admonition>
        """)

      assert with_title =~ ~s{class="min-w-0"}
      refute with_title =~ ~s{class="min-w-0 my-0.5"}

      assigns = %{}

      no_icon =
        rendered_to_string(~H"""
        <.admonition show_icon={false}>Limits reset monthly.</.admonition>
        """)

      refute no_icon =~ ~s{class="min-w-0 my-0.5"}
    end
  end

  describe "icon" do
    test "show_icon={false} removes the badge entirely" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition show_icon={false} title="Free tier">Limits reset monthly.</.admonition>
        """)

      refute html =~ "data-polaris-icon"
      refute html =~ "size-[23px]"
    end

    test "the icon slot replaces the whole badge with caller markup" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition title="Experiments enabled">
          <:icon><svg data-icon="flask" /></:icon>
          Feature flags apply to this project.
        </.admonition>
        """)

      assert html =~ ~s{data-icon="flask"}
      refute html =~ "data-polaris-icon"
      refute html =~ "size-[23px]"
    end

    test "a custom icon is still gated by show_icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition show_icon={false}>
          <:icon><svg data-icon="flask" /></:icon>
          Feature flags apply to this project.
        </.admonition>
        """)

      refute html =~ ~s{data-icon="flask"}
    end

    test "badge glyphs are decorative — hidden from assistive tech" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition>Free tier limits reset monthly.</.admonition>
        """)

      assert html =~ ~s{aria-hidden="true"}
    end
  end

  describe "actions" do
    test "actions render after the body with the layout's arrangement" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition type="warning" title="Transfer project ownership">
          <:description>The transfer cannot be undone once accepted.</:description>
          <:action><button>Transfer project</button></:action>
          <:action><button>Cancel transfer</button></:action>
        </.admonition>
        """)

      title = position(html, "Transfer project ownership")
      body = position(html, "The transfer cannot be undone once accepted.")
      first = position(html, "Transfer project</button>")
      second = position(html, "Cancel transfer")

      assert is_integer(title) and title < body and body < first and first < second
    end
  end

  describe "accessibility" do
    test "the root is an alert region labeled by its type" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition type="warning">This operation cannot be undone.</.admonition>
        """)

      assert html =~ ~s{role="alert"}
      assert html =~ ~s{aria-label="Warning"}
    end

    test "a caller aria-label overrides the derived one, exactly once" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition aria-label="Restart pending">Restart your project to apply changes.</.admonition>
        """)

      assert html =~ ~s{aria-label="Restart pending"}
      refute html =~ ~s{aria-label="Note"}
      assert count(html, "aria-label=") == 1
    end

    test "a caller role overrides the alert default (e.g. passive status)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition role="status">Saving changes…</.admonition>
        """)

      assert html =~ ~s{role="status"}
      refute html =~ ~s{role="alert"}
      assert count(html, "role=") == 1
    end
  end

  describe "interactive states (composed with buttons)" do
    test "the admonition itself stays passive — no hover, active, or cursor affordances" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition type="warning" title="Transfer project ownership">
          <:description>The transfer cannot be undone once accepted.</:description>
        </.admonition>
        """)

      root = root_class(html)

      refute root =~ "hover:"
      refute root =~ "focus"
      refute root =~ "active:"
      refute root =~ "cursor-pointer"
      refute root =~ "transition"
    end

    test "slotted action buttons carry hover, focus-ring, loading, and disabled states" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition
          type="destructive"
          layout="horizontal"
          title="Delete this project?"
        >
          <:description>All data will be permanently removed.</:description>
          <:action>
            <.button variant="danger" phx-click="delete-project">Delete project</.button>
          </:action>
          <:action>
            <.button variant="default">Keep project</.button>
          </:action>
        </.admonition>
        """)

      # the buttons own the interactive states, inside the admonition
      assert html =~ "focus-visible:ring-2"
      assert html =~ "hover:bg-danger-fill-hover"
      assert html =~ "Delete project"
      assert html =~ "Keep project"
    end

    test "a loading action locks and shows the spinner inside the admonition" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition title="Transferring project">
          <:description>Ownership moves once the new owner accepts.</:description>
          <:action>
            <.button variant="danger" loading>Transfer project</.button>
          </:action>
        </.admonition>
        """)

      assert html =~ ~s{aria-busy="true"}
      assert html =~ "data-polaris-spinner"
      assert html =~ "pointer-events-none"
      assert html =~ "Transfer project"
    end

    test "a disabled action dims and drops out of the tab order inside the admonition" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition title="Transfer blocked">
          <:description>The new owner must verify their email first.</:description>
          <:action>
            <.button disabled>Transfer project</.button>
          </:action>
        </.admonition>
        """)

      assert html =~ " disabled"
      assert html =~ ~s{tabindex="-1"}
      assert html =~ "opacity-50"
    end
  end

  describe "attributes and events" do
    test "forwards global attributes and phx events via rest" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition id="quota-warning" data-testid="quota" phx-click="open-billing">
          Free tier limits reset monthly.
        </.admonition>
        """)

      assert html =~ ~s{id="quota-warning"}
      assert html =~ ~s{data-testid="quota"}
      assert html =~ ~s{phx-click="open-billing"}
    end

    test "caller classes win over defaults through cn/1" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.admonition class="rounded-none border-x-0 bg-surface-base">
          Sandwiched inside a card.
        </.admonition>
        """)

      assert html =~ "bg-surface-base"
      assert html =~ "rounded-none"
      refute html =~ "bg-surface-panel/40"
      refute html =~ "rounded-lg"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      for type <- @all_types, layout <- ~w(vertical horizontal responsive) do
        assigns = %{type: type, layout: layout}

        html =
          rendered_to_string(~H"""
          <.admonition type={@type} layout={@layout} title="Any callout">
            Any body copy.
          </.admonition>
          """)

        refute html =~ "#[", "arbitrary-value class leaked for #{type}/#{layout}"
      end
    end

    test "every type keeps the high-contrast border the dark theme depends on" do
      for type <- @all_types do
        assigns = %{type: type}

        html =
          rendered_to_string(~H"""
          <.admonition type={@type}>Any body copy.</.admonition>
          """)

        assert html =~ " border-", "missing border for #{type}"
        assert html =~ "bg-", "missing fill for #{type}"
      end
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

  # The class attribute of the root alert region (the first class= in the
  # rendered output — role and aria-label precede it on the same tag).
  defp root_class(html) do
    [_, class | _] = String.split(html, ~s{class="}, parts: 2)
    class |> String.split(~s{"}) |> List.first()
  end
end
