defmodule PolarisUI.Components.KeyValueFieldArrayTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.KeyValueFieldArray` —
  row anatomy, input naming, event wiring, the add-actions split
  button, error hints, class merging, and the pure `validation_issues/1`
  rules, mirroring the Supabase design system fragment
  `ui-patterns/form/KeyValueFieldArray` (rows owned by the LiveView).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.KeyValueFieldArray

  doctest PolarisUI.Components.KeyValueFieldArray

  @headers [
    %{name: "x-client-info", value: "studio"},
    %{name: "accept", value: "application/json"}
  ]

  @add_actions [
    %{key: "auth", label: "Authorization header", description: "Adds a Bearer token row"},
    %{key: "custom", label: "Custom header", separator_above: true, action: "add-custom-header"}
  ]

  @base %{
    id: "headers",
    fields: @headers,
    key_field: :name,
    value_field: :value,
    key_placeholder: "Header name",
    value_placeholder: "Header value",
    add_label: "Add header"
  }

  defp render_kv(attrs \\ []) do
    assigns = %{attrs: Map.merge(@base, Map.new(attrs))}

    rendered_to_string(~H"""
    <.key_value_field_array {@attrs} />
    """)
  end

  describe "anatomy" do
    test "renders the array, rows, cells, and buttons with one row per field" do
      html = render_kv()

      assert html =~ "data-polaris-kv-array"
      assert html =~ "data-polaris-kv-rows"
      assert html =~ "data-polaris-kv-add"

      assert length(tags_with(html, "data-polaris-kv-row")) == 2
      assert length(tags_with(html, "data-polaris-kv-key-cell")) == 2
      assert length(tags_with(html, "data-polaris-kv-value-cell")) == 2
      assert length(tags_with(html, "data-polaris-kv-key")) == 2
      assert length(tags_with(html, "data-polaris-kv-value")) == 2
      assert length(tags_with(html, "data-polaris-kv-remove")) == 2
      assert length(tags_with(html, "data-polaris-kv-add-button")) == 1
    end

    test "rows carry their index and the fragment's geometry" do
      html = render_kv()

      assert html =~ ~s{data-index="0"}
      assert html =~ ~s{data-index="1"}
      assert class_of(html, "data-polaris-kv-row") =~ "flex items-start space-x-2"
      assert class_of(html, "data-polaris-kv-rows") =~ "mt-1 space-y-3"
      assert class_of(html, "data-polaris-kv-array") =~ "space-y-3"
    end

    test "values render into their inputs with placeholders and aria labels" do
      html = render_kv(fields: Enum.take(@headers, 1))

      assert html =~ ~s{value="x-client-info"}
      assert html =~ ~s{value="studio"}
      assert html =~ ~s{placeholder="Header name"}
      assert html =~ ~s{placeholder="Header value"}
      assert html =~ ~s{aria-label="Header name 1"}
      assert html =~ ~s{aria-label="Header value 1"}
      assert html =~ ~s{aria-label="Remove row"}
      assert html =~ ~s{autocomplete="off"}
    end

    test "the remove label is customizable" do
      html = render_kv(remove_label: "Remove header")

      assert html =~ ~s{aria-label="Remove header"}
    end

    test "inputs carry the shared input shell at the fragment's small size" do
      html = render_kv()

      key = class_of(html, "data-polaris-kv-key")
      value = class_of(html, "data-polaris-kv-value")

      for input <- [key, value] do
        assert input =~ "border-surface-border"
        assert input =~ "bg-surface-panel"
        assert input =~ "hover:border-surface-border-hover"
        assert input =~ "focus:ring-2 focus:ring-brand-emerald"
        assert input =~ "h-[34px]"
        assert input =~ "w-full px-2 text-sm"
      end
    end

    test "the remove button is icon-only chrome with the trash glyph" do
      html = render_kv(fields: Enum.take(@headers, 1))

      remove = class_of(html, "data-polaris-kv-remove")

      assert remove =~ "h-[34px] w-[34px] shrink-0"
      assert remove =~ "border border-surface-border"
      assert remove =~ "text-content-muted"
      assert remove =~ "hover:border-surface-border-hover hover:text-content-secondary"
      assert remove =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"

      tag = hd(tags_with(html, "data-polaris-kv-remove"))
      # icon-only: no text content between the tags
      assert tag =~ ~r{>\s*$}
      assert html =~ "M3 6h18"
    end

    test "the add button carries the fragment's button chrome" do
      html = render_kv(on_add: "kv-add")

      add = class_of(html, "data-polaris-kv-add-button")

      assert add =~ "h-[34px]"
      assert add =~ "px-3"
      assert add =~ "border border-surface-border"
      assert add =~ "bg-surface-panel"
      assert add =~ "hover:border-surface-border-hover"
      assert add =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"

      assert html =~ "Add header"
      assert html =~ "M5 12h14"
    end
  end

  describe "input names and field forms" do
    test "names derive from id, index, and field names" do
      html = render_kv()

      assert html =~ ~s{name="headers-0-name"}
      assert html =~ ~s{name="headers-0-value"}
      assert html =~ ~s{name="headers-1-name"}
      assert html =~ ~s{name="headers-1-value"}
    end

    test "string-keyed rows work with atom field names" do
      html =
        render_kv(fields: [%{"name" => "x-client-info", "value" => "studio"}])

      assert html =~ ~s{value="x-client-info"}
      assert html =~ ~s{value="studio"}
    end

    test "string field names work with atom-keyed rows" do
      html =
        render_kv(
          fields: [%{name: "retry", value: "3"}],
          key_field: "name",
          value_field: "value"
        )

      assert html =~ ~s{value="retry"}
      assert html =~ ~s{value="3"}
      assert html =~ ~s{name="headers-0-name"}
      assert hd(tags_with(html, "data-polaris-kv-key")) =~ ~s{phx-value-field="name"}
    end
  end

  describe "events" do
    test "inputs wire phx-change with index and field payloads" do
      html = render_kv(on_change: "kv-change")

      key_tag = hd(tags_with(html, "data-polaris-kv-key"))
      value_tag = hd(tags_with(html, "data-polaris-kv-value"))

      assert key_tag =~ ~s{phx-change="kv-change"}
      assert key_tag =~ ~s{phx-value-index="0"}
      assert key_tag =~ ~s{phx-value-field="name"}

      assert value_tag =~ ~s{phx-change="kv-change"}
      assert value_tag =~ ~s{phx-value-index="0"}
      assert value_tag =~ ~s{phx-value-field="value"}
    end

    test "the second row carries index 1 on its inputs and remove button" do
      html = render_kv(on_change: "kv-change", on_remove: "kv-remove")

      assert Enum.at(tags_with(html, "data-polaris-kv-key"), 1) =~ ~s{phx-value-index="1"}
      assert Enum.at(tags_with(html, "data-polaris-kv-remove"), 1) =~ ~s{phx-value-index="1"}
    end

    test "the add button pushes on_add and the row x pushes on_remove" do
      html = render_kv(on_add: "kv-add", on_remove: "kv-remove")

      assert hd(tags_with(html, "data-polaris-kv-add-button")) =~ ~s{phx-click="kv-add"}
      assert hd(tags_with(html, "data-polaris-kv-remove")) =~ ~s{phx-click="kv-remove"}
    end

    test "menu items push the add-action event with their key" do
      html =
        render_kv(add_actions: @add_actions, add_menu_open: true, on_add_action: "kv-add-action")

      [auth, custom] = tags_with(html, "data-polaris-kv-add-item")

      assert auth =~ ~s{phx-click="kv-add-action"}
      assert auth =~ ~s{phx-value-key="auth"}

      assert custom =~ ~s{phx-click="add-custom-header"}
      assert custom =~ ~s{phx-value-key="custom"}
    end
  end

  describe "disabled" do
    test "disables every input and button at once" do
      html = render_kv(disabled: true, add_actions: @add_actions)

      tags =
        tags_with(html, "data-polaris-kv-key") ++
          tags_with(html, "data-polaris-kv-value") ++
          tags_with(html, "data-polaris-kv-remove") ++
          tags_with(html, "data-polaris-kv-add-button") ++
          tags_with(html, "data-polaris-kv-add-toggle")

      assert length(tags) == 8

      for tag <- tags do
        assert tag =~ ~r{\sdisabled(?=[\s>=])}
      end

      assert class_of(html, "data-polaris-kv-add-button") =~ "disabled:opacity-50"
    end

    test "nothing is disabled by default" do
      html = render_kv(add_actions: @add_actions)

      for tag <-
            tags_with(html, "data-polaris-kv-key") ++
              tags_with(html, "data-polaris-kv-add-button") do
        refute tag =~ ~r{\sdisabled(?=[\s>=])}
      end
    end
  end

  describe "error_for" do
    test "renders the per-cell red hint under the offending input" do
      html =
        render_kv(
          error_for: %{
            "0-name" => "Header name is required",
            "1-value" => "Header value is required"
          }
        )

      assert length(tags_with(html, "data-polaris-kv-error")) == 2
      assert html =~ "Header name is required"
      assert html =~ "Header value is required"

      assert hd(tags_with(html, "data-polaris-kv-error")) =~
               ~s{class="mt-1 text-xs text-danger"}
    end

    test "nil and empty error maps render no hints" do
      refute render_kv() =~ "data-polaris-kv-error"
      refute render_kv(error_for: %{}) =~ "data-polaris-kv-error"
    end

    test "error keys use string field names even with atom field attrs" do
      html = render_kv(fields: Enum.take(@headers, 1), error_for: %{"0-value" => "Nope"})

      assert html =~ "Nope"
      assert length(tags_with(html, "data-polaris-kv-error")) == 1
    end
  end

  describe "add actions dropdown" do
    test "no add_actions means a plain add button and no toggle" do
      html = render_kv(on_add: "kv-add")

      assert html =~ "data-polaris-kv-add-button"
      refute html =~ "data-polaris-kv-add-toggle"
      refute class_of(html, "data-polaris-kv-add-button") =~ "rounded-r-none"
    end

    test "add_actions renders the split button with the fragment's seam classes" do
      html = render_kv(add_actions: @add_actions, on_toggle_add: "toggle-add-menu")

      toggle = hd(tags_with(html, "data-polaris-kv-add-toggle"))

      assert toggle =~ ~s{phx-click="toggle-add-menu"}
      assert toggle =~ ~s{aria-label="Add header options"}
      assert html =~ "m6 9 6 6 6-6"

      toggle_class = class_of(html, "data-polaris-kv-add-toggle")

      assert toggle_class =~ "rounded-l-none"
      assert toggle_class =~ "border-l-0"
      assert toggle_class =~ "-ml-px"
      assert toggle_class =~ "w-9"
      assert toggle_class =~ "focus-visible:rounded-l-sm"

      add_class = class_of(html, "data-polaris-kv-add-button")

      assert add_class =~ "rounded-r-none"
      assert add_class =~ "hover:z-10"
      assert add_class =~ "focus-visible:z-10"
      assert add_class =~ "focus-visible:rounded-r-sm"
    end

    test "the menu is absent until add_menu_open" do
      html = render_kv(add_actions: @add_actions)

      refute html =~ "data-polaris-kv-add-menu"
      refute html =~ "data-polaris-kv-add-item"
    end

    test "the open menu lists actions with labels, descriptions, and separators" do
      html = render_kv(add_actions: @add_actions, add_menu_open: true)

      assert html =~ "data-polaris-kv-add-menu"
      assert class_of(html, "data-polaris-kv-add-menu") =~ "absolute left-0 top-full z-50"
      assert length(tags_with(html, "data-polaris-kv-add-item")) == 2
      assert html =~ "Authorization header"
      assert html =~ "Adds a Bearer token row"
      assert html =~ ~s{class="text-content-primary"}
      assert html =~ ~s{class="text-xs text-content-secondary"}
      assert length(tags_with(html, "data-polaris-kv-add-separator")) == 1
    end

    test "menu item classes come from the fragment's dropdown item" do
      html = render_kv(add_actions: @add_actions, add_menu_open: true)

      item = class_of(html, "data-polaris-kv-add-item")

      assert item =~ "w-full"
      assert item =~ "items-start"
      assert item =~ "hover:bg-surface-panel-hover"
      assert item =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
    end
  end

  describe "class merging and globals" do
    test "caller classes merge onto every themed surface and globals pass through" do
      html =
        render_kv(%{
          "data-track" => "x",
          class: "max-w-2xl",
          rows_class: "mt-4",
          row_class: "gap-2",
          key_input_class: "font-mono",
          value_input_class: "font-mono",
          add_button_class: "px-6",
          remove_button_class: "text-content-secondary"
        })

      assert class_of(html, "data-polaris-kv-array") =~ "max-w-2xl"
      assert class_of(html, "data-polaris-kv-rows") =~ "mt-4"
      assert class_of(html, "data-polaris-kv-row") =~ "gap-2"
      assert class_of(html, "data-polaris-kv-key") =~ "font-mono"
      assert class_of(html, "data-polaris-kv-value") =~ "font-mono"
      assert class_of(html, "data-polaris-kv-add-button") =~ "px-6"
      assert class_of(html, "data-polaris-kv-remove") =~ "text-content-secondary"
      assert html =~ ~s{data-track="x"}
    end

    test "defaults survive when no caller classes are given" do
      html = render_kv()

      assert class_of(html, "data-polaris-kv-rows") =~ "space-y-3"
      assert class_of(html, "data-polaris-kv-add-button") =~ "px-3"
      assert class_of(html, "data-polaris-kv-key") =~ "border-surface-border"
    end
  end

  describe "validation_issues/1" do
    test "valid rows and empty inputs produce no issues" do
      assert validation_issues(rows: [], key_field: :name, value_field: :value) == []
      assert validation_issues(key_field: :name, value_field: :value) == []
      assert validation_issues(rows: @headers, key_field: :name, value_field: :value) == []
    end

    test "a missing key flags only the key cell and skips duplicate checks" do
      rows = [%{name: "", value: "studio"}, %{name: "  ", value: "edge"}]

      assert validation_issues(rows: rows, key_field: :name, value_field: :value) == [
               %{path: [0, "name"], message: "Key is required"},
               %{path: [1, "name"], message: "Key is required"}
             ]
    end

    test "a missing value skips duplicate checks like the fragment" do
      rows = [%{name: "accept", value: ""}, %{name: "accept", value: "json"}]

      assert validation_issues(rows: rows, key_field: :name, value_field: :value) == [
               %{path: [0, "value"], message: "Value is required"}
             ]
    end

    test "duplicates flag every occurrence after all per-row issues" do
      rows = [
        %{name: " x-client-info ", value: "studio"},
        %{name: "x-client-info", value: "edge"},
        %{name: "accept", value: ""}
      ]

      assert validation_issues(rows: rows, key_field: :name, value_field: :value) == [
               %{path: [2, "value"], message: "Value is required"},
               %{path: [0, "name"], message: "Duplicate key"},
               %{path: [1, "name"], message: "Duplicate key"}
             ]
    end

    test "distinct keys are not duplicates" do
      rows = [%{name: "a", value: "1"}, %{name: "b", value: "2"}]

      assert validation_issues(rows: rows, key_field: :name, value_field: :value) == []
    end

    test "fully empty rows are draft-friendly unless allow_empty_rows is false" do
      rows = [%{name: "", value: ""}, %{name: "  ", value: " \t "}]

      assert validation_issues(rows: rows, key_field: :name, value_field: :value) == []

      assert validation_issues(
               rows: rows,
               key_field: :name,
               value_field: :value,
               allow_empty_rows: false
             ) == [
               %{path: [0, "name"], message: "Key is required"},
               %{path: [0, "value"], message: "Value is required"},
               %{path: [1, "name"], message: "Key is required"},
               %{path: [1, "value"], message: "Value is required"}
             ]
    end

    test "non-string values count as empty" do
      rows = [%{name: 123, value: "x"}]

      assert validation_issues(rows: rows, key_field: :name, value_field: :value) == [
               %{path: [0, "name"], message: "Key is required"}
             ]
    end

    test "custom messages, map opts, and string field names" do
      opts = %{
        rows: [%{"name" => "a"}],
        key_field: "name",
        value_field: "value",
        key_required_message: "Header name is required",
        value_required_message: "Header value is required",
        duplicate_key_message: "Duplicate header"
      }

      assert validation_issues(opts) == [
               %{path: [0, "value"], message: "Header value is required"}
             ]
    end

    test "duplicate_key_message nil disables duplicate checks" do
      rows = [%{name: "a", value: "1"}, %{name: "a", value: "2"}]

      assert validation_issues(
               rows: rows,
               key_field: :name,
               value_field: :value,
               duplicate_key_message: nil
             ) == []
    end

    test "normalise_key compares transformed keys" do
      rows = [%{name: "Content-Type", value: "json"}, %{name: "content-type", value: "xml"}]

      assert validation_issues(
               rows: rows,
               key_field: :name,
               value_field: :value,
               normalise_key: &String.downcase/1
             ) == [
               %{path: [0, "name"], message: "Duplicate key"},
               %{path: [1, "name"], message: "Duplicate key"}
             ]
    end
  end

  # Extracts the opening tags of every element carrying the marker.
  # The lookahead keeps prefixed markers apart (row vs rows, key vs
  # key-cell) — bare data attributes render without ="...".
  defp tags_with(html, marker) do
    marker = Regex.escape(marker)

    html
    |> then(&Regex.scan(~r{<[^>]*#{marker}(?![\w-])[^>]*>}, &1))
    |> List.flatten()
  end

  # Extracts the class attribute of the element carrying the marker,
  # regardless of attribute order within the tag.
  defp class_of(html, marker) do
    marker = Regex.escape(marker)

    class_after = ~r{<[^>]*#{marker}(?![\w-])[^>]*?class="([^"]*)"[^>]*>}
    class_before = ~r{<[^>]*class="([^"]*)"[^>]*?#{marker}(?![\w-])[^>]*>}

    cond do
      match = Regex.run(class_after, html, capture: :all_but_first) -> hd(match)
      match = Regex.run(class_before, html, capture: :all_but_first) -> hd(match)
      true -> flunk("no element with marker #{marker}")
    end
  end
end
