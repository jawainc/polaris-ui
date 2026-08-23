defmodule PolarisUI.Components.TocTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Toc` — anatomy (nav
  landmark, header/footer slots, viewport, items, thumb), depth indents,
  the track border, empty items, inline-code titles, slug-derived hrefs,
  class merge + rest forwarding, scrollspy hook wiring, and the
  client-owned data-active state, mirroring the Supabase design system
  fragment `ui-patterns/Toc` 1:1: a sticky `<nav>` of in-page anchor
  links indented by heading depth, a thumb sized through the
  `--toc-top`/`--toc-height` CSS vars, and a colocated runtime hook that
  owns the scrollspy.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Toc

  @hook "PolarisUI.Components.Toc.Toc"

  @items [
    %{title: "REST API", url: "#rest-api", depth: 2},
    %{title: "Client libraries", url: "intro#client-libraries", depth: 3},
    %{title: "Deep dive", url: "#deep-dive", depth: 4}
  ]

  defp render_toc(assigns) do
    assigns = Map.merge(%{id: "page-toc", items: @items, show_track: false}, assigns)

    rendered_to_string(~H"""
    <.toc
      id={@id}
      items={@items}
      show_track={assigns[:show_track]}
      class={assigns[:class]}
      data-testid={assigns[:data_testid]}
    >
      <:header :if={assigns[:header]}>{assigns[:header]}</:header>
      <:footer :if={assigns[:footer]}>{assigns[:footer]}</:footer>
    </.toc>
    """)
  end

  describe "anatomy" do
    test "renders a nav landmark labelled as a table of contents" do
      html = render_toc(%{})

      assert html =~ ~s{<nav id="page-toc"}
      assert html =~ ~s{aria-label="Table of contents"}
      assert html =~ "data-polaris-toc"
    end

    test "the header and footer slots sandwich the scroll viewport" do
      html =
        render_toc(%{
          header: {:safe, "<p>On this page</p>"},
          footer: {:safe, "<a href=\"#top\">Back to top</a>"}
        })

      assert html =~ "On this page"
      assert html =~ "Back to top"

      header = position(html, "On this page")
      viewport = position(html, "data-polaris-toc-viewport")
      items = position(html, "data-polaris-toc-items")
      footer = position(html, "Back to top")

      assert is_integer(header) and is_integer(viewport) and header < viewport
      assert is_integer(items) and is_integer(footer) and items < footer
    end

    test "wraps the items in the overflow viewport and padded items container" do
      html = render_toc(%{})

      assert html =~ "data-polaris-toc-viewport"
      assert html =~ "relative min-h-0 overflow-y-auto text-sm"
      assert html =~ "data-polaris-toc-items"
      assert html =~ "list-none flex flex-col pl-[calc(0.75rem+5px)] border-surface-border"
    end

    test "renders one real in-page link per item with the muted-to-active text states" do
      html = render_toc(%{})

      assert html =~ ~s{href="#rest-api"}
      assert html =~ ~s{href="#client-libraries"}
      assert html =~ ~s{href="#deep-dive"}

      classes = item_classes(html)
      assert length(classes) == 3

      for class <- classes do
        assert class =~ "text-content-muted"
        assert class =~ "hover:text-brand-emerald"
        assert class =~ "transition-colors"
        assert class =~ "break-words"
        assert class =~ "first:pt-0 last:pb-0"
        assert class =~ "data-[active=true]:text-content-primary"
      end
    end

    test "the thumb consumes the fragment's --toc-top/--toc-height CSS vars" do
      html = render_toc(%{})

      assert html =~ "data-polaris-toc-thumb"
      assert html =~ "absolute start-0 w-px bg-content-primary transition-all"
      assert html =~ ~s{top: var(--toc-top, 0px); height: var(--toc-height, 0px)}
      assert html =~ ~s{aria-hidden="true"}
    end
  end

  describe "layout" do
    test "the root is sticky at the assumed header offset and hidden below md" do
      html = render_toc(%{})

      root = marker_class(html, "data-polaris-toc ")
      assert root =~ "sticky"
      assert root =~ "top-24"
      assert root =~ "h-fit"
      assert root =~ "max-md:hidden"
    end

    test "the inner column ports --toc-width as a fixed w-56" do
      html = render_toc(%{})

      assert html =~ "flex w-56 max-w-full flex-col gap-3 pe-4"
    end
  end

  describe "depth indents" do
    test "indents exactly by tier: <=2 ps-3, 3 ps-6, >=4 ps-8" do
      html =
        render_toc(%{
          items: [
            %{title: "H1", url: "#h1", depth: 1},
            %{title: "H2", url: "#h2", depth: 2},
            %{title: "H3", url: "#h3", depth: 3},
            %{title: "H4", url: "#h4", depth: 4},
            %{title: "H6", url: "#h6", depth: 6}
          ]
        })

      [h1, h2, h3, h4, h6] = item_classes(html)

      assert indent(h1) == "ps-3"
      assert indent(h2) == "ps-3"
      assert indent(h3) == "ps-6"
      assert indent(h4) == "ps-8"
      assert indent(h6) == "ps-8"
    end
  end

  describe "titles" do
    test "parses backtick inline code into mono code segments" do
      html =
        render_toc(%{
          items: [%{title: "Using the `supabase-js` client", url: "#client", depth: 2}]
        })

      # the HEEx for/if blocks pad segments with whitespace, hence ~r
      assert html =~
               ~r{Using the\s+<code class="font-mono text-content-primary">supabase-js</code>\s+client}
    end

    test "renders several code segments and keeps an unclosed backtick as code" do
      html =
        render_toc(%{
          items: [
            %{title: "call `fn` then `spawn` forever", url: "#calls", depth: 2},
            %{title: "unclosed `code", url: "#unclosed", depth: 2}
          ]
        })

      assert html =~ ~s{>fn</code>}
      assert html =~ ~s{>spawn</code>}
      assert html =~ "forever"
      assert html =~ ~s{>code</code>}
    end
  end

  describe "hrefs (formatSlug)" do
    test "plain anchors pass through untouched" do
      html = render_toc(%{items: [%{title: "Plain", url: "#plain-anchor", depth: 2}]})

      assert html =~ ~s{href="#plain-anchor"}
    end

    test "urls carrying a heading prefix use the slug after the first hash" do
      html = render_toc(%{items: [%{title: "Custom", url: "intro#custom-anchor", depth: 2}]})

      assert html =~ ~s{href="#custom-anchor"}
      refute html =~ "intro#custom-anchor"
    end
  end

  describe "track" do
    test "show_track draws the start border on the items container" do
      html = render_toc(%{show_track: true})

      container = marker_class(html, "data-polaris-toc-items ")
      assert container =~ ~r{border-s\b}
      assert container =~ "border-surface-border"
      assert container =~ "pl-[calc(0.75rem+5px)]"
    end

    test "without the track only the thumb inset remains" do
      html = render_toc(%{})

      container = marker_class(html, "data-polaris-toc-items ")
      refute container =~ ~r{border-s\b}
      assert container =~ "border-surface-border"
      assert container =~ "pl-[calc(0.75rem+5px)]"
    end
  end

  describe "empty items" do
    test "renders the nav shell only — header/footer slots still work" do
      html =
        render_toc(%{
          items: [],
          header: {:safe, "<p>On this page</p>"},
          footer: {:safe, "<p>Back to top</p>"}
        })

      assert html =~ ~s{<nav id="page-toc"}
      assert html =~ ~s{aria-label="Table of contents"}
      assert html =~ "On this page"
      assert html =~ "Back to top"

      refute html =~ ~s{<div data-polaris-toc-viewport}
      refute html =~ ~s{<div data-polaris-toc-items}
      refute html =~ ~s{<div data-polaris-toc-thumb}
      refute Regex.match?(~r{<a[^>]*data-polaris-toc-item}, html)
    end
  end

  describe "attributes" do
    test "caller classes merge onto the sticky root and override its utilities" do
      html = render_toc(%{class: "top-8 w-64"})

      root = marker_class(html, "data-polaris-toc ")
      assert root =~ "sticky"
      assert root =~ "top-8"
      assert root =~ "w-64"
      refute root =~ "top-24"
    end

    test "forwards global attributes via rest" do
      html = render_toc(%{data_testid: "docs-toc"})

      assert html =~ ~s{data-testid="docs-toc"}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_toc(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
      assert html =~ "updated()"
      assert html =~ "destroyed()"
    end

    test "implements the scrollspy: observe headings, sync data-active, size the thumb" do
      html = render_toc(%{})

      assert html =~ "IntersectionObserver"
      assert html =~ "ResizeObserver"
      assert html =~ ~s{rootMargin: "0px 0px -70% 0px"}
      assert html =~ "document.getElementById"
      assert html =~ ~s{setAttribute("data-active", "true")}
      assert html =~ ~s{removeAttribute("data-active")}
      assert html =~ "getComputedStyle"
      assert html =~ "paddingTop"
      assert html =~ "paddingBottom"
      assert html =~ "--toc-top"
      assert html =~ "--toc-height"
    end

    test "centers the last active item inside the viewport container only" do
      html = render_toc(%{})

      assert html =~ "scrollTo("
      assert html =~ ~s{behavior: "smooth"}
      assert html =~ "clientHeight / 2"
      assert html =~ "offsetTop"
      refute html =~ "scrollIntoView"
    end

    test "re-runs setup only when the item set changed and cleans up in destroyed" do
      html = render_toc(%{})

      assert html =~ "_fingerprint"
      assert length(String.split(html, "disconnect()")) == 3
    end
  end

  describe "active state" do
    test "data-active is client-owned — never server-rendered on items" do
      html = render_toc(%{})

      refute Regex.match?(~r{<a[^>]*data-active}, html)
      # but the styling for it ships on every item
      assert html =~ "data-[active=true]:text-content-primary"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html =
        render_toc(%{show_track: true, header: {:safe, "<p>H</p>"}, footer: {:safe, "<p>F</p>"}})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  # First byte offset of `pattern` in `html`, or nil — for ordering checks.
  defp position(html, pattern) do
    case :binary.match(html, pattern) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  # The class attribute of the element carrying the given marker (the marker
  # always precedes the element's own class= in the rendered output).
  defp marker_class(html, marker) do
    [_, after_marker | _] = String.split(html, marker, parts: 2)
    marker_class(after_marker)
  end

  defp marker_class(segment) do
    case :binary.match(segment, ~s{class="}) do
      {index, _} ->
        segment
        |> binary_part(index + 7, byte_size(segment) - index - 7)
        |> String.split(~s{"})
        |> List.first()

      :nomatch ->
        ""
    end
  end

  # One class string per TOC anchor, in render order. The trailing space in
  # the split pattern keeps "data-polaris-toc-items" (and the selector
  # strings inside the hook script) from matching.
  defp item_classes(html) do
    html
    |> String.split(~s{data-polaris-toc-item })
    |> Enum.drop(1)
    |> Enum.map(&marker_class/1)
  end

  defp indent(class), do: class |> String.split(" ") |> Enum.find(&String.starts_with?(&1, "ps-"))
end
