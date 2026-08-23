defmodule PolarisUI.Components.SingleValueFieldArray do
  @moduledoc """
  The Polaris single-value field array: a rendering-only editor for
  repeated single text inputs — redirect URLs, SSO domains, callback
  URIs — the port of the Supabase design system fragment
  `ui-patterns/form/SingleValueFieldArray`. Reach for the key/value
  field array when each row needs two inputs, or a custom row when
  the controls are mixed.

  The React fragment is a `react-hook-form` `useFieldArray` that owns
  its rows client-side and delegates validation to the consumer's
  resolver (a zod array of one-string objects). In LiveView the rows
  belong on the server, so this port keeps the anatomy, styling, and
  microcopy 1:1 while every mutation becomes a LiveView event:

    * `fields` renders the rows your LiveView owns — each row is a
      plain map and the component never mutates it;
    * editing an input pushes `on_change` with the row `index` and
      the `field` being edited (`phx-value-index` /
      `phx-value-field`);
    * the Add button pushes `on_add` (your handler appends the empty
      row — the fragment's `createEmptyRow`);
    * the row ✕ pushes `on_remove` with `index`;
    * validation stays with the consumer: build a lookup from your
      changeset's issue paths and pass it as `error_for` to render
      the fragment's per-input `FormMessage`s.

  ## Anatomy

      <.single_value_field_array
        id="redirect-urls"
        fields={@redirect_urls}
        value_field={:value}
        placeholder="https://example.com/callback"
        add_label="Add redirect URL"
        remove_label="Remove redirect URL"
        on_change="redirect-url-change"
        on_add="redirect-url-add"
        on_remove="redirect-url-remove"
        error_for={@redirect_url_errors}
      />

    * **rows** — one `flex` row per entry in `fields`: a value cell
      (`flex-1`) and the icon-only ✕ button. The cell is a small
      (`h-[34px]`) text input with the shared input shell (border,
      panel fill, emerald focus ring) and an optional red hint line
      beneath.
    * **add row** — the Add button with its Plus icon; no split-button
      or add-actions machinery here (that is key/value-only).

  Compose it inside a form item layout for the whole section's label,
  description, and message treatment, exactly like the fragment.

  ## Data shapes

      fields:    [%{value: "https://example.com/callback"}, %{value: ""}]
      error_for: %{"0-value" => "Must be a valid URL"}

  `value_field` names the row map key and may be an atom or a string
  (looked up as atom, then string); input names derive as
  `"<id>-<index>-<value_field>"`. `error_for` is keyed
  `"<index>-<value_field>"` (string keys) — build it straight from
  your changeset's issue paths:

      error_for =
        Map.new(issues, fn %{path: [index, field], message: message} ->
          {"\#{index}-\#{field}", message}
        end)

  ## Microcopy

  Per the Supabase copywriting guidelines the placeholder describes
  the value type, not the generic "Value":
  "https://example.com/callback" for redirect URLs, "SSO domain" for
  domains. The add label is a direct verb — "Add redirect URL" — and
  its noun carries into the remove label ("Remove redirect URL").

  ## States

    * **rest / hover** — input and button borders brighten
      (`hover:border-surface-border-hover`).
    * **focus** — inputs and buttons show the shared emerald ring
      (`focus:ring-2 focus:ring-brand-emerald` on inputs,
      `focus-visible:ring-2 ...` on buttons).
    * **disabled** — every input and button is disabled at once
      (`disabled:cursor-not-allowed disabled:opacity-50`); also ignore
      the events server-side.
    * **minimum rows** — every ✕ is disabled while
      `length(fields) <= minimum_rows` (the fragment's
      `disableRemove`), so a form can keep at least one row; Add
      stays enabled regardless.
    * **error** — pass `error_for` to render the red hint line
      (`text-xs text-danger`) under the offending input, like the
      fragment's `FormMessage`.

  Rendering-only: no colocated hook and no client state — the server
  round trips own everything.

  ## Deviations from the React fragment

  The fragment exposes `addButtonType` / `removeButtonType` (plus
  button sizes and `inputSize`). This port follows the house style of
  its key/value sibling: raw `<button>`s with the fixed default-look
  chrome instead of `<.button>` variants, so there are no
  `add_button_variant` / `remove_button_variant` attrs — restyle via
  `add_button_class` / `remove_button_class`. The input stays at the
  fragment's default `small` size (`h-[34px]`).
  """

  use PolarisUI.Component

  @input_shell "border border-surface-border bg-surface-panel transition-colors hover:border-surface-border-hover focus:border-surface-border-hover focus:outline-none focus:ring-2 focus:ring-brand-emerald focus:ring-offset-2 focus:ring-offset-surface-ground rounded-md"
  @input_size_classes "h-[34px] w-full px-2 text-sm"
  @button_focus_ring "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground rounded-md"
  @disabled_classes "disabled:cursor-not-allowed disabled:opacity-50"
  @remove_button_chrome "flex items-center justify-center rounded-md border border-surface-border bg-surface-panel text-content-muted transition-colors hover:border-surface-border-hover hover:text-content-secondary"
  @remove_button_size "h-[34px] w-[34px] shrink-0"
  @add_button_chrome "flex h-[34px] items-center gap-1.5 rounded-md border border-surface-border bg-surface-panel px-3 text-sm text-content-primary transition-colors hover:border-surface-border-hover"

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the array root. Row input names derive from it:
    `"<id>-<index>-<value_field>"`.
    """
  )

  attr(:fields, :list,
    required: true,
    doc: """
    The rows your LiveView owns — maps like
    `%{value: "https://example.com/callback"}`, rendered in order.
    """
  )

  attr(:value_field, :any,
    required: true,
    doc: """
    The row map key holding the text (the React `valueFieldName`) —
    atom or string. Fetched as atom, then string, so either row shape
    works.
    """
  )

  attr(:on_change, :string,
    default: nil,
    doc: "LiveView event for input edits (phx-change; receives `index` and `field`)."
  )

  attr(:on_add, :string,
    default: nil,
    doc: "LiveView event for the Add button (phx-click; append the empty row server-side)."
  )

  attr(:on_remove, :string,
    default: nil,
    doc: "LiveView event for the row ✕ (phx-click; receives `index`)."
  )

  attr(:placeholder, :string,
    required: true,
    doc:
      "Placeholder for row inputs — describe the value type (\"Redirect URL\"), not the generic \"Value\"."
  )

  attr(:add_label, :string,
    required: true,
    doc: "The Add button's verb phrase — a direct verb (\"Add redirect URL\")."
  )

  attr(:remove_label, :string,
    default: "Remove row",
    doc: "aria-label for the row ✕ button — carry the add label's noun (\"Remove redirect URL\")."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Disable every input and button in the array at once."
  )

  attr(:minimum_rows, :integer,
    default: 0,
    doc: """
    Floor on the row count (the fragment's `minimumRows`): every ✕ is
    disabled while `length(fields)` is at or below it. The Add button
    is unaffected.
    """
  )

  attr(:autocomplete, :string,
    default: "off",
    doc: """
    HTML autocomplete for row inputs (the fragment's
    `inputAutoComplete`) — defaults to `off`, unlike the fragment's
    `undefined`.
    """
  )

  attr(:error_for, :map,
    default: nil,
    doc: """
    Optional per-row error strings keyed by string
    `"<index>-<value_field>"` — e.g.
    `%{"0-value" => "Must be a valid URL"}` — rendered as a red hint
    line under the row's input, mirroring the React `FormMessage`.
    Build it from your changeset's issue paths.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root div — caller classes win via `cn/1`."
  )

  attr(:rows_class, :string,
    default: nil,
    doc: "Additional classes merged onto the rows wrapper."
  )

  attr(:row_class, :string, default: nil, doc: "Additional classes merged onto each row.")

  attr(:value_input_class, :string,
    default: nil,
    doc: "Additional classes merged onto each row's input."
  )

  attr(:add_button_class, :string,
    default: nil,
    doc: "Additional classes merged onto the Add button."
  )

  attr(:remove_button_class, :string,
    default: nil,
    doc: "Additional classes merged onto each row's ✕ button."
  )

  attr(:rest, :global, doc: "Forwarded to the root div: `data-*`, `phx-*`, …")

  def single_value_field_array(assigns) do
    # The fragment's disableRemove: one value for every ✕, computed
    # from the whole array length.
    disable_remove? = assigns.disabled or length(assigns.fields) <= assigns.minimum_rows

    assigns =
      assigns
      |> assign(
        disable_remove?: disable_remove?,
        value_field_name: to_string(assigns.value_field),
        container_classes: cn(["space-y-3", assigns.class]),
        rows_wrapper_classes: cn(["mt-1 space-y-3", assigns.rows_class]),
        row_classes: cn(["flex items-start space-x-2", assigns.row_class]),
        value_input_classes: cn([@input_shell, @input_size_classes, assigns.value_input_class]),
        remove_button_classes:
          cn([
            @remove_button_chrome,
            @button_focus_ring,
            @disabled_classes,
            @remove_button_size,
            assigns.remove_button_class
          ]),
        add_button_classes:
          cn([
            @add_button_chrome,
            @button_focus_ring,
            @disabled_classes,
            assigns.add_button_class
          ]),
        rows:
          assigns.fields
          |> Enum.with_index()
          |> Enum.map(fn {row, index} ->
            %{
              row: row,
              index: index,
              value_error: cell_error(assigns.error_for, index, assigns.value_field)
            }
          end)
      )

    ~H"""
    <div data-polaris-sv-array class={@container_classes} {@rest}>
      <div data-polaris-sv-rows class={@rows_wrapper_classes}>
        <%= for entry <- @rows do %>
          <div data-polaris-sv-row data-index={entry.index} class={@row_classes}>
            <div class="flex-1">
              <input
                type="text"
                name={"#{@id}-#{entry.index}-#{@value_field_name}"}
                value={fetch_field(entry.row, @value_field)}
                placeholder={@placeholder}
                aria-label={"#{@placeholder} #{entry.index + 1}"}
                phx-change={@on_change}
                phx-value-index={entry.index}
                phx-value-field={@value_field_name}
                class={@value_input_classes}
                autocomplete={@autocomplete}
                disabled={@disabled}
                data-polaris-sv-value
              />
              <p :if={entry.value_error} class="mt-1 text-xs text-danger" data-polaris-sv-error>
                {entry.value_error}
              </p>
            </div>
            <button
              type="button"
              phx-click={@on_remove}
              phx-value-index={entry.index}
              class={@remove_button_classes}
              aria-label={@remove_label}
              disabled={@disable_remove?}
              data-polaris-sv-remove
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="size-3.5"
                aria-hidden="true"
              >
                <path d="M3 6h18" />
                <path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" />
                <path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
              </svg>
            </button>
          </div>
        <% end %>
      </div>

      <div class="flex items-center" data-polaris-sv-add>
        <button
          type="button"
          phx-click={@on_add}
          class={@add_button_classes}
          disabled={@disabled}
          data-polaris-sv-add-button
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-3.5"
            aria-hidden="true"
          >
            <path d="M5 12h14" />
            <path d="M12 5v14" />
          </svg>
          {@add_label}
        </button>
      </div>
    </div>
    """
  end

  ## Row map lookups

  # Field lookup for row maps whose keys may be atoms or strings
  # (atom, then string, then charlist form), defaulting to "".
  defp fetch_field(row, field) when is_map(row) do
    case Enum.find(field_candidates(field), &Map.has_key?(row, &1)) do
      nil -> ""
      key -> empty_if_nil(row[key])
    end
  end

  defp fetch_field(_row, _field), do: ""

  defp field_candidates(field) do
    string_form = to_string(field)

    [field, string_form, String.to_charlist(string_form), existing_atom(string_form)]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp existing_atom(form) do
    String.to_existing_atom(form)
  rescue
    ArgumentError -> nil
  end

  defp empty_if_nil(nil), do: ""
  defp empty_if_nil(value), do: value

  defp cell_error(nil, _index, _field), do: nil

  defp cell_error(errors, index, field) when is_map(errors) do
    case Map.get(errors, "#{index}-#{to_string(field)}") do
      message when message in [nil, ""] -> nil
      message -> message
    end
  end
end
