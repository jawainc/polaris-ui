defmodule PolarisUI.Components.MermaidTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Mermaid` — the port
  of the Supabase design system Mermaid (`packages/ui-patterns`):
  diagrams rendered from Mermaid-syntax text.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Mermaid

  @hook "PolarisUI.Components.Mermaid.Root"
  @chart "flowchart LR\n  A[User Request] --> B{Authenticated?}"

  defp render_mermaid(assigns) do
    assigns =
      Map.merge(
        %{id: "diagram", chart: @chart, mermaid_src: nil, class: nil, rest: %{}},
        assigns
      )

    rendered_to_string(~H"""
    <.mermaid
      id={@id}
      chart={@chart}
      mermaid_src={@mermaid_src}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "root" do
    test "renders the source chart, hidden, next to the canvas" do
      html = render_mermaid(%{})

      assert html =~ ~s{<div id="diagram" data-polaris-mermaid}
      assert html =~ ~s{<div data-polaris-mermaid-source hidden class="hidden">}

      assert html =~
               "flowchart LR\n  A[User Request] --&gt; B{Authenticated?}"
    end

    test "loads Mermaid 11 from the jsDelivr CDN by default" do
      html = render_mermaid(%{})

      assert html =~
               ~s{data-mermaid-src="https://cdn.jsdelivr.net/npm/mermaid@11.12.1/dist/mermaid.min.js"}
    end

    test "mermaid_src overrides the build URL for self-hosting" do
      html = render_mermaid(%{mermaid_src: "/vendor/mermaid.min.js"})

      assert html =~ ~s{data-mermaid-src="/vendor/mermaid.min.js"}
    end

    test "merges the caller's class and forwards global attributes" do
      html = render_mermaid(%{class: "my-2", rest: %{"data-testid" => "erd"}})

      assert marker_class(html, "data-polaris-mermaid") =~ "my-2"
      assert html =~ ~s{data-testid="erd"}
    end
  end

  describe "loading state" do
    test "the canvas renders the source's pulse placeholder server-side" do
      html = render_mermaid(%{})

      assert html =~ ~s{<div id="diagram-canvas" phx-update="ignore" data-polaris-mermaid-canvas}
      assert html =~ ~s{class="my-6 h-64 animate-pulse rounded-lg bg-surface-panel p-6"}
    end

    test "the canvas is hook-owned — patches never fight the injected SVG" do
      html = render_mermaid(%{})

      assert html =~ ~s{phx-update="ignore"}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_mermaid(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
    end

    test "initializes with theme base and the source's diagram config" do
      html = render_mermaid(%{})

      assert html =~ "startOnLoad: false"
      assert html =~ ~s{theme: "base"}
      assert html =~ "actorMargin: 150, messageMargin: 60, noteMargin: 20"
      assert html =~ "useMaxWidth: false"
    end

    test "renders with a unique id per render and sanitizes non-XML br tags" do
      html = render_mermaid(%{})

      assert html =~ ~s{Math.random().toString(36).substring(2, 11)}
      assert html =~ ~s{replace(/<br\\s*>/gi, "<br/>")}
    end

    test "reads the theme variables from Polaris design tokens, not hexes" do
      html = render_mermaid(%{})

      assert html =~ "getComputedStyle(root)"
      assert html =~ "--color-brand-emerald"
      assert html =~ "--color-surface-panel"
      assert html =~ "--color-content-primary"
      assert html =~ "--font-mono"
    end

    test "light mode flips the font size and tracks polaris-light" do
      html = render_mermaid(%{})

      assert html =~ ~s{root.closest(".polaris-light")}
      assert html =~ ~s{light ? "13px" : "14px"}
    end

    test "invalid syntax renders the danger box with the raw chart" do
      html = render_mermaid(%{})

      assert html =~ ~s{"Mermaid Error: " + message}
      assert html =~ "border-danger-border bg-danger-muted"
      assert html =~ "font-mono text-sm text-danger"
      assert html =~ "pre.textContent = chart"
    end

    test "re-renders only when the chart or theme changes (the hash guard)" do
      html = render_mermaid(%{})

      assert html =~ "if (key === this._hash) return"
      assert html =~ "updated()"
    end

    test "loads the library once per page" do
      html = render_mermaid(%{})

      assert html =~ "window.__polarisMermaidLoader"
    end
  end

  describe "figure" do
    test "the injected figure matches the source's container treatment" do
      html = render_mermaid(%{})

      assert html =~
               "my-6 flex w-full justify-center rounded-lg border border-surface-border bg-surface-base p-6"

      assert html =~ "[&_svg]:h-auto [&_svg]:max-w-full"
    end
  end

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
