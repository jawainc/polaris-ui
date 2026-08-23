defmodule PolarisUI.Components.ComboboxTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Combobox` — the port
  of the Supabase design system Combobox (the Popover + Command + Button
  composition): a single-select trigger opening a searchable list
  popover with check-marked items.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Combobox

  @hook "PolarisUI.Components.Combobox.Select"

  @frameworks [
    %{value: "next.js", label: "Next.js"},
    %{value: "sveltekit", label: "SvelteKit", disabled: true},
    %{value: "remix", label: "Remix", description: "v2"}
  ]

  defp render_combobox(assigns) do
    assigns =
      Map.merge(
        %{
          id: "framework",
          options: @frameworks,
          value: nil,
          on_change: "pick-framework",
          name: nil,
          disabled: false,
          placeholder: "Select framework...",
          search_placeholder: "Search framework...",
          empty_label: "No framework found.",
          class: nil,
          popover_class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.combobox
      id={@id}
      options={@options}
      value={@value}
      on_change={@on_change}
      name={@name}
      disabled={@disabled}
      placeholder={@placeholder}
      search_placeholder={@search_placeholder}
      empty_label={@empty_label}
      class={@class}
      popover_class={@popover_class}
      {assigns[:rest]}
    />
    """)
  end

  describe "trigger" do
    test "renders the placeholder in muted text when nothing is selected" do
      html = render_combobox(%{})

      assert html =~ "Select framework..."
      assert html =~ "text-content-muted font-normal"
    end

    test "renders the selected option's label" do
      html = render_combobox(%{value: "remix"})

      assert html =~ "Remix"
    end

    test "an unknown value still renders (raw-value fallback)" do
      html = render_combobox(%{value: "gatsby"})

      assert html =~ "gatsby"
    end

    test "carries combobox semantics wired to the listbox" do
      html = render_combobox(%{})

      assert html =~ ~s{role="combobox"}
      assert html =~ ~s{aria-expanded="false"}
      assert html =~ ~s{aria-haspopup="listbox"}
      assert html =~ ~s{aria-controls="framework-listbox"}
      assert html =~ "data-polaris-combobox-trigger"
    end

    test "sizes to the demo width with the glyph closing it out" do
      html = render_combobox(%{})

      assert html =~ "w-[200px] justify-between"
      assert html =~ "opacity-50"
    end

    test "disabled locks the trigger" do
      html = render_combobox(%{disabled: true})

      assert html =~ " disabled"
    end

    test "caller classes merge onto the trigger" do
      html = render_combobox(%{class: "w-full"})

      assert html =~ "w-full"
    end
  end

  describe "form field" do
    test "name renders a hidden input carrying the value" do
      html = render_combobox(%{name: "framework", value: "remix"})

      assert html =~ ~s{type="hidden" name="framework" value="remix"}
    end
  end

  describe "popover" do
    test "ships hidden with the Command search row" do
      html = render_combobox(%{})

      assert html =~ ~s{data-polaris-combobox-popover}
      assert html =~ "hidden"
      assert html =~ "flex items-center border-b border-surface-border px-4"
      assert html =~ ~s{placeholder="Search framework..."}
      assert html =~ ~s{id="framework-search"}
    end

    test "options render with listbox semantics and check glyphs" do
      html = render_combobox(%{})

      assert html =~ ~s{id="framework-option-0"}
      assert html =~ ~s{role="option"}
      assert html =~ "Next.js"
      assert html =~ "mr-2 size-4 shrink-0"
    end

    test "the selected option's check is fully opaque, others transparent" do
      html = render_combobox(%{value: "next.js"})

      assert html =~ ~s{data-selected="true"}
      assert html =~ ~s{aria-selected="true"}
      assert html =~ "opacity-100"
      assert html =~ "opacity-0"
    end

    test "disabled options are inert" do
      html = render_combobox(%{})

      assert html =~ ~s{data-disabled="true"}
      assert html =~ "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
    end

    test "descriptions render muted next to the label" do
      html = render_combobox(%{})

      assert html =~ "v2"
      assert html =~ "text-content-muted"
    end

    test "the empty state ships hidden" do
      html = render_combobox(%{})

      assert html =~ ~s{data-polaris-combobox-empty}
      assert html =~ "No framework found."
      assert html =~ "hidden"
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook and ships its script inline" do
      html = render_combobox(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
      assert html =~ ~s{data-change-event="pick-framework"}
    end

    test "selection pushes on_change; re-picking the value clears it" do
      html = render_combobox(%{})

      assert html =~ "pushEvent"
      assert html =~ "dataset.selected === \"true\""
      assert html =~ "push(cleared ? \"\" : option.dataset.value)"
    end

    test "filters value plus label and reconciles the empty state" do
      html = render_combobox(%{})

      assert html =~ "_filter()"
      assert html =~ "dataset.label"
      assert html =~ "data-polaris-combobox-empty"
    end

    test "keyboard: arrows cycle, Enter picks, Escape closes and refocuses" do
      html = render_combobox(%{})

      assert html =~ "ArrowDown"
      assert html =~ "ArrowUp"
      assert html =~ "Enter"
      assert html =~ "Escape"
      assert html =~ "t.focus()"
    end

    test "click-outside closes" do
      html = render_combobox(%{})

      assert html =~ "root.contains(event.target)"
    end
  end

  describe "validation" do
    test "rejects options without a :value key" do
      assert_raise ArgumentError, ~r/:value/, fn ->
        render_combobox(%{options: [%{label: "Nope"}]})
      end
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_combobox(%{value: "next.js"})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
