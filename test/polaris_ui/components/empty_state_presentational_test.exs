defmodule PolarisUI.Components.EmptyStatePresentationalTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.EmptyStatePresentational`
  — anatomy, icon fallback and sizing, microcopy structure, slots, and
  attribute passthrough, mirroring the Supabase design system fragment
  `ui-patterns/EmptyStatePresentational` 1:1: a dashed-border invitation
  card with a muted glyph, an action-prompt `<h3>`, a value-proposition
  `<p>`, and slotted actions below.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.EmptyStatePresentational
  import PolarisUI.Components.Button

  describe "anatomy" do
    test "renders the dashed invitation card with centered stacks" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational
          title="Create an auth hook"
          description="Use Postgres functions or HTTP endpoints to customize your authentication flow."
        >
          <.button size="tiny" variant="primary">Add hook</.button>
        </.empty_state_presentational>
        """)

      aside = aside_class(html)

      assert aside =~ "border-dashed"
      assert aside =~ "bg-surface-base"
      assert aside =~ "rounded-lg"
      assert aside =~ "px-4"
      assert aside =~ "py-10"
      assert aside =~ "flex-col items-center"
      assert aside =~ "gap-y-3"
      assert aside =~ "w-full"

      assert html =~ "Create an auth hook"

      assert html =~
               "Use Postgres functions or HTTP endpoints to customize your authentication flow."

      assert html =~ "Add hook"
      refute html =~ "<script", "purely presentational — no hook, no client JS"
    end

    test "the title is a heading, the description a paragraph, both marked" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational
          title="Create a vector bucket"
          description="Store embeddings at scale."
        />
        """)

      assert html =~ ~s{<h3}
      assert html =~ ~s{data-polaris-empty-state-title}
      assert html =~ ~s{<p }
      assert html =~ ~s{data-polaris-empty-state-description}

      title = position(html, "data-polaris-empty-state-title")
      desc = position(html, "data-polaris-empty-state-description")
      assert is_integer(title) and is_integer(desc) and title < desc
    end

    test "the description is optional and omitted when blank" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="No API keys" />
        """)

      refute html =~ "data-polaris-empty-state-description"
      refute html =~ "max-w-[640px]"
    end

    test "the description keeps a readable measure and muted tone" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="T" description="D" />
        """)

      assert html =~ "max-w-[640px] text-sm text-content-secondary"
    end

    test "actions render after the text group" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="Add a provider" description="Use third-party auth.">
          <.button size="tiny" variant="default">Add provider</.button>
        </.empty_state_presentational>
        """)

      text = position(html, "Add a provider")
      button = position(html, "Add provider")

      assert is_integer(text) and is_integer(button) and text < button
    end

    test "composing buttons carries the full interactive state machine" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="Create bucket">
          <.button size="tiny" variant="primary">Create bucket</.button>
        </.empty_state_presentational>
        """)

      assert html =~ "focus-visible:ring-2"
      assert html =~ "h-[26px]"
      assert html =~ "bg-brand-fill"
    end
  end

  describe "icon" do
    test "falls back to the muted square-plus glyph at 24px with a 1.5 stroke" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="Create bucket" description="D" />
        """)

      icon = icon_class(html)

      assert icon =~ "text-content-muted"
      assert icon =~ "[&amp;&gt;svg]:size-6"
      assert html =~ ~s{stroke-width="1.5"}
      assert html =~ ~s{<rect width="18" height="18" x="3" y="3" rx="2">}
      assert html =~ ~s{aria-hidden="true"}
      assert html =~ ~s{data-polaris-empty-state-icon}
    end

    test "the icon slot replaces the default glyph wholesale" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="Create a vector bucket" description="D">
          <:icon><svg data-icon="bucket-plus" /></:icon>
        </.empty_state_presentational>
        """)

      assert html =~ ~s{data-icon="bucket-plus"}
      refute html =~ ~s{<rect width="18" height="18" x="3" y="3" rx="2">}
    end

    test "icon_size maps to static glyph scales (16/24/32px)" do
      scales = %{"small" => "[&amp;&gt;svg]:size-4", "large" => "[&amp;&gt;svg]:size-8"}

      for {size, scale} <- scales do
        assigns = %{size: size}

        html =
          rendered_to_string(~H"""
          <.empty_state_presentational title="T" icon_size={@size} />
          """)

        assert icon_class(html) =~ scale, "missing #{scale} for icon_size #{size}"
      end
    end

    test "rejects an unknown icon_size" do
      assigns = %{bad: "gigantic"}

      assert_raise ArgumentError, ~r/:icon_size/, fn ->
        rendered_to_string(~H"""
        <.empty_state_presentational title="T" icon_size={@bad} />
        """)
      end
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational
          title="T"
          id="no-buckets"
          data-testid="empty"
          aria-label="Empty buckets"
        />
        """)

      assert html =~ ~s{id="no-buckets"}
      assert html =~ ~s{data-testid="empty"}
      assert html =~ ~s{aria-label="Empty buckets"}
    end

    test "caller classes merge onto the root through cn/1" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="T" class="py-6 bg-surface-panel" />
        """)

      aside = aside_class(html)

      assert aside =~ "py-6"
      assert aside =~ "bg-surface-panel"
      refute aside =~ "py-10"
      refute aside =~ "bg-surface-base"
    end

    test "content_class merges onto the text block" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="T" content_class="gap-y-1" />
        """)

      assert html =~ "gap-y-1"
    end

    test "icon_class merges onto the icon wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="T" icon_class="text-brand-accent" />
        """)

      icon = icon_class(html)

      assert icon =~ "text-brand-accent"
      refute icon =~ "text-content-muted"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="T" description="D" class="py-6" />
        """)

      refute html =~ "#[", "arbitrary-value class leaked"
    end

    test "keeps the high-contrast dashed border the dark theme depends on" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state_presentational title="T" />
        """)

      assert aside_class(html) =~ "border-surface-border"
    end
  end

  # First byte offset of `pattern` in `html`, or nil — for ordering checks.
  defp position(html, pattern) do
    case :binary.match(html, pattern) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  # The class attribute of the root aside (first class= in the output).
  defp aside_class(html) do
    [_, class | _] = String.split(html, ~s{class="}, parts: 2)
    class |> String.split(~s{"}) |> List.first()
  end

  # The class attribute of the icon wrapper (after the icon marker).
  defp icon_class(html) do
    [_, rest] = String.split(html, "data-polaris-empty-state-icon", parts: 2)
    [_, class | _] = String.split(rest, ~s{class="}, parts: 2)
    class |> String.split(~s{"}) |> List.first()
  end
end
