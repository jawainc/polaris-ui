defmodule PolarisUI.Components.CardTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Card` — the port of the
  Supabase design system Card: the clipped panel surface with sectioned
  header/content/footer, `border-b` separators, the mono uppercase title,
  and the shared `--card-padding-x` horizontal rhythm.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Card

  defp render_card(assigns) do
    assigns =
      Map.merge(
        %{
          root_class: nil,
          header_class: nil,
          title_class: nil,
          description_class: nil,
          content_class: nil,
          footer_class: nil,
          rest: %{},
          with_description: true,
          with_footer: true
        },
        assigns
      )

    rendered_to_string(~H"""
    <.card class={@root_class} {assigns[:rest]}>
      <.card_header class={@header_class}>
        <.card_title class={@title_class}>Create project</.card_title>
        <.card_description :if={@with_description} class={@description_class}>
          Deploy a new Postgres database.
        </.card_description>
      </.card_header>
      <.card_content class={@content_class}>
        <p>Body</p>
      </.card_content>
      <.card_footer :if={@with_footer} class={@footer_class}>
        Footer
      </.card_footer>
    </.card>
    """)
  end

  describe "anatomy" do
    test "renders the root surface with the source treatment" do
      html = render_card(%{})

      assert html =~ ~s{data-polaris-card>}
      class = class_of(html, "data-polaris-card")
      assert class =~ "overflow-hidden rounded-lg"
      assert class =~ "border border-surface-border"
      assert class =~ "bg-surface-panel"
      assert class =~ "text-content-primary"
      assert class =~ "shadow-xs"
    end

    test "renders the header stacking title and description" do
      html = render_card(%{})

      class = class_of(html, "data-polaris-card-header")
      assert class =~ "flex flex-col space-y-1.5"
      assert class =~ "border-b border-surface-border"
      assert class =~ "py-4"
    end

    test "renders the title as the mono uppercase h3 signature" do
      html = render_card(%{})

      assert html =~ ~s{<h3 class="text-xs font-mono uppercase"}
      assert class_of(html, "data-polaris-card-title") =~ "text-xs font-mono uppercase"
      assert html =~ "Create project"
    end

    test "renders the description as a muted paragraph" do
      html = render_card(%{})

      assert html =~ "<p"

      assert class_of(html, "data-polaris-card-description") =~
               "text-sm text-content-secondary"

      assert html =~ "Deploy a new Postgres database."
    end

    test "renders the content section separated by border-b" do
      html = render_card(%{})

      class = class_of(html, "data-polaris-card-content")
      assert class =~ "border-b border-surface-border"
      assert class =~ "py-4"
      assert html =~ "<p>Body</p>"
    end

    test "renders the footer action row" do
      html = render_card(%{})

      assert class_of(html, "data-polaris-card-footer") =~ "flex items-center py-4"
      assert html =~ "Footer"
    end

    test "sections share the --card-padding-x rhythm" do
      html = render_card(%{})

      assert count(html, "px-[var(--card-padding-x,1rem)]") == 3
    end

    test "the content drops its separator when no footer follows" do
      html = render_card(%{with_footer: false})

      assert class_of(html, "data-polaris-card-content") =~ "last:border-none"
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_card(%{rest: %{"data-testid" => "project-card"}})

      assert html =~ ~s{data-testid="project-card"}
    end

    test "classes merge onto every section" do
      html =
        render_card(%{
          root_class: "max-w-sm",
          header_class: "bg-surface-panel-hover",
          title_class: "tracking-widest",
          description_class: "text-xs",
          content_class: "text-sm",
          footer_class: "justify-between"
        })

      assert class_of(html, "data-polaris-card") =~ "max-w-sm"
      assert class_of(html, "data-polaris-card-header") =~ "bg-surface-panel-hover"
      assert class_of(html, "data-polaris-card-title") =~ "tracking-widest"
      assert class_of(html, "data-polaris-card-description") =~ "text-xs"
      assert class_of(html, "data-polaris-card-content") =~ "text-sm"
      assert class_of(html, "data-polaris-card-footer") =~ "justify-between"
    end

    test "a caller class wins conflicts via cn/1" do
      html = render_card(%{root_class: "rounded-xl"})

      assert class_of(html, "data-polaris-card") =~ "rounded-xl"
      refute class_of(html, "data-polaris-card") =~ "rounded-lg"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_card(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  # Card sections render their class *before* the data-polaris marker —
  # extract the class attribute preceding the marker.
  defp class_of(html, marker) do
    [before_marker | _] = String.split(html, marker, parts: 2)

    before_marker
    |> String.split(~s{class="})
    |> List.last()
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
