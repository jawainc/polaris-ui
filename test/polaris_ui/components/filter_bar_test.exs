defmodule PolarisUI.Components.FilterBarTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.FilterBar` — bar
  anatomy, condition chips, variants, placeholder microcopy, event
  wiring, states, and the colocated hook, mirroring the Supabase design
  system fragment `ui-patterns/FilterBar` (chips in a freeform search
  bar, server-driven).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.FilterBar

  @hook "PolarisUI.Components.FilterBar.Bar"

  @properties [
    %{name: "name", label: "Name", type: "string", operators: ["=", "!="]},
    %{
      name: "status",
      label: "Status",
      type: "string",
      operators: ["=", "!="],
      options: ["active", "inactive"]
    },
    %{name: "type", label: "Type", type: "string"},
    %{name: "created_at", label: "Created at", type: "date"}
  ]

  @filters [%{property: "status", operator: "=", value: "active"}]

  describe "anatomy" do
    test "renders the bar with icon area, conditions row, and freeform input" do
      assigns = %{properties: @properties, filters: @filters}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} filters={@filters} />
        """)

      assert html =~ ~s{id="f"}
      assert html =~ ~s{id="f-freeform"}
      assert html =~ ~s{data-polaris-filter-bar}
      assert html =~ ~s{data-polaris-filter-bar-bar}
      assert html =~ ~s{data-polaris-filter-bar-icon}
      assert html =~ ~s{data-polaris-filter-bar-conditions}
      assert html =~ ~s{data-polaris-filter-bar-input}
    end

    test "the bar chrome owns the interactive states" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} />
        """)

      bar = bar_class(html)

      assert bar =~ "rounded-md"
      assert bar =~ "border-surface-border"
      assert bar =~ "bg-surface-panel"
      assert bar =~ "cursor-text"
      assert bar =~ "hover:border-surface-border-hover"
      assert bar =~ "focus-within:ring-2"
      assert bar =~ "focus-within:ring-brand-emerald"
    end

    test "the bar carries the min height and horizontal scroll of the fragment" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} />
        """)

      assert html =~ "min-h-[32px]"
      assert bar_class(html) =~ "overflow-auto"
    end
  end

  describe "condition chips" do
    test "each chip renders property label, operator, value, and remove button" do
      assigns = %{properties: @properties, filters: @filters}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} filters={@filters} />
        """)

      assert html =~ ~s{data-polaris-filter-condition="status"}
      assert html =~ ~s{data-polaris-filter-property="status"}
      assert html =~ ~s{data-polaris-filter-operator="status"}
      assert html =~ ~s{data-polaris-filter-value="status"}
      assert html =~ ~s{data-polaris-filter-remove="status"}
      assert html =~ "Status"
      assert html =~ ~s{value="="}
      assert html =~ ~s{value="active"}
      assert html =~ "h-[26px]"
    end

    test "chip segments carry the fragment's aria labels" do
      assigns = %{properties: @properties, filters: @filters}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} filters={@filters} />
        """)

      assert html =~ ~s{aria-label="Change property from Status"}
      assert html =~ ~s{aria-label="Operator for Status"}
      assert html =~ ~s{aria-label="Value for Status"}
      assert html =~ ~s{aria-label="Remove Status filter"}
    end

    test "operator and value inputs auto-size via the mirror-span trick" do
      assigns = %{properties: @properties, filters: @filters}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} filters={@filters} />
        """)

      assert html =~ "invisible block whitespace-pre"
    end

    test "unknown properties fall back to their name" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar
          id="f"
          properties={@properties}
          filters={[%{property: "mystery", operator: "=", value: "x"}]}
        />
        """)

      assert html =~ ~s{aria-label="Change property from mystery"}
    end

    test "chips render in order with index attributes" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar
          id="f"
          properties={@properties}
          filters={[
            %{property: "name", operator: "=", value: "a"},
            %{property: "type", operator: "!=", value: "b"}
          ]}
        />
        """)

      assert html =~ ~s{data-index="0"}
      assert html =~ ~s{data-index="1"}
      assert html =~ ~s{name="f-operator-0"}
      assert html =~ ~s{name="f-value-1"}
    end
  end

  describe "logical operator" do
    test "hidden by default, rendered between chips with supports_operators" do
      assigns = %{properties: @properties}

      two_filters = [
        %{property: "name", operator: "=", value: "a"},
        %{property: "type", operator: "=", value: "b"}
      ]

      assigns = %{properties: @properties, filters: two_filters}

      without =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} filters={@filters} />
        """)

      refute without =~ ~s{data-polaris-filter-bar-logical}

      with_toggle =
        rendered_to_string(~H"""
        <.filter_bar
          id="f"
          properties={@properties}
          filters={@filters}
          supports_operators
          on_toggle="toggle-logical"
        />
        """)

      assert with_toggle =~ ~s{data-polaris-filter-bar-logical}
      assert with_toggle =~ "AND"
      assert with_toggle =~ ~s{phx-click="toggle-logical"}
      assert with_toggle =~ ~s{aria-label="Switch logical operator to OR"}
    end

    test "no toggle before the first chip" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar
          id="f"
          properties={@properties}
          filters={[%{property: "name", operator: "=", value: "a"}]}
          supports_operators
        />
        """)

      refute html =~ ~s{data-polaris-filter-bar-logical}
    end

    test "logical_operator OR renders and invalid values raise" do
      assigns = %{
        properties: @properties,
        filters: [
          %{property: "name", operator: "=", value: "a"},
          %{property: "type", operator: "=", value: "b"}
        ]
      }

      html =
        rendered_to_string(~H"""
        <.filter_bar
          id="f"
          properties={@properties}
          filters={@filters}
          supports_operators
          logical_operator="OR"
        />
        """)

      assert html =~ "OR"

      assert_raise ArgumentError, ~r/invalid value for :logical_operator/, fn ->
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} logical_operator="XOR" />
        """)
      end
    end
  end

  describe "placeholder microcopy" do
    test "three properties render as Filter by A, B, C" do
      assigns = %{properties: Enum.take(@properties, 3)}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} />
        """)

      assert html =~ ~s{placeholder="Filter by Name, Status, Type"}
    end

    test "more than three properties get the ellipsis" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} />
        """)

      assert html =~ ~s{placeholder="Filter by Name, Status, Type..."}
    end

    test "no properties render Add filters..." do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={[]} />
        """)

      assert html =~ ~s{placeholder="Add filters..."}
    end

    test "existing conditions switch to Add more filters..." do
      assigns = %{properties: @properties, filters: @filters}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} filters={@filters} />
        """)

      assert html =~ ~s{placeholder="Add more filters..."}
    end

    test "an explicit placeholder wins" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} placeholder="Search invoices" />
        """)

      assert html =~ ~s{placeholder="Search invoices"}
    end
  end

  describe "events" do
    test "every segment wires its LiveView event with the chip index" do
      assigns = %{properties: @properties, filters: @filters}

      html =
        rendered_to_string(~H"""
        <.filter_bar
          id="f"
          properties={@properties}
          filters={@filters}
          on_search="search"
          on_add="add"
          on_property_click="edit-property"
          on_operator_change="operator-change"
          on_change="value-change"
          on_remove="remove"
          on_apply="apply"
        />
        """)

      assert html =~ ~s{phx-change="search"}
      assert html =~ ~s{phx-click="edit-property"}
      assert html =~ ~s{phx-change="operator-change"}
      assert html =~ ~s{phx-change="value-change"}
      assert html =~ ~s{phx-click="remove"}

      for event <- ~w(edit-property remove) do
        assert html =~ ~s{phx-click="#{event}"}
        assert html =~ ~s{phx-value-index="0"}
      end

      for event <- ~w(operator-change value-change) do
        assert html =~ ~s{phx-change="#{event}"}
        assert html =~ ~s{phx-value-index="0"}
      end
    end

    test "the freeform input suppresses password managers like the fragment" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} />
        """)

      assert html =~ "data-1p-ignore"
      assert html =~ ~s{data-lpignore="true"}
      assert html =~ ~s{data-form-type="other"}
      assert html =~ "data-bwignore"
      assert html =~ ~s{aria-label="Add filter"}
    end
  end

  describe "variants and states" do
    test "default chips are border-r separated; pill chips are bordered rounds" do
      assigns = %{properties: @properties, filters: @filters}

      default =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} filters={@filters} />
        """)

      assert default =~ "border-r border-surface-border"

      pill =
        rendered_to_string(~H"""
        <.filter_bar
          id="f"
          properties={@properties}
          filters={@filters}
          variant="pill"
        />
        """)

      assert pill =~ "rounded-sm border border-surface-border"
      assert pill =~ "gap-1"
    end

    test "invalid variant raises a clear error" do
      assigns = %{properties: @properties}

      assert_raise ArgumentError, ~r/invalid value for :variant/, fn ->
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} variant="chip" />
        """)
      end
    end

    test "loading pulses the chip row and spins the icon" do
      assigns = %{properties: @properties, filters: @filters}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} filters={@filters} loading />
        """)

      row = class_of(html, "data-polaris-filter-bar-conditions")
      assert row =~ "animate-pulse"
      assert html =~ "animate-spin"
    end

    test "error renders the red hint line under the bar" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} error="Failed to load options for Status" />
        """)

      assert html =~ ~s{data-polaris-filter-bar-error}
      assert html =~ "Failed to load options for Status"
      assert html =~ "text-danger"

      clean =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} />
        """)

      refute clean =~ ~s{data-polaris-filter-bar-error}
    end

    test "caller classes merge onto the bar and globals pass through" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} class="max-w-xl" data-track="x" />
        """)

      assert bar_class(html) =~ "max-w-xl"
      assert html =~ ~s{data-track="x"}
    end
  end

  describe "hook" do
    test "attaches the colocated runtime hook with its event names" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} on_add="add" on_apply="apply" />
        """)

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-add-event="add"}
      assert html =~ ~s{data-apply-event="apply"}
      assert html =~ "<script"
    end

    test "hook handles Enter commits, Escape blur, and bar-click focus" do
      assigns = %{properties: @properties}

      html =
        rendered_to_string(~H"""
        <.filter_bar id="f" properties={@properties} on_add="add" on_apply="apply" />
        """)

      assert html =~ ~s/"Enter"/
      assert html =~ ~s/"Escape"/
      assert html =~ "focusout"
      assert html =~ "pushEvent(addEvent"
    end
  end

  defp bar_class(html) do
    class_of(html, "data-polaris-filter-bar-bar")
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
      true -> ""
    end
  end
end
