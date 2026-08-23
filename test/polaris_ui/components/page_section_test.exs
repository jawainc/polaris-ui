defmodule PolarisUI.Components.PageSectionTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.PageSection` — anatomy
  and ordering, orientation variants, summary alignment, the conditional
  content wrapper, per-part class merging, rest forwarding, and design
  rules, mirroring the Supabase design system fragment
  `ui-patterns/PageSection` (the composable Root / Meta / Summary /
  Title / Description / Aside / Content family collapsed into one
  function component).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.PageSection

  describe "anatomy" do
    test "renders title, description, and aside in order before the content" do
      html =
        section(%{
          description: "External services this project talks to.",
          aside: "New connection",
          inner: "Section body"
        })

      assert html =~ "data-polaris-page-section"
      assert html =~ "data-polaris-page-section-title"
      assert html =~ "data-polaris-page-section-description"
      assert html =~ "data-polaris-page-section-aside"
      assert html =~ "data-polaris-page-section-content"

      title_at = position(html, "data-polaris-page-section-title")
      description_at = position(html, "data-polaris-page-section-description")
      aside_at = position(html, "data-polaris-page-section-aside")
      content_at = position(html, "data-polaris-page-section-content")

      assert is_integer(title_at) and is_integer(description_at) and
               is_integer(aside_at) and is_integer(content_at)

      assert title_at < description_at and description_at < aside_at and aside_at < content_at

      assert html =~ "Connections"
      assert html =~ "External services this project talks to."
      assert html =~ "New connection"
      assert html =~ "Section body"
    end

    test "the description is optional" do
      html = section(%{inner: "Section body"})

      refute html =~ "data-polaris-page-section-description"
      assert html =~ "data-polaris-page-section-title"
      assert html =~ "Connections"
    end

    test "the aside is omitted when the slot is empty" do
      html = section(%{inner: "Section body"})

      refute html =~ "data-polaris-page-section-aside"
    end

    test "the meta row is a container-query wrapper around the summary/aside row" do
      html = section(%{aside: "New connection"})

      assert html =~ ~s{class="@container"}
      assert html =~ "@xl:flex-row"
      assert html =~ "@xl:justify-between"
      assert html =~ "@xl:items-center"
    end
  end

  describe "orientation" do
    test "vertical is the default when the attr is omitted" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_section title="Connections">Section body</.page_section>
        """)

      assert html =~ ~s{data-orientation="vertical"}

      root = class_of(html, "data-polaris-page-section")

      assert root =~ "flex flex-col"
      refute root =~ "grid"
    end

    test "vertical stacks meta above content with the cva base classes" do
      html = section(%{orientation: "vertical", inner: "Section body"})

      root = class_of(html, "data-polaris-page-section")

      assert root =~ "pt-12 last:pb-12 gap-6"
      assert root =~ "flex flex-col"
      refute root =~ "grid-cols"
    end

    test "horizontal splits meta from content at the @3xl container breakpoint" do
      html = section(%{orientation: "horizontal", inner: "Section body"})

      assert html =~ ~s{data-orientation="horizontal"}

      root = class_of(html, "data-polaris-page-section")

      assert root =~ "pt-12 last:pb-12 gap-6"
      assert root =~ "grid @3xl:grid-cols-[1fr_2fr] @3xl:gap-12"
    end
  end

  describe "summary alignment" do
    test "without a description the summary centers against the aside" do
      html = section(%{aside: "New connection"})

      summary = class_of(html, "data-polaris-page-section-summary")

      assert summary =~ "flex flex-col gap-1"
      assert summary =~ "@xl:flex-1"
      assert summary =~ "@xl:self-center"
    end

    test "with a description the summary drops the self-centering" do
      html =
        section(%{
          description: "External services this project talks to.",
          aside: "New connection"
        })

      summary = class_of(html, "data-polaris-page-section-summary")

      assert summary =~ "@xl:flex-1"
      refute summary =~ "@xl:self-center"
    end

    test "the aside bottom-aligns with the description and never shrinks" do
      html = section(%{description: "External services.", aside: "New connection"})

      aside = class_of(html, "data-polaris-page-section-aside")

      assert aside =~ "flex shrink-0 items-center gap-2 @xl:self-end"
    end
  end

  describe "content wrapper" do
    test "is omitted when the inner block is blank" do
      html = section(%{})

      refute html =~ "data-polaris-page-section-content"
      assert html =~ "data-polaris-page-section-title"

      html = section(%{inner: "   "})

      refute html =~ "data-polaris-page-section-content"
    end

    test "wraps the inner block in a plain div" do
      html = section(%{inner: "Section body"})

      # Plain wrapper: no default classes of its own (the fragment's
      # Content is bare too — HEEx renders the empty class attribute).
      assert class_of(html, "data-polaris-page-section-content") == ""
      assert html =~ "Section body"
    end
  end

  describe "class merging" do
    test "merges caller classes onto the root — caller wins" do
      html = section(%{class: "pt-6", inner: "Section body"})

      root = class_of(html, "data-polaris-page-section")

      assert root =~ "pt-6"
      refute root =~ "pt-12"
      assert root =~ "last:pb-12"
      assert root =~ "gap-6"
    end

    test "merges caller classes onto every part" do
      html =
        section(%{
          description: "External services this project talks to.",
          aside: "New connection",
          inner: "Section body",
          title_class: "tracking-tight",
          description_class: "max-w-lg",
          aside_class: "flex-wrap",
          content_class: "space-y-4"
        })

      title = class_of(html, "data-polaris-page-section-title")

      assert title =~ "text-xl text-content-primary"
      assert title =~ "tracking-tight"

      description = class_of(html, "data-polaris-page-section-description")

      assert description =~ "text-sm text-content-secondary"
      assert description =~ "max-w-lg"

      aside = class_of(html, "data-polaris-page-section-aside")

      assert aside =~ "flex shrink-0 items-center gap-2 @xl:self-end"
      assert aside =~ "flex-wrap"

      content = class_of(html, "data-polaris-page-section-content")

      assert content =~ "space-y-4"
    end
  end

  describe "globals" do
    test "forwards rest attributes to the root" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.page_section title="Connections" id="connections-section" data-track="sections">
          Section body
        </.page_section>
        """)

      assert html =~ ~s{id="connections-section"}
      assert html =~ ~s{data-track="sections"}
      assert html =~ "data-polaris-page-section-content"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html =
        section(%{
          orientation: "horizontal",
          description: "External services this project talks to.",
          aside: "New connection",
          inner: "Section body",
          class: "bg-surface-panel",
          title_class: "tracking-tight",
          description_class: "max-w-lg",
          aside_class: "flex-wrap",
          content_class: "space-y-4"
        })

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  describe "microcopy and heading semantics" do
    test "the title is the section's single h2 carrying the title text" do
      html = section(%{inner: "Section body"})

      assert count(html, "<h2") == 1

      open_at = position(html, "<h2")
      text_at = position(html, "Connections")
      close_at = position(html, "</h2>")

      assert is_integer(open_at) and is_integer(text_at) and is_integer(close_at)
      assert open_at < text_at and text_at < close_at
    end

    test "the h2 stays one level below the page header's h1 — no h1 or h3 here" do
      html = section(%{description: "External services this project talks to."})

      refute html =~ "<h1"
      refute html =~ "<h3"

      description_at = position(html, "data-polaris-page-section-description")
      text_at = position(html, "External services this project talks to.")

      assert is_integer(description_at) and is_integer(text_at) and description_at < text_at
    end
  end

  # Renders the component with a base title, merging per-test overrides
  # (including nil for the optional attrs) — see confirmation_modal_test.
  defp section(assigns) do
    assigns = Map.merge(%{title: "Connections"}, assigns)

    rendered_to_string(~H"""
    <.page_section
      title={@title}
      description={assigns[:description]}
      orientation={assigns[:orientation] || "vertical"}
      class={assigns[:class]}
      title_class={assigns[:title_class]}
      description_class={assigns[:description_class]}
      aside_class={assigns[:aside_class]}
      content_class={assigns[:content_class]}
    >
      <:aside>{assigns[:aside]}</:aside>
      {assigns[:inner]}
    </.page_section>
    """)
  end

  # First byte offset of `pattern` in `html`, or nil — for ordering checks.
  defp position(html, pattern) do
    case :binary.match(html, pattern) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  # Extracts the class attribute of the element carrying the marker,
  # regardless of attribute order within the tag.
  defp class_of(html, marker) do
    marker = Regex.escape(marker)

    class_after = ~r{<[^>]*#{marker}[^>]*?class="([^"]*)"[^>]*>}
    class_before = ~r{<[^>]*class="([^"]*)"[^>]*?#{marker}[^>]*>}

    cond do
      match = Regex.run(class_after, html, capture: :all_but_first) -> hd(match)
      match = Regex.run(class_before, html, capture: :all_but_first) -> hd(match)
      true -> flunk("no element with marker #{marker}")
    end
  end
end
