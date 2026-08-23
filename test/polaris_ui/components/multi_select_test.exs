defmodule PolarisUI.Components.MultiSelectTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.MultiSelect` — trigger
  anatomy, value badges and badge limits, modes, popover options,
  creatable, form inputs, states, and the colocated hook, mirroring the
  Supabase design system fragment `ui-patterns/MultiSelect` (badges in a
  combobox trigger, server-driven selection).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.MultiSelect

  @hook "PolarisUI.Components.MultiSelect.Select"

  @options [
    %{value: "Apple", label: "Apple"},
    %{value: "Banana", label: "Banana", description: "Yellow and seedless"},
    %{value: "Cherry", label: "Cherry"},
    %{value: "Kiwi", label: "Kiwi", disabled: true}
  ]

  describe "anatomy" do
    test "renders root, trigger, badges row, popover, list, and options" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={["Apple"]} on_change="toggle" />
        """)

      assert html =~ ~s{id="ms"}
      assert html =~ "data-polaris-multi-select"
      assert html =~ "data-polaris-multi-select-trigger"
      assert html =~ ~s{data-open="false"}
      assert html =~ "data-polaris-multi-select-badges"
      assert html =~ "data-polaris-multi-select-badge"
      assert html =~ ~s{id="ms-listbox"}
      assert html =~ "data-polaris-multi-select-popover"
      assert html =~ "data-polaris-multi-select-list"
      assert html =~ "data-polaris-multi-select-option"
    end

    test "the trigger is a labelled combobox pointing at the listbox" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" label="Select fruits" />
        """)

      assert html =~ ~s{role="combobox"}
      assert html =~ ~s{aria-expanded="false"}
      assert html =~ ~s{aria-haspopup="listbox"}
      assert html =~ ~s{aria-controls="ms-listbox"}
      assert html =~ ~s{aria-labelledby="ms-label"}
      assert html =~ ~s{id="ms-label"}
      assert html =~ "Select fruits"
    end

    test "option ids derive from id + index and labels and descriptions render" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      assert html =~ ~s{id="ms-option-0"}
      assert html =~ ~s{id="ms-option-1"}
      assert html =~ ~s{id="ms-option-3"}
      assert html =~ ~s{data-value="Banana"}
      assert html =~ ~s{data-label="Banana"}
      assert html =~ "Banana"
      assert html =~ "Yellow and seedless"
    end

    test "values render as badges with labels; unknown values render raw" do
      assigns = %{options: @options, values: ["Apple", "Durian"]}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={@values} on_change="toggle" />
        """)

      assert html =~ ~s{data-polaris-multi-select-badge data-value="Apple"}
      assert html =~ ~s{data-polaris-multi-select-badge-remove data-value="Apple"}
      assert html =~ ~s{aria-label="Remove Apple"}
      assert html =~ ~s{data-polaris-multi-select-badge data-value="Durian"}
      assert html =~ ~s{aria-label="Remove Durian"}
      badge = class_of(html, ~s{data-polaris-multi-select-badge data-value="Apple"})
      assert badge =~ "bg-surface-panel-hover"
      assert badge =~ "text-xs"
    end

    test "empty trigger renders the raised plate; filled renders the sunk well" do
      assigns = %{options: @options}

      empty =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      assert class_of(empty, "data-polaris-multi-select-trigger") =~ "bg-surface-panel"

      assigns = %{options: @options, values: ["Apple"]}

      filled =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={@values} on_change="toggle" />
        """)

      trigger = class_of(filled, "data-polaris-multi-select-trigger")

      assert trigger =~ "bg-surface-base"
      assert trigger =~ "min-h-[34px]"
      assert trigger =~ "min-w-[200px]"
      assert trigger =~ "hover:border-surface-border-hover"
      assert trigger =~ "focus-within:border-surface-border-hover"
      assert trigger =~ "focus-within:ring-2"
      assert trigger =~ "focus-within:ring-brand-emerald"
      assert trigger =~ "focus-within:ring-offset-surface-ground"
    end
  end

  describe "badge_limit" do
    test "the default renders every badge with no overflow badge" do
      assigns = %{options: @options, values: ["Apple", "Banana", "Cherry"]}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={@values} on_change="toggle" />
        """)

      assert html =~ ~s{data-polaris-multi-select-badge data-value="Cherry"}
      refute html =~ "data-polaris-multi-select-overflow"
      assert class_of(html, "data-polaris-multi-select-badges") =~ "overflow-x-auto"
    end

    test "an integer limit renders a +K overflow badge and hides extras" do
      assigns = %{options: @options, values: ["Apple", "Banana", "Cherry"]}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={@values} on_change="toggle" badge_limit={1} />
        """)

      assert html =~ ~s{data-polaris-multi-select-badge data-value="Apple"}
      refute html =~ ~s{data-polaris-multi-select-badge data-value="Banana"}
      assert html =~ "data-polaris-multi-select-overflow"
      assert html =~ "+2"
      assert class_of(html, "data-polaris-multi-select-overflow") =~ "bg-surface-panel-hover"
    end

    test ":wrap renders every badge wrapped with no overflow badge" do
      assigns = %{options: @options, values: ["Apple", "Banana", "Cherry"]}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={@values} on_change="toggle" badge_limit={:wrap} />
        """)

      assert class_of(html, "data-polaris-multi-select-badges") =~ "flex-wrap"
      assert html =~ ~s{data-polaris-multi-select-badge data-value="Cherry"}
      refute html =~ "data-polaris-multi-select-overflow"
    end

    test "a limit below 1 collapses to the N items selected form" do
      assigns = %{options: @options}

      plural =
        rendered_to_string(~H"""
        <.multi_select
          id="ms"
          options={@options}
          values={["Apple", "Banana"]}
          on_change="toggle"
          badge_limit={0}
        />
        """)

      assert plural =~ "2 items selected"
      refute plural =~ "+2"

      singular =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={["Apple"]} on_change="toggle" badge_limit={0} />
        """)

      assert singular =~ "1 item selected"
      refute singular =~ "1 item selecteds"
    end

    test "an invalid badge_limit raises a clear error" do
      assigns = %{options: @options}

      assert_raise ArgumentError, ~r/invalid value for :badge_limit/, fn ->
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" badge_limit="3" />
        """)
      end
    end

    test "an invalid mode raises a clear error" do
      assigns = %{options: @options}

      assert_raise ArgumentError, ~r/invalid value for :mode/, fn ->
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" mode="inline" />
        """)
      end
    end
  end

  describe "trigger flags" do
    test "deletable_badge false drops the remove affordances" do
      assigns = %{options: @options, values: ["Apple"]}

      html =
        rendered_to_string(~H"""
        <.multi_select
          id="ms"
          options={@options}
          values={@values}
          on_change="toggle"
          deletable_badge={false}
        />
        """)

      assert html =~ ~s{data-polaris-multi-select-badge data-value="Apple"}
      refute html =~ "data-polaris-multi-select-badge-remove data-value"
    end

    test "show_icon false drops the chevrons glyph" do
      assigns = %{options: @options}

      with_icon =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      assert with_icon =~ "m7 15 5 5 5-5"

      without_icon =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" show_icon={false} />
        """)

      refute without_icon =~ "m7 15 5 5 5-5"
    end

    test "persist_label keeps the label visible beside badges" do
      assigns = %{options: @options, values: ["Apple"]}

      persisting =
        rendered_to_string(~H"""
        <.multi_select
          id="ms"
          options={@options}
          values={@values}
          on_change="toggle"
          label="Select fruits"
          persist_label
        />
        """)

      label = class_of(persisting, ~s{id="ms-label"})
      assert label =~ "inline opacity-100"
      assert label =~ "text-content-muted"

      hiding =
        rendered_to_string(~H"""
        <.multi_select
          id="ms"
          options={@options}
          values={@values}
          on_change="toggle"
          label="Select fruits"
        />
        """)

      assert class_of(hiding, ~s{id="ms-label"}) =~ "hidden opacity-0"
    end

    test "the label shows when there are no values" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" label="Select fruits" />
        """)

      assert class_of(html, ~s{id="ms-label"}) =~ "inline opacity-100"
    end
  end

  describe "modes" do
    test "inline-combobox renders the input inside the trigger with the label as placeholder" do
      assigns = %{options: @options, values: ["Apple"]}

      html =
        rendered_to_string(~H"""
        <.multi_select
          id="ms"
          options={@options}
          values={@values}
          on_change="toggle"
          mode="inline-combobox"
          label="Select fruits"
        />
        """)

      assert html =~ "data-polaris-multi-select-input"
      assert html =~ ~s{placeholder="Select fruits"}
      assert html =~ ~s{data-mode="inline-combobox"}
      refute html =~ "data-polaris-multi-select-search"
      refute html =~ ~s{id="ms-search"}
    end

    test "combobox mode renders the search row in the popover" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      assert html =~ "data-polaris-multi-select-search"
      assert html =~ ~s{id="ms-search"}
      assert html =~ ~s{placeholder="Search"}
      assert html =~ ~s{data-mode="combobox"}

      custom =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" placeholder="Search fruits" />
        """)

      assert custom =~ ~s{placeholder="Search fruits"}
    end
  end

  describe "disabled states" do
    test "disabled greys out the trigger" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" disabled />
        """)

      assert html =~ "disabled data-polaris-multi-select-trigger"
      assert class_of(html, "data-polaris-multi-select-trigger") =~ "disabled:opacity-50"
      assert class_of(html, "data-polaris-multi-select-trigger") =~ "disabled:cursor-not-allowed"

      enabled =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      refute enabled =~ "disabled data-polaris-multi-select-trigger"
    end

    test "disabled options are marked and inert" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      assert Regex.match?(~r{id="ms-option-3"[^>]*aria-disabled="true"}, html)
      assert Regex.match?(~r{id="ms-option-3"[^>]*data-disabled="true"}, html)
      assert class_of(html, ~s{id="ms-option-3"}) =~ "pointer-events-none"
      assert class_of(html, ~s{id="ms-option-3"}) =~ "opacity-50"
      refute class_of(html, ~s{id="ms-option-0"}) =~ "pointer-events-none"
    end
  end

  describe "form inputs" do
    test "renders one hidden input per value when name is set" do
      assigns = %{options: @options, values: ["Apple", "Cherry"]}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" name="fruits" options={@options} values={@values} on_change="toggle" />
        """)

      assert html =~ ~s{type="hidden"}
      assert html =~ ~s{name="fruits[]"}
      assert html =~ ~s{name="fruits[]" value="Apple"}
      assert html =~ ~s{name="fruits[]" value="Cherry"}
      assert html =~ "data-polaris-multi-select-hidden"
      assert hidden_input_count(html) == 2
    end

    test "no hidden inputs without a name" do
      assigns = %{options: @options, values: ["Apple"]}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={@values} on_change="toggle" />
        """)

      refute html =~ "data-polaris-multi-select-hidden"
    end
  end

  describe "popover" do
    test "the popover is a multiselectable listbox, hidden until the hook opens it" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      assert html =~ ~s{role="listbox"}
      assert html =~ ~s{aria-multiselectable="true"}
      popover = class_of(html, "data-polaris-multi-select-popover")
      assert popover =~ "hidden"
      assert popover =~ "absolute"
      assert popover =~ "border-surface-border"
      assert popover =~ "bg-surface-panel"
      assert popover =~ "shadow-lg"
    end

    test "selected options carry aria-selected and data-selected" do
      assigns = %{options: @options, values: ["Apple"]}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={@values} on_change="toggle" />
        """)

      assert Regex.match?(
               ~r{id="ms-option-0"[^>]*aria-selected="true"[^>]*data-selected="true"},
               html
             )

      assert Regex.match?(
               ~r{id="ms-option-1"[^>]*aria-selected="false"[^>]*data-selected="false"},
               html
             )
    end

    test "the checkbox fills and the check renders only for selected options" do
      assigns = %{options: @options, values: ["Apple"]}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} values={@values} on_change="toggle" />
        """)

      assert html =~ "border-content-primary bg-content-primary text-surface-ground"
      assert html =~ ~s{d="M20 6 9 17l-5-5"}
      assert check_count(html) == 1

      assert html =~ "border-surface-border"
    end

    test "the creatable item renders hidden and only when enabled" do
      assigns = %{options: @options}

      without =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      refute without =~ ~s{Create "}
      refute without =~ "data-polaris-multi-select-create-label></span>"

      with_creatable =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" creatable />
        """)

      assert with_creatable =~ "data-polaris-multi-select-create"
      assert with_creatable =~ "data-polaris-multi-select-create-label"
      assert with_creatable =~ ~s{Create "}

      assert Regex.match?(
               ~r{<div[^>]*data-polaris-multi-select-create[^>]*?hidden[^>]*>},
               with_creatable
             )
    end

    test "the empty state renders hidden with its label" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      assert html =~ "data-polaris-multi-select-empty"
      assert html =~ "No results found"
      assert class_of(html, "data-polaris-multi-select-empty") =~ "hidden"

      custom =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" empty_label="Nothing matches" />
        """)

      assert custom =~ "Nothing matches"
    end
  end

  describe "class merging" do
    test "trigger class, popover class, and root globals pass through" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select
          id="ms"
          options={@options}
          on_change="toggle"
          class="w-72"
          popover_class="max-h-96"
          data-track="x"
        />
        """)

      assert class_of(html, "data-polaris-multi-select-trigger") =~ "w-72"
      assert class_of(html, "data-polaris-multi-select-popover") =~ "max-h-96"
      assert html =~ ~s{data-track="x"}
    end
  end

  describe "hook" do
    test "attaches the colocated runtime hook with its event wiring" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" on_create="create" creatable />
        """)

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-change-event="toggle"}
      assert html =~ ~s{data-create-event="create"}
      assert html =~ ~s{data-creatable="true"}
      assert html =~ ~s{data-mode="combobox"}
      assert html =~ "<script"
    end

    test "creatable defaults to false" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      assert html =~ ~s{data-creatable="false"}
    end

    test "the hook owns open/close, filtering, keyboard navigation, and backspace" do
      assigns = %{options: @options}

      html =
        rendered_to_string(~H"""
        <.multi_select id="ms" options={@options} on_change="toggle" />
        """)

      assert html =~ ~s/"ArrowDown"/
      assert html =~ ~s/"ArrowUp"/
      assert html =~ ~s/"Backspace"/
      assert html =~ ~s/"Escape"/
      assert html =~ "pushEvent("
      assert html =~ ".closest("
      assert html =~ ~s/document.addEventListener("click"/
      assert html =~ "scrollIntoView"
      assert html =~ "destroyed()"
    end
  end

  defp hidden_input_count(html) do
    html |> String.split("data-polaris-multi-select-hidden") |> length() |> Kernel.-(1)
  end

  defp check_count(html) do
    html |> String.split(~s{d="M20 6 9 17l-5-5"}) |> length() |> Kernel.-(1)
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
end
