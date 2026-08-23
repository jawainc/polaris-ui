defmodule PolarisUI.Components.SingleValueFieldArrayTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.SingleValueFieldArray`
  — row anatomy, input naming, event wiring, minimum-rows and disabled
  states, error hints, class merging, and the no-arbitrary-color design
  rule, mirroring the Supabase design system fragment
  `ui-patterns/form/SingleValueFieldArray` (rows owned by the
  LiveView).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.SingleValueFieldArray

  @urls [
    %{value: "https://example.com/callback"},
    %{value: "https://studio.supabase.com/auth/callback"}
  ]

  @base %{
    id: "redirect-urls",
    fields: @urls,
    value_field: :value,
    placeholder: "https://example.com/callback",
    add_label: "Add redirect URL"
  }

  defp render_sv(attrs \\ []) do
    assigns = %{attrs: Map.merge(@base, Map.new(attrs))}

    rendered_to_string(~H"""
    <.single_value_field_array {@attrs} />
    """)
  end

  describe "anatomy" do
    test "renders the array, rows, inputs, and buttons with one row per field" do
      html = render_sv()

      assert html =~ "data-polaris-sv-array"
      assert html =~ "data-polaris-sv-rows"
      assert html =~ "data-polaris-sv-add"

      assert length(tags_with(html, "data-polaris-sv-row")) == 2
      assert length(tags_with(html, "data-polaris-sv-value")) == 2
      assert length(tags_with(html, "data-polaris-sv-remove")) == 2
      assert length(tags_with(html, "data-polaris-sv-add-button")) == 1
    end

    test "rows carry their index and the fragment's geometry" do
      html = render_sv()

      assert html =~ ~s{data-index="0"}
      assert html =~ ~s{data-index="1"}
      assert class_of(html, "data-polaris-sv-row") =~ "flex items-start space-x-2"
      assert class_of(html, "data-polaris-sv-rows") =~ "mt-1 space-y-3"
      assert class_of(html, "data-polaris-sv-array") =~ "space-y-3"
    end

    test "values render into their inputs with placeholder and aria labels" do
      html = render_sv(fields: Enum.take(@urls, 1))

      assert html =~ ~s{value="https://example.com/callback"}
      assert html =~ ~s{placeholder="https://example.com/callback"}
      assert html =~ ~s{aria-label="https://example.com/callback 1"}
      assert html =~ ~s{aria-label="Remove row"}
      assert html =~ ~s{autocomplete="off"}
    end

    test "the remove label is customizable" do
      html = render_sv(remove_label: "Remove redirect URL")

      assert html =~ ~s{aria-label="Remove redirect URL"}
    end

    test "inputs carry the shared input shell at the fragment's small size" do
      html = render_sv()

      input = class_of(html, "data-polaris-sv-value")

      assert input =~ "border-surface-border"
      assert input =~ "bg-surface-panel"
      assert input =~ "hover:border-surface-border-hover"
      assert input =~ "focus:ring-2 focus:ring-brand-emerald"
      assert input =~ "focus:ring-offset-2 focus:ring-offset-surface-ground"
      assert input =~ "rounded-md"
      assert input =~ "h-[34px]"
      assert input =~ "w-full px-2 text-sm"
    end

    test "the remove button is icon-only chrome with the trash glyph" do
      html = render_sv(fields: Enum.take(@urls, 1))

      remove = class_of(html, "data-polaris-sv-remove")

      assert remove =~ "h-[34px] w-[34px] shrink-0"
      assert remove =~ "border border-surface-border"
      assert remove =~ "text-content-muted"
      assert remove =~ "hover:border-surface-border-hover hover:text-content-secondary"
      assert remove =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"

      tag = hd(tags_with(html, "data-polaris-sv-remove"))
      # icon-only: no text content between the tags
      assert tag =~ ~r{>\s*$}
      assert html =~ "M3 6h18"
    end

    test "the add button carries the fragment's button chrome" do
      html = render_sv(on_add: "sv-add")

      add = class_of(html, "data-polaris-sv-add-button")

      assert add =~ "h-[34px]"
      assert add =~ "px-3"
      assert add =~ "border border-surface-border"
      assert add =~ "bg-surface-panel"
      assert add =~ "hover:border-surface-border-hover"
      assert add =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"

      assert html =~ "Add redirect URL"
      assert html =~ "M5 12h14"
    end

    test "autocomplete is customizable per input" do
      html = render_sv(autocomplete: "url")

      assert hd(tags_with(html, "data-polaris-sv-value")) =~ ~s{autocomplete="url"}
    end
  end

  describe "input names and field forms" do
    test "names derive from id, index, and the value field" do
      html = render_sv()

      assert html =~ ~s{name="redirect-urls-0-value"}
      assert html =~ ~s{name="redirect-urls-1-value"}
    end

    test "string-keyed rows work with atom field names" do
      html = render_sv(fields: [%{"value" => "https://example.com/callback"}])

      assert html =~ ~s{value="https://example.com/callback"}
    end

    test "string field names work with atom-keyed rows" do
      html =
        render_sv(
          fields: [%{value: "https://edge.supabase.com"}],
          value_field: "value"
        )

      assert html =~ ~s{value="https://edge.supabase.com"}
      assert html =~ ~s{name="redirect-urls-0-value"}
      assert hd(tags_with(html, "data-polaris-sv-value")) =~ ~s{phx-value-field="value"}
    end
  end

  describe "events" do
    test "inputs wire phx-change with index and field payloads" do
      html = render_sv(on_change: "sv-change")

      tag = hd(tags_with(html, "data-polaris-sv-value"))

      assert tag =~ ~s{phx-change="sv-change"}
      assert tag =~ ~s{phx-value-index="0"}
      assert tag =~ ~s{phx-value-field="value"}
    end

    test "the second row carries index 1 on its input and remove button" do
      html = render_sv(on_change: "sv-change", on_remove: "sv-remove")

      assert Enum.at(tags_with(html, "data-polaris-sv-value"), 1) =~ ~s{phx-value-index="1"}
      assert Enum.at(tags_with(html, "data-polaris-sv-remove"), 1) =~ ~s{phx-value-index="1"}
    end

    test "the add button pushes on_add and the row x pushes on_remove" do
      html = render_sv(on_add: "sv-add", on_remove: "sv-remove")

      assert hd(tags_with(html, "data-polaris-sv-add-button")) =~ ~s{phx-click="sv-add"}
      assert hd(tags_with(html, "data-polaris-sv-remove")) =~ ~s{phx-click="sv-remove"}
    end

    test "no event attrs render when the handlers are omitted" do
      html = render_sv()

      refute html =~ "phx-change"
      refute html =~ "phx-click"
    end
  end

  describe "minimum rows" do
    test "removes stay enabled above the floor" do
      html = render_sv(minimum_rows: 1)

      for tag <- tags_with(html, "data-polaris-sv-remove") do
        refute tag =~ ~r{\sdisabled(?=[\s>=])}
      end
    end

    test "removes disable at or below the floor but the add button never does" do
      html = render_sv(minimum_rows: 2)

      for tag <- tags_with(html, "data-polaris-sv-remove") do
        assert tag =~ ~r{\sdisabled(?=[\s>=])}
      end

      refute hd(tags_with(html, "data-polaris-sv-add-button")) =~ ~r{\sdisabled(?=[\s>=])}
    end

    test "disabled combines with the floor via or, like the fragment's disableRemove" do
      html = render_sv(disabled: false, minimum_rows: 5)

      assert length(tags_with(html, "data-polaris-sv-remove")) == 2
    end
  end

  describe "disabled" do
    test "disables every input and button at once" do
      html = render_sv(disabled: true)

      tags =
        tags_with(html, "data-polaris-sv-value") ++
          tags_with(html, "data-polaris-sv-remove") ++
          tags_with(html, "data-polaris-sv-add-button")

      assert length(tags) == 5

      for tag <- tags do
        assert tag =~ ~r{\sdisabled(?=[\s>=])}
      end

      assert class_of(html, "data-polaris-sv-add-button") =~ "disabled:opacity-50"
    end

    test "nothing is disabled by default" do
      html = render_sv()

      for tag <-
            tags_with(html, "data-polaris-sv-value") ++
              tags_with(html, "data-polaris-sv-add-button") do
        refute tag =~ ~r{\sdisabled(?=[\s>=])}
      end
    end
  end

  describe "error_for" do
    test "renders the per-row red hint under the offending input" do
      html =
        render_sv(
          error_for: %{
            "0-value" => "Must be a valid URL",
            "1-value" => "Must be a valid URL"
          }
        )

      assert length(tags_with(html, "data-polaris-sv-error")) == 2
      assert html =~ "Must be a valid URL"

      assert hd(tags_with(html, "data-polaris-sv-error")) =~
               ~s{class="mt-1 text-xs text-danger"}
    end

    test "nil and empty error maps render no hints" do
      refute render_sv() =~ "data-polaris-sv-error"
      refute render_sv(error_for: %{}) =~ "data-polaris-sv-error"
    end

    test "error keys use string field names even with atom field attrs" do
      html = render_sv(fields: Enum.take(@urls, 1), error_for: %{"0-value" => "Nope"})

      assert html =~ "Nope"
      assert length(tags_with(html, "data-polaris-sv-error")) == 1
    end

    test "errors for absent rows or fields render nothing" do
      html =
        render_sv(
          fields: Enum.take(@urls, 1),
          error_for: %{"1-value" => "Gone", "0-key" => "Wrong cell"}
        )

      refute html =~ "data-polaris-sv-error"
    end
  end

  describe "class merging and globals" do
    test "caller classes merge onto every themed surface and globals pass through" do
      html =
        render_sv(%{
          "data-track" => "x",
          class: "max-w-2xl",
          rows_class: "mt-4",
          row_class: "gap-2",
          value_input_class: "font-mono",
          add_button_class: "px-6",
          remove_button_class: "text-content-secondary"
        })

      assert class_of(html, "data-polaris-sv-array") =~ "max-w-2xl"
      assert class_of(html, "data-polaris-sv-rows") =~ "mt-4"
      assert class_of(html, "data-polaris-sv-row") =~ "gap-2"
      assert class_of(html, "data-polaris-sv-value") =~ "font-mono"
      assert class_of(html, "data-polaris-sv-add-button") =~ "px-6"
      assert class_of(html, "data-polaris-sv-remove") =~ "text-content-secondary"
      assert html =~ ~s{data-track="x"}
    end

    test "defaults survive when no caller classes are given" do
      html = render_sv()

      assert class_of(html, "data-polaris-sv-rows") =~ "space-y-3"
      assert class_of(html, "data-polaris-sv-add-button") =~ "px-3"
      assert class_of(html, "data-polaris-sv-value") =~ "border-surface-border"
    end
  end

  describe "empty fields" do
    test "no rows render but the add button remains" do
      html = render_sv(fields: [])

      assert html =~ "data-polaris-sv-rows"
      assert tags_with(html, "data-polaris-sv-row") == []
      assert tags_with(html, "data-polaris-sv-value") == []
      assert tags_with(html, "data-polaris-sv-remove") == []
      refute html =~ "data-polaris-sv-error"

      assert length(tags_with(html, "data-polaris-sv-add-button")) == 1
      assert html =~ "Add redirect URL"
    end
  end

  describe "design rules" do
    test "no arbitrary color values anywhere in a fully-loaded render" do
      html =
        render_sv(
          error_for: %{"0-value" => "Must be a valid URL"},
          class: "max-w-2xl",
          value_input_class: "font-mono"
        )

      refute html =~ "#["
    end
  end

  # Extracts the opening tags of every element carrying the marker.
  # The lookahead keeps prefixed markers apart (row vs rows,
  # add vs add-button) — bare data attributes render without ="...".
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
