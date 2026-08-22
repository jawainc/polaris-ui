defmodule PolarisUI.Components.FilterBar do
  @moduledoc """
  The Polaris filter bar: a search-style bar for building structured
  filters — condition chips (`property operator value`) inside a
  freeform search input, the port of the Supabase design system fragment
  `ui-patterns/FilterBar`.

  The React fragment owns a fully client-side recursive filter tree with
  Radix popovers; in LiveView the filter state belongs on the server, so
  this port keeps the anatomy, styling, and microcopy 1:1 while the
  popover pickers become server round trips:

    * the freeform input drives `on_search` on every keystroke and
      commits via `on_add` on **Enter** (the property picker your
      `handle_event` opens replaces the React dropdown);
    * each chip's property label is a button firing `on_property_click`
      with the chip `index` (change-property flow);
    * the operator and value segments are real inputs firing
      `on_operator_change` / `on_change` with the chip `index`;
    * the ✕ button removes the condition via `on_remove`;
    * `on_toggle` flips the group's `AND`/`OR` (rendered between chips
      when `supports_operators`);
    * **Enter** in a value input and **blur leaving the bar** push
      `on_apply` — the commit boundary, matching the fragment's
      two-tier `onFilterChange`/`onApply` split.

  ## Anatomy

      <.filter_bar
        id="table-filters"
        properties={@filter_properties}
        filters={@filters}
        freeform_text={@search}
        on_search="filter-search"
        on_add="filter-add"
        on_change="filter-change"
        on_remove="filter-remove"
        on_apply="filters-applied"
      />

    * **bar** — the chrome-owning container: panel fill, border,
      hover/focus states, `cursor-text` (clicking anywhere focuses the
      freeform input), horizontal scroll when chips overflow.
    * **icon area** — the search glyph (a spinner while `loading`),
      click-focuses the input like the fragment.
    * **chips** — one per condition map in `filters`:
      `[property label][operator][value][✕]`, `h-[26px]`, separated by
      the AND/OR toggle when `supports_operators`. The operator and
      value inputs auto-size to their content via the mirror-span
      trick from the fragment.
    * **freeform input** — the trailing input whose placeholder teaches
      the grammar: `"Filter by Name, Status, Type..."` (three labels
      then ellipsis), `"Add filters..."` with no properties, and
      `"Add more filters..."` once conditions exist.

  ## Data shapes

      properties: [%{name: "status", label: "Status", type: "string",
                     operators: ["=", "!="], options: ["active", ...]}]
      filters:    [%{property: "status", operator: "=", value: "active"}]

  `operators`/`options` are informational for the picker you build
  server-side; the bar renders whatever condition maps it is given and
  falls back to the property `name` when the label is unknown.

  ## States

    * **rest / hover** — border brightens on hover; clicking empty bar
      space focuses the input.
    * **focus** — the bar ring (shared emerald focus treatment) shows
      while anything inside has focus.
    * **loading** — the chip row pulses (the framer-motion opacity
      loop) and the search glyph becomes a spinner.
    * **error** — pass `error` to render the fragment's red hint line
      under the bar (e.g. "Failed to load options").
    * **disabled** — drive it from your LiveView by ignoring events;
      the bar itself has no lock state (like the fragment).

  ## Accessibility

    * Chip segments carry labelled inputs — `aria-label="Operator for
      {label}"` / `"Value for {label}"` — and the ✕ button
      `aria-label="Remove {label} filter"`, exactly like the fragment.
    * The AND/OR toggle is a real button (the fragment renders a bare
      span) with an `aria-label` describing the switch.
    * The freeform input carries `aria-label="Add filter"`; password
      managers are suppressed on it.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @variants ~w(default pill)
  @logical_operators ~w(AND OR)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the bar root — required because the colocated hook that
    manages focus/commit behavior anchors on it. The freeform input id
    derives as `"<id>-freeform"`.
    """
  )

  attr(:properties, :list,
    required: true,
    doc: """
    Filterable property maps — `%{name:, label:, type:, operators: [...],
    options: [...]}`. Drives the generated placeholder; label lookups
    fall back to `name`.
    """
  )

  attr(:filters, :list,
    default: [],
    doc: """
    Active condition maps — `%{property: "status", operator: "=", value:
    "active"}` — rendered as chips in order.
    """
  )

  attr(:logical_operator, :string,
    values: @logical_operators,
    default: "AND",
    doc: "The group's logical operator, rendered between chips when `supports_operators`."
  )

  attr(:supports_operators, :boolean,
    default: false,
    doc: "Render the AND/OR toggle between chips (clicking pushes `on_toggle`)."
  )

  attr(:variant, :string,
    values: @variants,
    default: "default",
    doc:
      "`default` — seam-connected chips with border separators; `pill` — bordered rounded chips."
  )

  attr(:freeform_text, :string,
    default: "",
    doc: "Controlled value of the freeform input (keep it synced from `on_search`)."
  )

  attr(:loading, :boolean,
    default: false,
    doc: "Pulse the chip row and swap the search glyph for a spinner."
  )

  attr(:error, :string,
    default: nil,
    doc: "Red hint line under the bar — e.g. \"Failed to load options for Status\"."
  )

  attr(:placeholder, :string,
    default: nil,
    doc: "Override the generated placeholder (\"Filter by Name, Status, ...\")."
  )

  attr(:on_search, :string,
    default: nil,
    doc: "LiveView event for freeform keystrokes (phx-change; add `phx-debounce`)."
  )

  attr(:on_add, :string,
    default: nil,
    doc: "LiveView event pushed on Enter in the freeform input (payload: the typed value)."
  )

  attr(:on_property_click, :string,
    default: nil,
    doc: "LiveView event for the chip property label (phx-click, receives `index`)."
  )

  attr(:on_operator_change, :string,
    default: nil,
    doc: "LiveView event for an operator edit (phx-change, receives `index`)."
  )

  attr(:on_change, :string,
    default: nil,
    doc: "LiveView event for a value edit (phx-change, receives `index`)."
  )

  attr(:on_remove, :string,
    default: nil,
    doc: "LiveView event for the chip ✕ (phx-click, receives `index`)."
  )

  attr(:on_toggle, :string,
    default: nil,
    doc: "LiveView event for the AND/OR toggle (phx-click)."
  )

  attr(:on_apply, :string,
    default: nil,
    doc: "LiveView event pushed on Enter in a value input and when focus leaves the bar."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the bar container — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  def filter_bar(assigns) do
    validate_in!(:variant, assigns.variant, @variants)
    validate_in!(:logical_operator, assigns.logical_operator, @logical_operators)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Bar",
        placeholder:
          assigns.placeholder || build_placeholder(assigns.properties, assigns.filters),
        icon_area_classes:
          cn([
            "relative flex shrink-0 cursor-pointer items-center justify-center px-2",
            "text-content-muted transition-colors hover:text-content-secondary",
            if(assigns.variant == "default",
              do: "border-r border-surface-border bg-surface-panel-hover",
              else: "bg-transparent"
            )
          ]),
        bar_classes:
          cn([
            "relative flex w-full cursor-text items-stretch gap-0 overflow-auto rounded-md",
            "border border-surface-border bg-surface-panel pr-2 transition-colors",
            "hover:border-surface-border-hover",
            "focus-within:border-surface-border-hover focus-within:outline-none",
            "focus-within:ring-2 focus-within:ring-brand-emerald focus-within:ring-offset-2",
            "focus-within:ring-offset-surface-ground",
            assigns.class
          ]),
        row_classes:
          cn([
            "flex flex-1 flex-wrap items-stretch gap-0",
            if(assigns.variant == "pill", do: "gap-1 py-1"),
            if(assigns.loading, do: "animate-pulse")
          ])
      )

    ~H"""
    <div
      id={@id}
      class="relative w-full"
      data-polaris-filter-bar
      phx-hook={@hook}
      data-add-event={@on_add}
      data-apply-event={@on_apply}
      {@rest}
    >
      <div class="flex h-full min-h-[32px] items-stretch">
        <div class={@bar_classes} data-polaris-filter-bar-bar>
          <div class={@icon_area_classes} data-polaris-filter-bar-icon aria-hidden="true">
            <%= if @loading do %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                class="size-4 animate-spin text-content-secondary"
              >
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" opacity="0.2" />
                <path
                  d="M22 12a10 10 0 0 0-10-10"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                />
              </svg>
            <% else %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="size-4"
              >
                <circle cx="11" cy="11" r="8" />
                <path d="m21 21-4.3-4.3" />
              </svg>
            <% end %>
          </div>
          <div class={@row_classes} data-polaris-filter-bar-conditions>
            <%= for {condition, index} <- Enum.with_index(@filters) do %>
              <% label = property_label(@properties, condition.property) %>
              <button
                :if={index > 0 and @supports_operators}
                type="button"
                phx-click={@on_toggle}
                class="my-auto cursor-pointer px-0.5 text-xs font-medium text-content-muted transition-colors hover:text-content-secondary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"
                aria-label={"Switch logical operator to #{@logical_operator == "AND" && "OR" || "AND"}"}
                data-polaris-filter-bar-logical
              >
                {@logical_operator}
              </button>
              <div
                class={
                  cn([
                    "group flex h-[26px] shrink-0 items-stretch bg-surface-panel-hover",
                    if(@variant == "default",
                      do: "border-r border-surface-border",
                      else: "rounded-sm border border-surface-border"
                    )
                  ])
                }
                data-polaris-filter-condition={condition.property}
                data-index={index}
              >
                <button
                  type="button"
                  phx-click={@on_property_click}
                  phx-value-index={index}
                  class="flex h-full shrink-0 cursor-pointer items-center whitespace-nowrap pl-2 pr-1 text-xs text-content-secondary transition-colors hover:text-content-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"
                  aria-label={"Change property from #{label}"}
                  data-polaris-filter-property={condition.property}
                >
                  {label}
                </button>
                <div class="relative inline-block" data-polaris-filter-operator-segment>
                  <input
                    type="text"
                    name={"#{@id}-operator-#{index}"}
                    value={condition.operator}
                    phx-change={@on_operator_change}
                    phx-value-index={index}
                    class="absolute left-0 top-0 h-full w-full border-none bg-transparent px-1 text-center text-xs text-content-primary focus:outline-none"
                    aria-label={"Operator for #{label}"}
                    autocomplete="off"
                    data-polaris-filter-operator={condition.property}
                  />
                  <span class="invisible block whitespace-pre px-1 text-xs">{condition.operator || " "}</span>
                </div>
                <div class="relative inline-block max-w-[180px]" data-polaris-filter-value-segment>
                  <input
                    type="text"
                    name={"#{@id}-value-#{index}"}
                    value={condition.value}
                    phx-change={@on_change}
                    phx-value-index={index}
                    class="absolute left-0 top-0 h-full w-full border-none bg-transparent px-1 text-xs text-content-primary focus:outline-none"
                    aria-label={"Value for #{label}"}
                    autocomplete="off"
                    data-polaris-filter-value={condition.property}
                  />
                  <span class="invisible block whitespace-pre px-1 text-xs">{condition.value || " "}</span>
                </div>
                <button
                  type="button"
                  phx-click={@on_remove}
                  phx-value-index={index}
                  class="group/remove flex cursor-pointer items-center px-1 text-content-muted transition-colors hover:text-content-primary group-hover:text-content-secondary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"
                  aria-label={"Remove #{label} filter"}
                  tabindex="-1"
                  data-polaris-filter-remove={condition.property}
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="size-3"
                    aria-hidden="true"
                  >
                    <path d="M18 6 6 18" />
                    <path d="m6 6 12 12" />
                  </svg>
                </button>
              </div>
            <% end %>
            <input
              type="text"
              id={"#{@id}-freeform"}
              name={"#{@id}-search"}
              value={@freeform_text}
              placeholder={@placeholder}
              phx-change={@on_search}
              class="h-auto w-full min-w-[120px] flex-1 border-none bg-transparent px-2 py-1 text-xs text-content-primary placeholder:text-content-muted focus:border-transparent focus:outline-none"
              aria-label="Add filter"
              autocomplete="off"
              spellcheck="false"
              data-1p-ignore
              data-lpignore="true"
              data-form-type="other"
              data-bwignore
              data-polaris-filter-bar-input
            />
          </div>
        </div>
      </div>
      <p :if={@error} class="mt-1 text-xs text-danger" data-polaris-filter-bar-error>
        {@error}
      </p>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Bar" runtime>
      {
        mounted() {
          const root = this.el
          const input = root.querySelector("[data-polaris-filter-bar-input]")
          this._focusInput = () => {
            if (input) {
              input.focus()
            }
          }
          // Clicking the bar's empty space or the icon focuses the freeform
          // input (the fragment's cursor-text affordance).
          this._onBarClick = (event) => {
            if (event.target.closest("input, button, a")) {
              return
            }
            this._focusInput()
          }
          root.addEventListener("click", this._onBarClick)
          const icon = root.querySelector("[data-polaris-filter-bar-icon]")
          if (icon) {
            this._onIconClick = () => this._focusInput()
            icon.addEventListener("click", this._onIconClick)
          }
          this._onKeydown = (event) => {
            if (event.key === "Enter") {
              if (event.target === input) {
                const addEvent = root.dataset.addEvent
                if (addEvent && typeof this.pushEvent === "function") {
                  event.preventDefault()
                  this.pushEvent(addEvent, { value: input.value })
                }
              } else if (event.target.matches("input[data-polaris-filter-value]")) {
                const applyEvent = root.dataset.applyEvent
                if (applyEvent && typeof this.pushEvent === "function") {
                  event.preventDefault()
                  this.pushEvent(applyEvent)
                }
              }
            } else if (event.key === "Escape") {
              event.target.blur()
            }
          }
          root.addEventListener("keydown", this._onKeydown)
          // Commit boundary: focus leaving the whole bar applies filters,
          // like the fragment's deferred-blur onApply.
          this._onFocusOut = (event) => {
            if (!root.contains(event.relatedTarget)) {
              const applyEvent = root.dataset.applyEvent
              if (applyEvent && typeof this.pushEvent === "function") {
                this.pushEvent(applyEvent)
              }
            }
          }
          root.addEventListener("focusout", this._onFocusOut)
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onBarClick)
          this.el.removeEventListener("keydown", this._onKeydown)
          this.el.removeEventListener("focusout", this._onFocusOut)
          const icon = this.el.querySelector("[data-polaris-filter-bar-icon]")
          if (icon && this._onIconClick) {
            icon.removeEventListener("click", this._onIconClick)
          }
        }
      }
    </script>
    """
  end

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end

  # The fragment's buildFilterPlaceholder: up to three property labels,
  # ellipsis when more, "Add filters..." when none; existing conditions
  # switch the trailing input to "Add more filters...".
  defp build_placeholder(_properties, filters) when filters != [], do: "Add more filters..."
  defp build_placeholder([], _filters), do: "Add filters..."

  defp build_placeholder(properties, _filters) do
    labels = properties |> Enum.take(3) |> Enum.map(&label_of/1) |> Enum.join(", ")
    suffix = if length(properties) > 3, do: "...", else: ""
    "Filter by #{labels}#{suffix}"
  end

  defp label_of(%{label: label}), do: label
  defp label_of(property) when is_map(property), do: Map.get(property, :name, "")

  # Property label lookup with name fallback (unknown properties still
  # render their name so server-driven conditions never blank out).
  defp property_label(properties, name) do
    case Enum.find(properties, &(&1.name == name)) do
      %{label: label} -> label
      _ -> to_string(name)
    end
  end
end
