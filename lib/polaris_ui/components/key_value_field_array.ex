defmodule PolarisUI.Components.KeyValueFieldArray do
  @moduledoc """
  The Polaris key/value field array: a rendering-only editor for repeated
  text/text pairs — HTTP headers, environment variables, tags — the port
  of the Supabase design system fragment
  `ui-patterns/form/KeyValueFieldArray`.

  The React fragment is a `react-hook-form` `useFieldArray` that owns its
  rows client-side and delegates validation to the consumer's resolver.
  In LiveView the rows belong on the server, so this port keeps the
  anatomy, styling, and microcopy 1:1 while every mutation becomes a
  LiveView event:

    * `fields` renders the rows your LiveView owns — each row is a plain
      map and the component never mutates it;
    * editing a cell pushes `on_change` with the row `index` and the
      `field` being edited (`phx-value-index` / `phx-value-field`);
    * the Add button pushes `on_add` (your handler appends the empty
      row — the fragment's `createEmptyRow`);
    * the row ✕ pushes `on_remove` with `index`;
    * `add_actions` turns Add into a split button: the chevron pushes
      `on_toggle_add` (your handler flips `add_menu_open` server-side)
      and a menu item pushes `on_add_action` — or the item's own
      `action` event — with `phx-value-key` (your handler decides which
      rows to append — the fragment's `createRows`);
    * validation stays with the consumer: call `validation_issues/1`
      from your changeset and pass a lookup built from its paths as
      `error_for` to render the fragment's nested per-cell
      `FormMessage`s.

  ## Anatomy

      <.key_value_field_array
        id="headers"
        fields={@headers}
        key_field={:name}
        value_field={:value}
        key_placeholder="Header name"
        value_placeholder="Header value"
        add_label="Add header"
        remove_label="Remove header"
        on_change="header-change"
        on_add="header-add"
        on_remove="header-remove"
        error_for={@header_errors}
      />

    * **rows** — one `flex` row per entry in `fields`: a key cell
      (`flex-1`), a value cell (`flex-1`), and the icon-only ✕ button.
      Each cell is a small (`h-[34px]`) text input with the shared input
      shell (border, panel fill, emerald focus ring) and an optional red
      hint line beneath.
    * **add row** — the Add button, a split-button chevron when
      `add_actions` is given, and — when `add_menu_open` — the dropdown
      menu of extra add options (labels, optional descriptions, and
      separator rules above items).

  ## Data shapes

      fields:      [%{name: "x-client-info", value: "studio"}]
      add_actions: [%{key: "auth", label: "Authorization header",
                      description: "Adds a Bearer token row"},
                    %{key: "custom", label: "Custom header",
                      separator_above: true, action: "add-custom-header"}]
      error_for:   %{"0-name" => "Header name is required",
                     "1-value" => "Header value is required"}

  `key_field`/`value_field` name the row map keys and may be atoms or
  strings (looked up as atom, then string); input names derive as
  `"<id>-<index>-<key_field>"` / `"<id>-<index>-<value_field>"`.
  `error_for` is keyed `"<index>-<key_field>"` /
  `"<index>-<value_field>"` (string keys) — build it straight from
  `validation_issues/1` paths:

      error_for =
        Map.new(issues, fn %{path: [index, field], message: message} ->
          {"\#{index}-\#{field}", message}
        end)

  ## Microcopy

  Per the Supabase copywriting guidelines the placeholders describe the
  pair type, not the generic "Key"/"Value": "Header name"/"Header value"
  for HTTP headers, "Variable"/"Value" for environment variables. The
  add label is a direct verb — "Add header", "Add variable" — and its
  noun carries into the remove label ("Remove header"). Required and
  duplicate messages follow `validation_issues/1`.

  ## States

    * **rest / hover** — input and button borders brighten
      (`hover:border-surface-border-hover`).
    * **focus** — inputs and buttons show the shared emerald ring
      (`focus:ring-2 focus:ring-brand-emerald` on inputs,
      `focus-visible:ring-2 ...` on buttons); split-button halves keep
      the seam square while focused (`focus-visible:rounded-r-sm` /
      `focus-visible:rounded-l-sm`).
    * **disabled** — every input and button is disabled at once
      (`disabled:cursor-not-allowed disabled:opacity-50`); also ignore
      the events server-side.
    * **error** — pass `error_for` to render the red hint line
      (`text-xs text-danger`) under the offending cell, like the
      fragment's nested `FormMessage`.

  Rendering-only: no colocated hook and no client state — the server
  round trips own everything.
  """

  use PolarisUI.Component

  @input_shell "border border-surface-border bg-surface-panel transition-colors hover:border-surface-border-hover focus:border-surface-border-hover focus:outline-none focus:ring-2 focus:ring-brand-emerald focus:ring-offset-2 focus:ring-offset-surface-ground rounded-md"
  @input_size_classes "h-[34px] w-full px-2 text-sm"
  @button_focus_ring "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground rounded-md"
  @disabled_classes "disabled:cursor-not-allowed disabled:opacity-50"
  @remove_button_chrome "flex items-center justify-center rounded-md border border-surface-border bg-surface-panel text-content-muted transition-colors hover:border-surface-border-hover hover:text-content-secondary"
  @remove_button_size "h-[34px] w-[34px] shrink-0"
  @add_button_chrome "flex h-[34px] items-center gap-1.5 rounded-md border border-surface-border bg-surface-panel px-3 text-sm text-content-primary transition-colors hover:border-surface-border-hover"
  @split_add_classes "rounded-r-none px-3 hover:z-10 focus-visible:z-10 focus-visible:rounded-r-sm"
  @toggle_button_classes "flex h-[34px] w-9 shrink-0 items-center justify-center rounded-l-none border border-l-0 border-surface-border bg-surface-panel text-content-muted transition-colors hover:border-surface-border-hover hover:text-content-secondary -ml-px focus-visible:z-10 focus-visible:rounded-l-sm"
  @add_menu_classes "absolute left-0 top-full z-50 mt-1 min-w-[220px] rounded-md border border-surface-border bg-surface-panel p-1 shadow-lg"
  @add_menu_item_classes "flex w-full flex-col items-start gap-0.5 rounded-sm px-2 py-1.5 text-left text-sm transition-colors hover:bg-surface-panel-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the array root. Row input names derive from it:
    `"<id>-<index>-<key_field>"` / `"<id>-<index>-<value_field>"`.
    """
  )

  attr(:fields, :list,
    required: true,
    doc: """
    The rows your LiveView owns — maps like
    `%{name: "x-client-info", value: "studio"}`, rendered in order.
    """
  )

  attr(:key_field, :any,
    required: true,
    doc: """
    The row map key holding the key text (the React `keyFieldName`) —
    atom or string. Fetched as atom, then string, so either row shape
    works.
    """
  )

  attr(:value_field, :any,
    required: true,
    doc: "The row map key holding the value text — atom or string, like `key_field`."
  )

  attr(:on_change, :string,
    default: nil,
    doc: "LiveView event for cell edits (phx-change; receives `index` and `field`)."
  )

  attr(:on_add, :string,
    default: nil,
    doc: "LiveView event for the Add button (phx-click; append the empty row server-side)."
  )

  attr(:on_remove, :string,
    default: nil,
    doc: "LiveView event for the row ✕ (phx-click; receives `index`)."
  )

  attr(:add_actions, :list,
    default: [],
    doc: """
    Extra add options for the split-button dropdown — maps with `key`,
    `label`, optional `description`, optional `separator_above`, and an
    optional per-item `action` event name. When non-empty the Add
    button gains the split-button chrome and the chevron toggle.
    """
  )

  attr(:on_add_action, :string,
    default: nil,
    doc: "LiveView event for dropdown menu items (phx-click; receives `key`)."
  )

  attr(:on_toggle_add, :string,
    default: nil,
    doc: "LiveView event for the split-button chevron (phx-click; open the menu server-side)."
  )

  attr(:add_menu_open, :boolean,
    default: false,
    doc: "Render the add-actions dropdown menu open (your LiveView owns the state)."
  )

  attr(:key_placeholder, :string,
    required: true,
    doc: "Placeholder for key inputs — describe the pair type (\"Header name\")."
  )

  attr(:value_placeholder, :string,
    required: true,
    doc: "Placeholder for value inputs — describe the pair type (\"Header value\")."
  )

  attr(:add_label, :string,
    required: true,
    doc: "The Add button's verb phrase — a direct verb (\"Add header\")."
  )

  attr(:remove_label, :string,
    default: "Remove row",
    doc: "aria-label for the row ✕ button — carry the add label's noun (\"Remove header\")."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Disable every input and button in the array at once."
  )

  attr(:error_for, :map,
    default: nil,
    doc: """
    Optional per-cell error strings keyed by string
    `"<index>-<key_field>"` / `"<index>-<value_field>"` — e.g.
    `%{"0-name" => "Header name is required"}` — rendered as a red hint
    line under the row's input, mirroring the React `FormMessage`.
    Build it from `validation_issues/1` paths.
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

  attr(:key_input_class, :string,
    default: nil,
    doc: "Additional classes merged onto each key input."
  )

  attr(:value_input_class, :string,
    default: nil,
    doc: "Additional classes merged onto each value input."
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

  def key_value_field_array(assigns) do
    has_add_actions? = assigns.add_actions != []

    assigns =
      assigns
      |> assign(
        has_add_actions?: has_add_actions?,
        key_field_name: to_string(assigns.key_field),
        value_field_name: to_string(assigns.value_field),
        container_classes: cn(["space-y-3", assigns.class]),
        rows_wrapper_classes: cn(["mt-1 space-y-3", assigns.rows_class]),
        row_classes: cn(["flex items-start space-x-2", assigns.row_class]),
        key_input_classes: cn([@input_shell, @input_size_classes, assigns.key_input_class]),
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
            if(has_add_actions?, do: @split_add_classes),
            @disabled_classes,
            assigns.add_button_class
          ]),
        toggle_button_classes:
          cn([@button_focus_ring, @toggle_button_classes, @disabled_classes]),
        add_menu_classes: @add_menu_classes,
        add_menu_item_classes: @add_menu_item_classes,
        rows:
          assigns.fields
          |> Enum.with_index()
          |> Enum.map(fn {row, index} ->
            %{
              row: row,
              index: index,
              key_error: cell_error(assigns.error_for, index, assigns.key_field),
              value_error: cell_error(assigns.error_for, index, assigns.value_field)
            }
          end)
      )

    ~H"""
    <div data-polaris-kv-array class={@container_classes} {@rest}>
      <div data-polaris-kv-rows class={@rows_wrapper_classes}>
        <%= for entry <- @rows do %>
          <div data-polaris-kv-row data-index={entry.index} class={@row_classes}>
            <div class="flex-1" data-polaris-kv-key-cell>
              <input
                type="text"
                name={"#{@id}-#{entry.index}-#{@key_field_name}"}
                value={fetch_field(entry.row, @key_field)}
                placeholder={@key_placeholder}
                aria-label={"#{@key_placeholder} #{entry.index + 1}"}
                phx-change={@on_change}
                phx-value-index={entry.index}
                phx-value-field={@key_field_name}
                class={@key_input_classes}
                autocomplete="off"
                disabled={@disabled}
                data-polaris-kv-key
              />
              <p :if={entry.key_error} class="mt-1 text-xs text-danger" data-polaris-kv-error>
                {entry.key_error}
              </p>
            </div>
            <div class="flex-1" data-polaris-kv-value-cell>
              <input
                type="text"
                name={"#{@id}-#{entry.index}-#{@value_field_name}"}
                value={fetch_field(entry.row, @value_field)}
                placeholder={@value_placeholder}
                aria-label={"#{@value_placeholder} #{entry.index + 1}"}
                phx-change={@on_change}
                phx-value-index={entry.index}
                phx-value-field={@value_field_name}
                class={@value_input_classes}
                autocomplete="off"
                disabled={@disabled}
                data-polaris-kv-value
              />
              <p :if={entry.value_error} class="mt-1 text-xs text-danger" data-polaris-kv-error>
                {entry.value_error}
              </p>
            </div>
            <button
              type="button"
              phx-click={@on_remove}
              phx-value-index={entry.index}
              class={@remove_button_classes}
              aria-label={@remove_label}
              disabled={@disabled}
              data-polaris-kv-remove
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

      <div class="relative flex items-center" data-polaris-kv-add>
        <button
          type="button"
          phx-click={@on_add}
          class={@add_button_classes}
          disabled={@disabled}
          data-polaris-kv-add-button
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
        <button
          :if={@has_add_actions?}
          type="button"
          phx-click={@on_toggle_add}
          aria-label={"#{@add_label} options"}
          class={@toggle_button_classes}
          disabled={@disabled}
          data-polaris-kv-add-toggle
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
            <path d="m6 9 6 6 6-6" />
          </svg>
        </button>
        <div
          :if={@add_menu_open and @has_add_actions?}
          class={@add_menu_classes}
          data-polaris-kv-add-menu
        >
          <%= for action <- @add_actions do %>
            <div
              :if={present?(fetch_field(action, :separator_above))}
              class="my-1 border-t border-surface-border"
              data-polaris-kv-add-separator
            >
            </div>
            <button
              type="button"
              phx-click={action_event(action, @on_add_action)}
              phx-value-key={fetch_field(action, :key)}
              class={@add_menu_item_classes}
              data-polaris-kv-add-item
            >
              <span class="text-content-primary">{fetch_field(action, :label)}</span>
              <span
                :if={present?(fetch_field(action, :description))}
                class="text-xs text-content-secondary"
              >
                {fetch_field(action, :description)}
              </span>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Per-cell validation issues for draft-friendly key/value rows — the port
  of the fragment's `getKeyValueFieldArrayValidationIssues`. The
  component is rendering-only: call this from your changeset (or before
  render) and feed the result into `error_for`.

  ## Rules (mirroring the fragment)

    * values are trimmed before every check; non-string values count as
      empty;
    * a row whose key *and* value are empty is skipped — draft rows are
      not errors — unless `allow_empty_rows` is `false`;
    * a row with a value but no key flags `key_required_message` on the
      key cell only, and never participates in duplicate checks;
    * a row with a key but no value flags `value_required_message` on
      the value cell and — like missing-key rows — also skips duplicate
      checks (the fragment returns before tracking incomplete rows);
    * when duplicate checking is on, every occurrence of a duplicated
      key (the first included) is flagged, after all per-row issues,
      comparing keys through `normalise_key` (identity by default).

  ## Options

    * `:rows` — the field-array rows (list of maps). Defaults to `[]`.
    * `:key_field`, `:value_field` — atom or string field names, looked
      up with the component's semantics (atom, then string).
    * `:key_required_message` — defaults to `"Key is required"`.
    * `:value_required_message` — defaults to `"Value is required"`.
    * `:duplicate_key_message` — defaults to `"Duplicate key"`; `nil`
      or `false` disables duplicate checks entirely.
    * `:allow_empty_rows` — defaults to `true`.
    * `:normalise_key` — 1-arity fun applied before duplicate
      comparison (e.g. `&String.downcase/1`).

  Accepts a keyword list or a map.

  ## Examples

      iex> validation_issues(rows: [], key_field: :name, value_field: :value)
      []

      iex> validation_issues(rows: [%{name: "x-client-info", value: "studio"}], key_field: :name, value_field: :value)
      []

  Fully empty (or whitespace-only) rows are draft-friendly by default:

      iex> validation_issues(rows: [%{name: "", value: ""}, %{name: "  ", value: " \t "}], key_field: :name, value_field: :value)
      []

  ...unless `allow_empty_rows` is `false`, which flags both cells:

      iex> issues = validation_issues(rows: [%{name: "", value: ""}], key_field: :name, value_field: :value, allow_empty_rows: false)
      iex> Enum.map(issues, & &1.path)
      [[0, "name"], [0, "value"]]

  A missing key flags only the key cell:

      iex> validation_issues(rows: [%{name: "  ", value: "studio"}], key_field: :name, value_field: :value)
      [%{message: "Key is required", path: [0, "name"]}]

  A missing value flags the value cell only — incomplete rows never
  collide with complete ones in duplicate checks:

      iex> rows = [%{name: "accept", value: ""}, %{name: "accept", value: "json"}]
      iex> validation_issues(rows: rows, key_field: :name, value_field: :value)
      [%{message: "Value is required", path: [0, "value"]}]

  Duplicates flag *every* occurrence (the first included), trimmed
  before comparing:

      iex> rows = [%{name: " x-client-info ", value: "studio"}, %{name: "x-client-info", value: "edge"}]
      iex> issues = validation_issues(rows: rows, key_field: :name, value_field: :value)
      iex> Enum.map(issues, & &1.path)
      [[0, "name"], [1, "name"]]

  Custom messages and string field names work too:

      iex> opts = %{rows: [%{"name" => "a"}], key_field: "name", value_field: "value", value_required_message: "Header value is required"}
      iex> validation_issues(opts)
      [%{message: "Header value is required", path: [0, "value"]}]

  `nil` duplicate messages disable duplicate checks:

      iex> rows = [%{name: "a", value: "1"}, %{name: "a", value: "2"}]
      iex> validation_issues(rows: rows, key_field: :name, value_field: :value, duplicate_key_message: nil)
      []
  """
  @spec validation_issues(keyword() | map()) :: [
          %{path: [non_neg_integer() | String.t()], message: String.t()}
        ]
  def validation_issues(opts) when is_list(opts) or is_map(opts) do
    opts = if is_map(opts), do: Map.to_list(opts), else: opts

    rows = opt(opts, :rows, [])
    key_field = opt(opts, :key_field, "")
    value_field = opt(opts, :value_field, "")
    key_required_message = opt(opts, :key_required_message, "Key is required")
    value_required_message = opt(opts, :value_required_message, "Value is required")
    duplicate_key_message = opt(opts, :duplicate_key_message, "Duplicate key")
    allow_empty_rows? = opt(opts, :allow_empty_rows, true)
    normalise_key = opt(opts, :normalise_key, nil)

    track_duplicates? = duplicate_key_message not in [nil, false]

    normalise =
      case normalise_key do
        nil -> fn key -> key end
        fun when is_function(fun, 1) -> fun
      end

    key_name = to_string(key_field)
    value_name = to_string(value_field)

    {row_issues, groups} =
      Enum.reduce(
        Enum.with_index(rows),
        {[], %{}},
        fn {row, index}, {issues, groups} ->
          key = trimmed_string(fetch_field(row, key_field))
          value = trimmed_string(fetch_field(row, value_field))

          cond do
            key == "" and value == "" ->
              if allow_empty_rows? do
                {issues, groups}
              else
                {
                  [
                    issue(index, value_name, value_required_message),
                    issue(index, key_name, key_required_message) | issues
                  ],
                  groups
                }
              end

            key == "" ->
              {[issue(index, key_name, key_required_message) | issues], groups}

            true ->
              # The fragment returns before duplicate tracking when the
              # value is missing, so incomplete rows never collide with
              # complete ones.
              if value == "" do
                {[issue(index, value_name, value_required_message) | issues], groups}
              else
                groups =
                  if track_duplicates? do
                    case normalise.(key) do
                      normalised when normalised in [nil, false, ""] -> groups
                      normalised -> Map.update(groups, normalised, [index], &[index | &1])
                    end
                  else
                    groups
                  end

                {issues, groups}
              end
          end
        end
      )

    # Groups iterate in first-occurrence order (the JS Map insertion
    # order) and every occurrence of a duplicated key is flagged.
    duplicate_issues =
      groups
      |> Enum.map(fn {_normalised, indexes} -> Enum.reverse(indexes) end)
      |> Enum.filter(&(length(&1) > 1))
      |> Enum.sort_by(&hd/1)
      |> Enum.flat_map(fn indexes ->
        Enum.map(indexes, &issue(&1, key_name, duplicate_key_message))
      end)

    Enum.reverse(row_issues) ++ duplicate_issues
  end

  ## Row and action map lookups

  # Field lookup for row/action maps whose keys may be atoms or strings
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

  defp present?(value), do: value not in [nil, false, ""]

  # A menu item's own `action` event wins over the shared `on_add_action`.
  defp action_event(action, fallback) do
    case fetch_field(action, :action) do
      "" -> fallback
      event -> event
    end
  end

  defp cell_error(nil, _index, _field), do: nil

  defp cell_error(errors, index, field) when is_map(errors) do
    case Map.get(errors, "#{index}-#{to_string(field)}") do
      message when message in [nil, ""] -> nil
      message -> message
    end
  end

  ## Validation helpers

  defp opt(opts, key, default) do
    case List.keyfind(opts, key, 0) do
      {^key, value} -> value
      nil -> default
    end
  end

  # The fragment's getTrimmedString: strings are trimmed, anything else
  # counts as empty.
  defp trimmed_string(value) when is_binary(value), do: String.trim(value)
  defp trimmed_string(_value), do: ""

  defp issue(index, field_name, message), do: %{path: [index, field_name], message: message}
end
