defmodule PolarisUI.Components.CollapsibleCardSectionTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.CollapsibleCardSection` —
  anatomy, attributes, slots, hook, and accessibility behavior, mirroring the
  Supabase design system fragment `ui-patterns/CollapsibleCardSection` 1:1: a
  mono-uppercase heading-as-button with a rotating chevron, animated
  grid-rows disclosure, and an optional description that renders only while
  expanded.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.CollapsibleCardSection

  @hook "PolarisUI.Components.CollapsibleCardSection.Toggle"

  describe "anatomy" do
    test "renders the heading trigger, chevron, and collapsing content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="advanced" title="Advanced settings">
          <input name="issuer" />
        </.collapsible_card_section>
        """)

      assert html =~ "Advanced settings"
      assert html =~ ~s{id="advanced"}
      assert html =~ ~s{id="advanced-trigger"}
      assert html =~ ~s{id="advanced-content"}
      assert html =~ ~s{data-polaris-collapsible-trigger}
      assert html =~ ~s{data-polaris-collapsible-content}
      assert html =~ ~s{name="issuer"}
    end

    test "the trigger blends with card section headings: mono, uppercase, tracked out" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings">Fields.</.collapsible_card_section>
        """)

      trigger = trigger_class(html)

      assert trigger =~ "font-mono"
      assert trigger =~ "uppercase"
      assert trigger =~ "tracking-widest"
      assert trigger =~ "text-xs"
      assert trigger =~ "flex items-center gap-1"
      assert trigger =~ "text-content-muted"
      assert trigger =~ "hover:text-content-secondary"
      assert trigger =~ "data-[state=open]:text-content-secondary"
    end

    test "the chevron is a 16px/1-stroke chevron-right that rotates 90deg when open" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings">Fields.</.collapsible_card_section>
        """)

      assert html =~ ~s{stroke-width="1"}
      assert html =~ "size-4"
      assert html =~ "group-data-[state=open]/trigger:rotate-90"
      assert html =~ "group-hover/trigger:text-content-secondary"
      assert html =~ "mr-2"
      assert html =~ ~s{aria-hidden="true"}
      # the lucide chevron-right path
      assert html =~ ~s{d="m9 18 6-6-6-6"}
    end

    test "the card chrome stays the caller's responsibility" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings">Fields.</.collapsible_card_section>
        """)

      # the fragment renders no panel border, background, or padding of its own
      root = root_class(html)
      refute root =~ "border-"
      refute root =~ "bg-"
      refute root =~ "px-"
      refute root =~ "py-"
    end
  end

  describe "description" do
    test "renders under the heading while expanded with the muted qualifier style" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section
          id="a"
          title="Advanced settings"
          description="These settings cannot be changed after creation"
          default_open
        >
          Fields.
        </.collapsible_card_section>
        """)

      assert html =~ "These settings cannot be changed after creation"
      assert html =~ ~s{class="mb-6 text-xs text-content-muted"}
      assert html =~ ~s{data-polaris-description}

      # the description renders before the disclosed content
      desc = position(html, "These settings cannot be changed after creation")
      content = position(html, "Fields.")
      assert is_integer(desc) and is_integer(content) and desc < content
    end

    test "omits the description paragraph when not provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings" default_open>
          Fields.
        </.collapsible_card_section>
        """)

      refute html =~ "data-polaris-description"
      refute html =~ "mb-6"
    end
  end

  describe "open state and animation" do
    test "collapses by default: closed data-state, zero grid rows, invisible" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings">Fields.</.collapsible_card_section>
        """)

      assert html =~ ~s{data-state="closed"}
      assert html =~ ~s{aria-expanded="false"}
      assert html =~ "grid-rows-[0fr]"
      # invisible applies to the closed state; visible only when open
      content = content_class(html)
      assert content =~ "invisible"
      assert content =~ "data-[state=open]:visible"
    end

    test "default_open starts expanded" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings" default_open>
          Fields.
        </.collapsible_card_section>
        """)

      assert html =~ ~s{data-state="open"}
      assert html =~ ~s{aria-expanded="true"}
    end

    test "the height animates over 100ms with visibility folded into the transition" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings">Fields.</.collapsible_card_section>
        """)

      content = content_class(html)

      assert content =~ "transition-[grid-template-rows,visibility]"
      assert content =~ "duration-100"
      assert content =~ "ease-out"
      assert content =~ "data-[state=open]:grid-rows-[1fr]"
      # pb-px + overflow-y:clip keep child borders/shadows from being clipped
      assert content =~ "pb-px"
      assert content =~ "[overflow-y:clip]"
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings">Fields.</.collapsible_card_section>
        """)

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook toggles data-state and aria-expanded client-side" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings">Fields.</.collapsible_card_section>
        """)

      assert html =~ "addEventListener(\"click\""
      assert html =~ "dataset.state = open ? \"open\" : \"closed\""
      assert html =~ "setAttribute(\"aria-expanded\", String(open))"
      assert html =~ "updated()"
    end
  end

  describe "accessibility" do
    test "the trigger is a labeled button controlling the content region" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings">Fields.</.collapsible_card_section>
        """)

      assert html =~ ~s{type="button"}
      assert html =~ ~s{aria-controls="a-content"}
      assert html =~ ~s{aria-expanded="false"}
      # the heading is purely visual — never a heading element
      refute html =~ "<h1"
      refute html =~ "<h2"
      refute html =~ "<h3"
    end

    test "the trigger carries a visible focus ring (an improvement over the original)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings">Fields.</.collapsible_card_section>
        """)

      trigger = trigger_class(html)

      assert trigger =~ "focus-visible:ring-2"
      assert trigger =~ "focus-visible:ring-brand-emerald"
      assert trigger =~ "focus-visible:ring-offset-2"
    end
  end

  describe "attributes and events" do
    test "forwards global attributes and phx events via rest" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section
          id="a"
          title="Advanced settings"
          data-testid="advanced"
          phx-click="track"
        >
          Fields.
        </.collapsible_card_section>
        """)

      assert html =~ ~s{data-testid="advanced"}
      assert html =~ ~s{phx-click="track"}
    end

    test "caller classes merge onto the root through cn/1" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings" class="mt-4">
          Fields.
        </.collapsible_card_section>
        """)

      root = root_class(html)
      assert root =~ "mt-4"
      assert root =~ "relative"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.collapsible_card_section id="a" title="Advanced settings" description="Qualifier">
          Fields.
        </.collapsible_card_section>
        """)

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

  # The class attribute of the root wrapper (first class= in the output).
  defp root_class(html) do
    [_, class | _] = String.split(html, ~s{class="}, parts: 2)
    class |> String.split(~s{"}) |> List.first()
  end

  # The class attribute of the trigger button (the button tag's class=).
  defp trigger_class(html) do
    [_, rest] = String.split(html, "<button", parts: 2)
    [_, class | _] = String.split(rest, ~s{class="}, parts: 2)
    class |> String.split(~s{"}) |> List.first()
  end

  # The class attribute of the collapsing content region — the marker sits at
  # the end of its opening tag, so its class is the last one before the marker.
  defp content_class(html) do
    [before_marker | _] = String.split(html, "data-polaris-collapsible-content", parts: 2)

    before_marker
    |> String.split(~s{class="})
    |> Enum.at(-1)
    |> String.split(~s{"})
    |> List.first()
  end
end
