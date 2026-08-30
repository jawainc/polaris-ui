defmodule PolarisUI.Components.SelectTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Select` — the port of
  the Supabase design system Select (shadcn over Radix): the trigger
  with its size scale and chevron, the listbox popup with grouped
  options and the circle check indicator, the hidden form input, and
  the colocated hook's open/close/select contract.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Select

  @hook "PolarisUI.Components.Select.Root"

  @grouped_options [
    %{group: "Fruits", value: "apple", label: "Apple"},
    %{group: "Fruits", value: "banana", label: "Banana"},
    %{group: "Vegetables", value: "carrot", label: "Carrot", disabled: true}
  ]

  defp render_select(assigns) do
    assigns =
      Map.merge(
        %{
          id: "fruit",
          options: @grouped_options,
          value: nil,
          placeholder: "Select a fruit",
          name: nil,
          on_change: nil,
          size: "small",
          side: "bottom",
          align: "center",
          side_offset: 4,
          disabled: false,
          loading: false,
          class: nil,
          trigger_class: nil,
          content_class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.select
      id={@id}
      options={@options}
      value={@value}
      placeholder={@placeholder}
      name={@name}
      on_change={@on_change}
      size={@size}
      side={@side}
      align={@align}
      side_offset={@side_offset}
      disabled={@disabled}
      loading={@loading}
      class={@class}
      trigger_class={@trigger_class}
      content_class={@content_class}
      {@rest}
    />
    """)
  end

  describe "trigger anatomy" do
    test "renders the combobox trigger anchored by the hook" do
      html = render_select(%{})

      assert html =~ ~s{id="fruit-trigger"}
      assert html =~ ~s{data-polaris-select-trigger}
      assert html =~ ~s{role="combobox"}
      assert html =~ ~s{aria-haspopup="listbox"}
      assert html =~ ~s{aria-expanded="false"}
      assert html =~ ~s{aria-controls="fruit-listbox"}
      assert html =~ ~s{phx-hook="#{@hook}"}
    end

    test "carries the source's trigger treatment" do
      html = render_select(%{})

      class = trigger_class(html)
      assert class =~ "flex w-full items-center justify-between gap-2 rounded-md border"
      assert class =~ "bg-surface-panel"
      assert class =~ "border-surface-border"
      assert class =~ "text-left"
      assert class =~ "transition-colors duration-200"

      assert class =~
               "hover:border-surface-border-hover data-[state=open]:border-surface-border-hover"

      assert class =~ "data-[placeholder]:text-content-secondary"
      assert class =~ "[&amp;&gt;span]:truncate"
    end

    test "the chevron is the source's 1.5-stroke glyph" do
      html = render_select(%{})

      assert html =~ ~s{stroke-width="1.5"}
      assert html =~ ~s{d="m6 9 6 6 6-6"}
      assert html =~ "size-4 shrink-0 text-content-secondary"
    end

    test "placeholder paints while nothing is selected" do
      html = render_select(%{})

      assert html =~ ~s{data-placeholder="true"}
      assert html =~ "Select a fruit"
    end

    test "the selected option's label resolves server-side" do
      html = render_select(%{value: "banana"})

      assert html =~ ~s{data-state="checked"}
      assert html =~ "Banana"
      refute html =~ ~s{data-placeholder="true"}
    end
  end

  describe "size scale" do
    test "small is the default (the source's SIZE_VARIANTS_DEFAULT)" do
      html = render_select(%{})

      class = trigger_class(html)
      assert class =~ "text-base md:text-sm leading-4 px-3 py-2 h-[34px]"
    end

    test "each size resolves its exact class string" do
      assert trigger_class(render_select(%{size: "tiny"})) =~ "text-xs px-2.5 py-1 h-[26px]"

      assert trigger_class(render_select(%{size: "medium"})) =~
               "text-base md:text-sm px-4 py-2 h-[38px]"

      assert trigger_class(render_select(%{size: "large"})) =~ "text-base px-4 py-2 h-[42px]"
      assert trigger_class(render_select(%{size: "xlarge"})) =~ "text-base px-6 py-3 h-[50px]"
    end

    test "rejects unknown sizes at render time" do
      assert_raise ArgumentError, ~r/invalid value for :size/, fn ->
        render_select(%{size: "giant"})
      end
    end

    test "caller width narrows the wrapper (the docs' w-[180px] trigger)" do
      html = render_select(%{class: "w-[180px]"})

      assert root_class(html) =~ "w-[180px]"
    end
  end

  describe "listbox anatomy" do
    test "renders the hidden listbox popup with the source's treatment" do
      html = render_select(%{})

      assert html =~ ~s{id="fruit-listbox"}
      assert html =~ ~s{role="listbox"}
      assert html =~ ~s{hidden}

      class = content_class(html)
      assert class =~ "fixed z-50 min-w-32 max-h-96 overflow-hidden rounded-md border"
      assert class =~ "bg-surface-panel text-content-primary shadow-md"
    end

    test "options render as aria options carrying their data" do
      html = render_select(%{})

      assert html =~ ~s{id="fruit-option-apple"}
      assert html =~ ~s{role="option"}
      assert html =~ ~s{data-polaris-select-item}
      assert html =~ ~s{data-value="apple" data-label="Apple"}
      assert html =~ ~s{data-state="unchecked"}
    end

    test "the selected option paints checked" do
      html = render_select(%{value: "apple"})

      assert html =~ ~s{aria-selected="true"}
      assert html =~ ~s{data-state="checked"}
      assert html =~ ~s{data-polaris-select-item-indicator}
    end

    test "the indicator is the filled circle with the knocked-out check" do
      html = render_select(%{value: "apple"})

      assert html =~ "h-3.5 w-3.5 items-center justify-center rounded-full bg-content-primary"
      assert html =~ ~s{stroke-width="6"}
      assert html =~ "size-2 text-surface-panel"
    end

    test "the indicator slot is reserved for unchecked items (the pl-8 alignment)" do
      html = render_select(%{})

      item = item_class(html)
      assert item =~ "py-1.5 pl-8 pr-2 text-sm"
      assert html =~ "absolute left-2 flex h-3.5 w-3.5 items-center justify-center"
    end

    test "grouped options render under the source's uppercase mono label" do
      html = render_select(%{})

      assert html =~ ~s{data-polaris-select-group}
      assert html =~ "Fruits"
      assert html =~ "Vegetables"

      label = group_class(html)
      assert label =~ "py-1.5 pl-8 pr-2 text-xs font-mono uppercase tracking-wider"
    end

    test "consecutive same-group options share one label run" do
      html = render_select(%{})

      assert occurrences(html, ~s{data-polaris-select-group}) == 2
    end

    test "a hairline separator divides consecutive groups" do
      html = render_select(%{})

      assert html =~ ~s{data-polaris-select-separator}
      sep = separator_class(html)
      assert sep =~ "-mx-1 my-1 h-px bg-surface-border"
      assert occurrences(html, ~s{data-polaris-select-separator}) == 1
    end

    test "string options are both value and label" do
      html = render_select(%{options: ["UTC", "CET"], value: "CET"})

      assert html =~ ~s{data-value="UTC" data-label="UTC"}
      assert html =~ "CET"
      refute html =~ ~s{data-polaris-select-group}
    end

    test "disabled options grey out and block activation" do
      html = render_select(%{})

      assert html =~ ~s{data-disabled="true"}
      assert html =~ ~s{aria-disabled="true"}

      item = item_class(html)
      assert item =~ "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    end

    test "the viewport carries the scroll chevron buttons" do
      html = render_select(%{})

      assert html =~ ~s{data-polaris-select-viewport}
      assert html =~ ~s{data-polaris-select-scroll-up}
      assert html =~ ~s{data-polaris-select-scroll-down}
      assert html =~ "flex cursor-default items-center justify-center py-1 text-content-muted"
    end
  end

  describe "form participation & events" do
    test "name renders the hidden input carrying the selection" do
      html = render_select(%{name: "fruit", value: "banana"})

      assert html =~ ~s{type="hidden" name="fruit" value="banana"}
      assert html =~ ~s{data-polaris-select-input}
    end

    test "without name there is no hidden input" do
      html = render_select(%{})

      refute html =~ ~s{type="hidden"}
    end

    test "on_change rides the data attribute the hook pushes" do
      html = render_select(%{on_change: "pick-fruit"})

      assert html =~ ~s{data-change-event="pick-fruit"}
      assert html =~ "pushEvent(name, { value: this._value })"
    end
  end

  describe "states" do
    test "disabled locks the trigger" do
      html = render_select(%{disabled: true})

      assert html =~ ~s{disabled}
      assert trigger_class(html) =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end

    test "loading swaps the chevron for the brand spinner and sets aria-busy" do
      html = render_select(%{loading: true})

      assert html =~ ~s{aria-busy="true"}
      assert html =~ ~s{disabled}
      assert html =~ "animate-spin text-brand-accent"
      # Only the (hidden) scroll buttons and spinner remain — no trigger chevron.
      refute html =~ ~s{stroke-width="1.5"}
    end

    test "focus ring is the shared emerald treatment" do
      html = render_select(%{})

      class = trigger_class(html)

      assert class =~
               "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"

      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_select(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "selection owns the trigger label, hidden input, and item paint" do
      html = render_select(%{})

      assert html =~ "t.removeAttribute(\"data-placeholder\")"

      assert html =~
               "valueSpan.textContent = label != null ? label : root.dataset.placeholderText || \"\""

      assert html =~ "el.dataset.state = checked ? \"checked\" : \"unchecked\""
    end

    test "selection bubbles input/change through the hidden input" do
      html = render_select(%{})

      assert html =~ "hidden.dispatchEvent(new Event(\"input\", { bubbles: true }))"
      assert html =~ "hidden.dispatchEvent(new Event(\"change\", { bubbles: true }))"
    end

    test "carries the keyboard contract: open, cycle, Home/End, pick, escape" do
      html = render_select(%{})

      assert html =~ ~s{["Enter", " ", "ArrowDown", "ArrowUp"].includes(event.key)}
      assert html =~ "items[(index + 1) % items.length]"
      assert html =~ "items[(index - 1 + items.length) % items.length]"
      assert html =~ ~s{event.key === "Home"}
      assert html =~ ~s{event.key === "End"}
      assert html =~ ~s{event.key === "Escape"}
      assert html =~ ~s{event.key === "Tab"}
    end

    test "ships typeahead jumping to matching labels" do
      html = render_select(%{})

      assert html =~ "this._typeahead += event.key.toLowerCase()"
      assert html =~ ".startsWith(this._typeahead)"
    end

    test "positions beside the trigger, pinned to its width, flipping on overflow" do
      html = render_select(%{})

      assert html =~ "c.style.minWidth = t.offsetWidth + \"px\""
      assert html =~ "place(side === \"bottom\" ? \"top\" : \"bottom\")"
    end

    test "open/close syncs aria-expanded and returns focus to the trigger" do
      html = render_select(%{})

      assert html =~ "t.setAttribute(\"aria-expanded\", \"true\")"
      assert html =~ "t.setAttribute(\"aria-expanded\", \"false\")"
      assert html =~ "this._previouslyFocused.focus()"
    end

    test "re-applies the hook-owned state after LiveView patches" do
      html = render_select(%{})

      assert html =~ "updated()"
      assert html =~ "this._apply()"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_select(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp occurrences(html, pattern), do: length(Regex.scan(~r{#{Regex.escape(pattern)}}, html))

  defp root_class(html), do: class_of(html, "data-polaris-select data-placeholder-text")

  defp trigger_class(html), do: class_of(html, "data-polaris-select-trigger")

  defp content_class(html), do: class_of(html, "data-polaris-select-content")

  defp item_class(html), do: class_of(html, "data-polaris-select-item")

  defp group_class(html), do: class_of(html, "data-polaris-select-group")

  defp separator_class(html), do: class_of(html, "data-polaris-select-separator")

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
