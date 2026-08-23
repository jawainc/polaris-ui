defmodule PolarisUI.Components.AccordionTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Accordion` — the port
  of the Supabase design system Accordion (shadcn over Radix): border-b
  separated items, full-width underlined triggers with rotating chevrons,
  animated grid-row content regions, and the colocated hook owning the
  WAI-ARIA open-state machine.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Accordion

  @hook "PolarisUI.Components.Accordion.Root"

  defp render_accordion(assigns) do
    assigns =
      Map.merge(
        %{
          id: "faq",
          type: "single",
          collapsible: true,
          default_open: [],
          on_change: nil,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.accordion
      id={@id}
      type={@type}
      collapsible={@collapsible}
      default_open={@default_open}
      on_change={@on_change}
      class={@class}
      {assigns[:rest]}
    >
      <:item
        value={assigns[:v1] || "item-1"}
        title={assigns[:t1] || "Is it accessible?"}
        disabled={assigns[:d1] || false}
        hide_icon={assigns[:h1] || false}
        class={assigns[:c1]}
      >
        {assigns[:c1_content] || "Yes, WAI-ARIA."}
      </:item>
      <:item value={assigns[:v2] || "item-2"} title={assigns[:t2] || "Is it styled?"}>
        {assigns[:c2_content] || "Yes, it ships defaults."}
      </:item>
    </.accordion>
    """)
  end

  describe "anatomy" do
    test "renders the hook root with the type and collapsible dataset" do
      html = render_accordion(%{})

      assert html =~ ~s{id="faq"}
      assert html =~ ~s{data-polaris-accordion}
      assert html =~ ~s{data-type="single"}
      assert html =~ ~s{data-collapsible="true"}
      assert html =~ ~s{phx-hook="#{@hook}"}
    end

    test "renders items separated by the border-b" do
      html = render_accordion(%{})

      # two item divs (data-value renders only on items, never in the script)
      assert count(html, ~s{data-value="}) == 2
      assert count(html, ~s{class="border-b}) == 2
    end

    test "the trigger is a full-width underlined button in a flex header" do
      html = render_accordion(%{})

      assert html =~ ~s{<div class="flex">}

      class = trigger_class(html, "item-1")
      assert class =~ "flex flex-1"
      assert class =~ "cursor-pointer"
      assert class =~ "items-center justify-between"
      assert class =~ "py-4 text-left"
      assert class =~ "font-medium"
      assert class =~ "hover:underline"
      assert class =~ "transition-all"
    end

    test "the chevron rotates on open via the exact source selector" do
      html = render_accordion(%{})

      class = trigger_class(html, "item-1")
      assert class =~ "[&[data-state=open]>svg]:rotate-180"

      chevron = html |> String.split("<path d=\"m6 9 6 6 6-6\"") |> List.first()
      assert chevron =~ "h-4 w-4 shrink-0"
      assert chevron =~ "transition-transform duration-200"
      assert chevron =~ ~s{aria-hidden="true"}
    end

    test "hide_icon suppresses the chevron" do
      html = render_accordion(%{h1: true})

      assert count(html, "m6 9 6 6 6-6") == 1
    end

    test "the content renders inside the animated region with the source padding" do
      html = render_accordion(%{})

      assert html =~ "Yes, WAI-ARIA."
      assert html =~ ~s{class="pb-4 pt-0"}

      class = content_class(html, "item-1")
      assert class =~ "grid overflow-hidden text-sm"
      assert class =~ "duration-150 ease-out"
      assert class =~ "data-[state=closed]:grid-rows-[0fr]"
      assert class =~ "data-[state=open]:grid-rows-[1fr]"
      assert class =~ "data-[state=closed]:invisible"
    end

    test "closed regions collapse; open regions expand" do
      html = render_accordion(%{default_open: ["item-1"]})

      assert item_chunk(html, "item-1") =~ ~s{data-state="open"}
      assert item_chunk(html, "item-2") =~ ~s{data-state="closed"}
    end

    test "motion-reduce disables the animations" do
      html = render_accordion(%{})

      assert content_class(html, "item-1") =~ "motion-reduce:transition-none"
      assert html =~ "motion-reduce:transition-none motion-reduce:duration-0"
    end
  end

  describe "open-state model" do
    test "single mode clamps default_open to the first value" do
      html = render_accordion(%{default_open: ["item-2", "item-1"]})

      assert item_chunk(html, "item-2") =~ ~s{data-state="open"}
      assert item_chunk(html, "item-1") =~ ~s{data-state="closed"}
    end

    test "a bare string opens one item" do
      html = render_accordion(%{default_open: "item-2"})

      assert item_chunk(html, "item-2") =~ ~s{data-state="open"}
    end

    test "multiple mode keeps every default_open value" do
      html = render_accordion(%{type: "multiple", default_open: ["item-1", "item-2"]})

      assert item_chunk(html, "item-1") =~ ~s{data-state="open"}
      assert item_chunk(html, "item-2") =~ ~s{data-state="open"}
    end

    test "non-collapsible single still renders the closed-by-default state" do
      html = render_accordion(%{collapsible: false})

      assert html =~ ~s{data-collapsible="false"}
      assert item_chunk(html, "item-1") =~ ~s{data-state="closed"}
    end

    test "rejects an unknown type" do
      assert_raise ArgumentError, ~r/:type/, fn ->
        render_accordion(%{type: "accordion"})
      end
    end
  end

  describe "states" do
    test "the trigger carries the focus-ring treatment" do
      html = render_accordion(%{})

      class = trigger_class(html, "item-1")
      assert class =~ "focus-visible:outline-none"
      assert class =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert class =~ "focus-visible:ring-offset-2"
    end

    test "disabled locks the trigger and drops it from the tab order" do
      html = render_accordion(%{d1: true})

      chunk = item_chunk(html, "item-1")
      assert chunk =~ " disabled"
      assert chunk =~ ~s{tabindex="-1"}
      assert trigger_class(html, "item-1") =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end

    test "enabled triggers render the explicit Safari tabindex" do
      html = render_accordion(%{})

      assert item_chunk(html, "item-1") =~ ~s{tabindex="0"}
    end

    test "a caller tabindex wins and is marked so the hook respects it" do
      html = render_accordion(%{rest: %{}})

      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.accordion id="custom">
          <:item value="a" title="A" tabindex="1">Content A</:item>
        </.accordion>
        """)

      assert html =~ ~s{tabindex="1"}
      assert html =~ ~s{data-polaris-tabindex="true"}
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_accordion(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "toggles from the server-rendered state and seeds the open set" do
      html = render_accordion(%{default_open: ["item-1"]})

      assert html =~ "dataset.state === \"open\""
      assert html =~ "this._open = new Set("
    end

    test "honors single vs multiple and collapsible in _toggle" do
      html = render_accordion(%{})

      assert html =~ "dataset.type === \"multiple\""
      assert html =~ "dataset.collapsible === \"true\""
      assert html =~ "this._open.clear()"
    end

    test "pushes the on_change event when configured" do
      html = render_accordion(%{on_change: "faq-toggled"})

      assert html =~ ~s{data-change-event="faq-toggled"}
      assert html =~ "pushEvent(name, { value: value, state:"
    end

    test "no data-change-event attribute without on_change" do
      html = render_accordion(%{})

      refute html =~ "data-change-event"
    end

    test "implements roving tabindex with the Radix pattern" do
      html = render_accordion(%{})

      assert html =~ "aria-expanded"
      assert html =~ "_rove()"
      assert html =~ "trigger.tabIndex = trigger === active ? 0 : -1"
      assert html =~ "data-polaris-tabindex"
    end

    test "arrow and home/end keys move between triggers" do
      html = render_accordion(%{})

      assert html =~ ~s{"ArrowDown"}
      assert html =~ ~s{"ArrowUp"}
      assert html =~ ~s{"Home"}
      assert html =~ ~s{"End"}
      assert html =~ ".focus()"
    end

    test "disabled triggers are skipped by keyboard navigation" do
      html = render_accordion(%{})

      assert html =~ "!t.disabled"
    end

    test "re-applies state after LiveView patches" do
      html = render_accordion(%{})

      assert html =~ "updated()"
      assert html =~ "LiveView patches may stomp"
    end
  end

  describe "accessibility" do
    test "triggers and regions are wired by derived ids" do
      html = render_accordion(%{})

      assert html =~ ~s{id="faq-item-1-trigger"}
      assert html =~ ~s{id="faq-item-1-content"}
      assert html =~ ~s{aria-controls="faq-item-1-content"}
      assert html =~ ~s{aria-labelledby="faq-item-1-trigger"}
    end

    test "triggers expose aria-expanded from the initial state" do
      html = render_accordion(%{default_open: ["item-1"]})

      assert item_chunk(html, "item-1") =~ ~s{aria-expanded="true"}
      assert item_chunk(html, "item-2") =~ ~s{aria-expanded="false"}
    end

    test "content regions are labelled regions" do
      html = render_accordion(%{})

      assert count(html, ~s{role="region"}) == 2
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_accordion(%{rest: %{"data-testid" => "faq-block"}})

      assert html =~ ~s{data-testid="faq-block"}
    end

    test "item classes merge onto the item" do
      html = render_accordion(%{c1: "bg-surface-panel"})

      assert item_chunk(html, "item-1") =~ "bg-surface-panel"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_accordion(%{})

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

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  # The chunk describing one item: from its data-value to the next item.
  defp item_chunk(html, value) do
    [_, after_item | _] = String.split(html, ~s{data-value="#{value}"}, parts: 2)

    case :binary.match(after_item, "data-polaris-accordion-item") do
      {index, _} -> binary_part(after_item, 0, index)
      :nomatch -> after_item
    end
  end

  # The class attribute of an item's trigger button, unescaped — the button
  # renders its class after the trigger marker.
  defp trigger_class(html, value) do
    [_, after_marker | _] =
      String.split(item_chunk(html, value), "data-polaris-accordion-trigger", parts: 2)

    after_marker
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  # The class attribute of an item's content region, unescaped.
  defp content_class(html, value) do
    [_, after_marker | _] =
      String.split(item_chunk(html, value), "data-polaris-accordion-content", parts: 2)

    after_marker
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
