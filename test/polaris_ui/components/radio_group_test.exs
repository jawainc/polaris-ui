defmodule PolarisUI.Components.RadioGroupTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.RadioGroup` — the port
  of the Supabase design system RadioGroup family: the base circle
  group, the card tiles, the stacked segmented list, the hidden form
  input, and the colocated runtime hook owning the roving radio state
  machine.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.RadioGroup

  @hook "PolarisUI.Components.RadioGroup.Root"

  defp render_group(assigns) do
    assigns =
      Map.merge(
        %{
          id: "plan",
          name: nil,
          value: nil,
          on_change: nil,
          class: nil,
          rest: %{},
          pro_checked: false,
          free_checked: false
        },
        assigns
      )

    rendered_to_string(~H"""
    <.radio_group id={@id} name={@name} value={@value} on_change={@on_change} class={@class} {@rest}>
      <.radio_group_item value="pro" id="plan-pro" checked={@pro_checked}>Pro</.radio_group_item>
      <.radio_group_item value="free" id="plan-free" checked={@free_checked}>Free</.radio_group_item>
    </.radio_group>
    """)
  end

  describe "root anatomy" do
    test "renders the radiogroup landmark anchored by the hook" do
      html = render_group(%{})

      assert html =~ ~s{id="plan"}
      assert html =~ ~s{role="radiogroup"}
      assert html =~ ~s{data-polaris-radio-group}
      assert html =~ ~s{phx-hook="#{@hook}"}
    end

    test "the base group uses the source grid container" do
      html = render_group(%{})

      assert class_of(html, "data-polaris-radio-group") =~ "relative grid gap-2"
    end

    test "the stacked group joins segments with the source container" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.radio_group_stacked id="density">
          <.radio_group_stacked_item value="compact" label="Compact" />
        </.radio_group_stacked>
        """)

      class = class_of(html, "data-polaris-radio-group")
      assert class =~ "relative flex w-full flex-col"
      assert class =~ "-space-y-px"
    end

    test "caller classes merge onto the group" do
      html = render_group(%{class: "flex flex-wrap gap-3"})

      assert class_of(html, "data-polaris-radio-group") =~ "flex flex-wrap gap-3"
    end

    test "globals forward through rest" do
      html = render_group(%{rest: %{"aria-label" => "Billing plan", "data-testid" => "plan"}})

      assert html =~ ~s{aria-label="Billing plan"}
      assert html =~ ~s{data-testid="plan"}
    end
  end

  describe "base item anatomy" do
    test "renders the radio circle with the source treatment" do
      html = render_group(%{})

      assert html =~ ~s{data-polaris-radio-group-item}
      assert html =~ ~s{role="radio"}
      assert html =~ ~s{aria-checked="false"}
      assert html =~ ~s{data-state="unchecked"}
      assert html =~ ~s{data-value="pro"}

      class = item_class(html, "plan-pro")
      assert class =~ "relative aspect-square h-4 w-4 shrink-0"
      assert class =~ "cursor-pointer rounded-full border"
      assert class =~ "border-brand-border hover:border-brand-border-hover"
      assert class =~ "transition-colors duration-150 ease-in-out"
    end

    test "the dot cross-fades in when checked" do
      html = render_group(%{pro_checked: true})

      assert html =~ ~s{<circle cx="12" cy="12" r="10">}

      chunk = indicator_chunk(html)
      assert chunk =~ "size-2.5 fill-current"
      assert chunk =~ "opacity-0 transition-opacity"
      assert chunk =~ "group-data-[state=checked]:opacity-100"
    end

    test "the label wires to the circle via id" do
      html = render_group(%{})

      assert html =~ ~s{<label for="plan-pro" id="plan-pro-label"}
      assert item_chunk(html, "plan-pro") =~ ~s{aria-labelledby="plan-pro-label"}
      assert html =~ "Pro"
    end

    test "without an id the label renders unwired" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.radio_group id="bare">
          <.radio_group_item value="x">Bare option</.radio_group_item>
        </.radio_group>
        """)

      refute html =~ "<label"
      assert html =~ "Bare option"
    end
  end

  describe "checked state" do
    test "checked paints the SSR state with the emerald border" do
      html = render_group(%{pro_checked: true})

      chunk = item_chunk(html, "plan-pro")
      assert chunk =~ ~s{aria-checked="true"}
      assert chunk =~ ~s{data-state="checked"}
      assert chunk =~ ~s{data-checked="true"}

      class = item_class(html, "plan-pro")
      assert class =~ "data-[state=checked]:border-brand-emerald"
      assert class =~ "data-[state=checked]:text-brand-emerald"
    end

    test "checked takes the tab stop (the roving model)" do
      html = render_group(%{pro_checked: true})

      assert item_chunk(html, "plan-pro") =~ ~s{tabindex="0"}
      assert item_chunk(html, "plan-free") =~ ~s{tabindex="-1"}
    end

    test "unchecked items seed out of the tab order until the hook mounts" do
      html = render_group(%{})

      assert item_chunk(html, "plan-pro") =~ ~s{tabindex="-1"}
    end
  end

  describe "disabled state" do
    test "disabled locks the item and drops it from the tab order" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.radio_group id="plan">
          <.radio_group_item value="legacy" id="plan-legacy" disabled>Legacy</.radio_group_item>
        </.radio_group>
        """)

      chunk = item_chunk(html, "plan-legacy")
      assert chunk =~ " disabled"
      assert chunk =~ ~s{tabindex="-1"}
      assert chunk =~ ~s{data-disabled="true"}

      assert item_class(html, "plan-legacy") =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end

    test "the label dims through the peer relationship" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.radio_group id="plan">
          <.radio_group_item value="legacy" id="plan-legacy" disabled>Legacy</.radio_group_item>
        </.radio_group>
        """)

      assert html =~ "peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
    end
  end

  describe "focus ring" do
    test "every family carries the shared emerald focus ring" do
      base = render_group(%{})

      assert item_class(base, "plan-pro") =~
               "focus-visible:ring-2 focus-visible:ring-brand-emerald"

      assigns = %{}

      card =
        rendered_to_string(~H"""
        <.radio_group_card id="themes">
          <.radio_group_card_item value="dark" label="Dark" />
        </.radio_group_card>
        """)

      assert class_of(card, "data-polaris-radio-group-item") =~
               "focus-visible:ring-2 focus-visible:ring-brand-emerald"

      stacked =
        rendered_to_string(~H"""
        <.radio_group_stacked id="density">
          <.radio_group_stacked_item value="compact" label="Compact" />
        </.radio_group_stacked>
        """)

      assert class_of(stacked, "data-polaris-radio-group-item") =~
               "focus-visible:ring-2 focus-visible:ring-brand-emerald"
    end
  end

  describe "card family" do
    test "renders the w-48 tile with the label row" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.radio_group_card id="themes" value="dark">
          <.radio_group_card_item value="dark" label="Dark" checked>
            <img src="/themes/dark.svg" alt="" />
          </.radio_group_card_item>
        </.radio_group_card>
        """)

      class = class_of(html, "data-polaris-radio-group-item")

      assert class =~
               "flex w-48 flex-col gap-2 rounded-md border border-surface-border bg-surface-panel p-2"

      assert class =~ "hover:border-surface-border-hover"
      assert class =~ "data-[state=checked]:border-surface-border-hover"

      assert html =~ ~s{aria-label="Dark"}
      assert html =~ "Dark"
      assert html =~ ~s{src="/themes/dark.svg"}
      assert html =~ ~s{aria-checked="true"}
    end

    test "show_indicator drops the circle" do
      assigns = %{}

      with_indicator =
        rendered_to_string(~H"""
        <.radio_group_card id="t"><.radio_group_card_item value="a" label="A" /></.radio_group_card>
        """)

      without_indicator =
        rendered_to_string(~H"""
        <.radio_group_card id="t">
          <.radio_group_card_item value="a" label="A" show_indicator={false} />
        </.radio_group_card>
        """)

      assert with_indicator |> String.split("data-polaris-radio-indicator") |> length() >
               without_indicator |> String.split("data-polaris-radio-indicator") |> length()
    end
  end

  describe "stacked family" do
    test "renders the joined segment with label and description" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.radio_group_stacked id="density" value="comfortable">
          <.radio_group_stacked_item
            value="compact"
            label="Compact"
            description="The most space-efficient layout."
          />
          <.radio_group_stacked_item
            value="comfortable"
            label="Comfortable"
            checked
            description="Balanced density for tables."
          />
        </.radio_group_stacked>
        """)

      class = class_of(html, "data-polaris-radio-group-item")

      assert class =~
               "flex w-full flex-col gap-2 border border-surface-border bg-surface-panel/50"

      assert class =~ "first-of-type:rounded-t-lg last-of-type:rounded-b-lg"

      assert class =~
               "enabled:hover:border-surface-border-hover enabled:hover:bg-surface-panel-hover"

      assert class =~
               "data-[state=checked]:border-surface-border-hover data-[state=checked]:bg-surface-panel-hover"

      assert class =~ "first-of-type:rounded-t-lg"

      assert html =~ "The most space-efficient layout."
      assert html =~ "Balanced density for tables."
      assert html =~ ~s{aria-checked="true"}
    end

    test "the description drops cleanly" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.radio_group_stacked id="density">
          <.radio_group_stacked_item value="compact" label="Compact" />
        </.radio_group_stacked>
        """)

      refute html =~ "text-balance"
    end
  end

  describe "form participation" do
    test "with name, renders the hidden input seeded with the value" do
      html = render_group(%{name: "plan", value: "pro"})

      assert html =~ ~s{<input type="hidden" name="plan" value="pro"}
      assert html =~ ~s{data-polaris-radio-input}
    end

    test "without name, no hidden input renders" do
      html = render_group(%{})

      refute html =~ ~s{type="hidden"}
    end

    test "the root carries the value seed for the hook" do
      html = render_group(%{value: "pro"})

      assert html =~ ~s{data-polaris-radio-group data-value="pro"}
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_group(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "seeds selection from item data-checked, falling back to the root value" do
      html = render_group(%{})

      assert html =~
               ~s{const seeded = root.querySelector('[data-polaris-radio-group-item][data-checked="true"]')}

      assert html =~ "this._value = seeded ? seeded.dataset.value : root.dataset.value || null"
    end

    test "applies roving tabindex with one tab stop" do
      html = render_group(%{})

      assert html =~ ~s{el.tabIndex = el === tabstop ? 0 : -1}
    end

    test "radios never uncheck — selection only fires on change" do
      html = render_group(%{})

      assert html =~ "if (item.dataset.value !== this._value) {"
    end

    test "arrows and Home/End check siblings, wrapping" do
      html = render_group(%{})

      assert html =~ ~s{event.key === "ArrowDown" || event.key === "ArrowRight"}
      assert html =~ "move((index + 1) % enabled.length)"
      assert html =~ "move((index - 1 + enabled.length) % enabled.length)"
      assert html =~ ~s{event.key === "Home"}
      assert html =~ ~s{event.key === "End"}
    end

    test "syncs the hidden input and bubbles input/change" do
      html = render_group(%{})

      assert html =~ ~s[input.value = this._value == null ? "" : this._value]
      assert html =~ ~s[new Event("input", { bubbles: true })]
      assert html =~ ~s[new Event("change", { bubbles: true })]
    end

    test "pushes the on_change event when configured" do
      html = render_group(%{on_change: "pick-plan"})

      assert html =~ ~s{data-change-event="pick-plan"}
      assert html =~ ~s[pushEvent(name, { value: this._value })]
    end

    test "no data-change-event attribute without on_change" do
      html = render_group(%{})

      refute html =~ "data-change-event"
    end

    test "re-applies state after LiveView patches" do
      html = render_group(%{})

      assert html =~ "updated()"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.radio_group_stacked id="density">
          <.radio_group_stacked_item value="compact" label="Compact" description="Tight rows." />
        </.radio_group_stacked>
        """)

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp item_chunk(html, id) do
    [_, rest | _] = String.split(html, ~s{id="#{id}"}, parts: 2)
    String.split(rest, ">") |> Enum.at(0)
  end

  defp item_class(html, id) do
    item_chunk(html, id)
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp indicator_chunk(html) do
    [_, rest | _] = String.split(html, "data-polaris-radio-indicator", parts: 2)
    String.slice(rest, 0, 400)
  end

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

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
