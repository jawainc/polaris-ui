defmodule PolarisUI.Components.MultiSelect do
  @moduledoc """
  The Polaris multi-select: a combobox trigger that stacks removable value
  badges and opens a checklist popover — the port of the Supabase design
  system fragment `ui-patterns/MultiSelect`, built for dense dashboards
  and filter toolbars where several values must be picked in one control.

  ## Server-owned selection

  The React fragment is fully client-side: a `MultiSelectContext` holds
  `values`/`open`/`inputValue`/`activeIndex`, Radix owns the popover, and
  cmdk owns filtering plus keyboard navigation. In LiveView the selection
  belongs on the server, so this port keeps the anatomy, styling, and
  microcopy 1:1 while splitting the fragment's brain in two:

    * the **server** owns `values` — every option click, badge ✕, and
      backspace deletion pushes `on_change` with `%{"value" => v,
      "selected" => "true" | "false"}`, and the re-rendered badge row is
      the single source of truth;
    * the colocated **hook** owns only the view layer — popover
      open/close (with a simple flip when space below runs out), option
      filtering, arrow-key navigation, the creatable item, and
      backspace-to-delete. It holds no selection state, so the two
      layers can never drift.

  ## Anatomy

      <.multi_select
        id="fruit-picker"
        options={@fruits}
        values={@selected_fruits}
        on_change="fruit-toggled"
        label="Select fruits"
        placeholder="Search fruits"
        badge_limit={:wrap}
      />

    * **root** — `relative` wrapper carrying the hook and its event
      wiring (`data-change-event`, `data-create-event`,
      `data-creatable`, `data-mode`).
    * **trigger** — a `role="combobox"` button: empty renders the raised
      plate (`bg-surface-panel`), filled renders the sunk well
      (`bg-surface-base`) holding the value badges; the
      chevrons-up-down glyph closes it out (drop with `show_icon={false}`).
    * **badges** — one per selected value in `values` order, each with a
      ✕ (disable with `deletable_badge={false}`) and a `+K` overflow
      badge when `badge_limit` caps them.
    * **popover** — always in the DOM (`hidden` until the hook opens
      it): the search row (`combobox` mode only), the option list with
      checkbox-affordance rows, the creatable row, and the
      "No results found" empty state.

  ## Data shapes

      options: [%{value: "Apple", label: "Apple", disabled: false, description: nil}]
      values:  ["Apple", "Banana"]

  `value` is required per option; `label` defaults to `value`,
  `disabled` to `false`, and an optional `description` renders muted
  next to the label. Unknown `values` (no matching option) still render
  as badges using the raw value, so server-driven state never blanks
  out.

  ## badge_limit

    * `:wrap` — render every badge and let the trigger grow taller
      (`flex-wrap`);
    * integer `n` — show the first `n` badges, then a `+K` overflow
      badge (the hidden tail scrolls horizontally inside the trigger);
    * integer below `1` with several values — collapse to the
      `"N items selected"` form instead of `+K`.

  ## Modes

    * `combobox` (default) — the search input lives in the popover under
      a search row; the trigger shows badges only.
    * `inline-combobox` — the search input lives inside the trigger
      after the badges and the popover has no search row — the
      fragment's compact inline variant.

  ## Creatable

  Set `creatable` (plus `on_create`) to offer a `Create "x"` row when
  the filter matches nothing — the fragment's cmdk creatable item. It
  pushes `on_create` with `%{"value" => x}`; your LiveView decides
  whether the created value joins `values` (the item is inert without
  `on_create`).

  ## Keyboard map

    * **ArrowDown / ArrowUp** — cycle the highlighted option (wraps);
      **Home** / **End** jump to the first / last visible option.
    * **Enter** — select the highlighted option (the first visible one
      when none is highlighted); on the creatable row it creates.
    * **Escape** — close the popover and refocus the trigger.
    * **Backspace** in an empty search input — remove the last badge.

  ## Microcopy

  The `label` names the domain ("Select fruits"), the search
  `placeholder` narrows it ("Search fruits"), and `empty_label` covers
  the miss ("No results found"). With `persist_label` the label stays
  beside the badges instead of disappearing once values exist.

  ## States

    * **rest / hover** — the empty trigger is the raised plate, the
      filled one the sunk well; hover brightens the border.
    * **focus-within** — the shared emerald ring on the trigger.
    * **open** — the trigger border stays brightened while the popover
      is open.
    * **disabled** — `disabled` greys out the whole trigger;
      per-option `disabled` greys the row and blocks selection.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @modes ~w(combobox inline-combobox)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the root — the colocated hook anchors on it. Derived
    ids: `"<id>-search"` (search input), `"<id>-listbox"` (popover),
    `"<id>-label"` (label span), `"<id>-option-<index>"` (options).
    """
  )

  attr(:name, :string,
    default: nil,
    doc: """
    Form field name — when set, one hidden input per selected value is
    rendered (`name="name[]" value=...`) so the control submits with
    normal forms.
    """
  )

  attr(:options, :list,
    required: true,
    doc: """
    Option maps — `%{value: "Apple", label: "Apple", disabled: false,
    description: nil}`. `value` is required; `label` defaults to
    `value`, `disabled` to `false`; `description` renders muted next to
    the label.
    """
  )

  attr(:values, :list,
    default: [],
    doc: "Selected values (server-owned) — badges render in this order."
  )

  attr(:on_change, :string,
    required: true,
    doc: """
    LiveView event pushed on every select/deselect with payload
    `%{"value" => v, "selected" => "true" | "false"}` — also used by the
    badge ✕ and backspace removals.
    """
  )

  attr(:on_create, :string,
    default: nil,
    doc: "LiveView event for the creatable item (payload `%{\"value\" => x}`)."
  )

  attr(:disabled, :boolean, default: false, doc: "Disables the trigger.")

  attr(:label, :string,
    default: nil,
    doc: "Placeholder text inside the trigger — \"Select fruits\" names the domain."
  )

  attr(:persist_label, :boolean,
    default: false,
    doc: "Keep the label visible beside the badges even when values exist."
  )

  attr(:badge_limit, :any,
    default: 9999,
    doc: """
    Integer (first N badges then a `+K` overflow badge) or `:wrap` (all
    badges, wrapped). A limit below 1 collapses to
    "N items selected".
    """
  )

  attr(:deletable_badge, :boolean, default: true, doc: "Render the ✕ on each badge.")

  attr(:show_icon, :boolean,
    default: true,
    doc: "Render the chevrons-up-down icon on the trigger."
  )

  attr(:mode, :string,
    values: @modes,
    default: "combobox",
    doc: """
    `combobox` — search input in the popover; `inline-combobox` — search
    input inside the trigger (popover has no search row).
    """
  )

  attr(:creatable, :boolean,
    default: false,
    doc: "Offer the `Create \"x\"` item when the filter matches nothing (needs `on_create`)."
  )

  attr(:placeholder, :string,
    default: "Search",
    doc: "Placeholder for the search input — \"Search fruits\" narrows the domain."
  )

  attr(:empty_label, :string,
    default: "No results found",
    doc: "Text for the filtered-empty state."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the trigger button — caller classes win via `cn/1`."
  )

  attr(:popover_class, :string,
    default: nil,
    doc: "Additional classes merged onto the popover."
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  def multi_select(assigns) do
    validate_in!(:mode, assigns.mode, @modes)
    validate_badge_limit!(assigns.badge_limit)

    options = normalize_options(assigns.options)
    wrap? = assigns.badge_limit == :wrap

    visible_values =
      if wrap?, do: assigns.values, else: Enum.take(assigns.values, assigns.badge_limit)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Select",
        options: options,
        wrap: wrap?,
        visible_values: visible_values,
        extra_count: length(assigns.values) - length(visible_values),
        overflow_text:
          overflow_text(
            assigns.badge_limit,
            wrap?,
            length(assigns.values) - length(visible_values)
          ),
        label_visibility: label_visibility(assigns),
        trigger_classes:
          cn([
            "flex min-h-[34px] w-full min-w-[200px] items-center justify-between gap-1 rounded-md border px-3 py-1.5 text-sm transition-colors",
            "border-surface-border",
            # Empty: raised plate. Filled: sunk well for the badges.
            if(assigns.values == [], do: "bg-surface-panel", else: "bg-surface-base"),
            "hover:border-surface-border-hover",
            "focus-within:border-surface-border-hover focus-within:outline-none",
            "focus-within:ring-2 focus-within:ring-brand-emerald focus-within:ring-offset-2",
            "focus-within:ring-offset-surface-ground",
            "disabled:cursor-not-allowed disabled:opacity-50",
            assigns.class
          ]),
        popover_classes:
          cn([
            "absolute left-0 z-50 mt-1 hidden w-full overflow-hidden rounded-md border border-surface-border bg-surface-panel p-0 shadow-lg",
            assigns.popover_class
          ])
      )

    ~H"""
    <div
      id={@id}
      class="relative"
      data-polaris-multi-select
      phx-hook={@hook}
      data-change-event={@on_change}
      data-create-event={@on_create}
      data-creatable={to_string(@creatable)}
      data-mode={@mode}
      {@rest}
    >
      <%= if @name do %>
        <input
          :for={value <- @values}
          type="hidden"
          name={"#{@name}[]"}
          value={value}
          data-polaris-multi-select-hidden
        />
      <% end %>

      <button
        type="button"
        role="combobox"
        aria-expanded="false"
        aria-haspopup="listbox"
        aria-controls={"#{@id}-listbox"}
        aria-labelledby={"#{@id}-label"}
        disabled={@disabled}
        data-polaris-multi-select-trigger
        data-open="false"
        class={@trigger_classes}
      >
        <div
          class={"flex -ml-1 flex-1 gap-1 overflow-hidden #{if @wrap, do: "flex-wrap", else: "overflow-x-auto"}"}
          data-polaris-multi-select-badges
        >
          <%= for value <- @visible_values do %>
            <% label = label_for(@options, value) %>
            <span
              data-polaris-multi-select-badge
              data-value={value}
              class="shrink-0 rounded-sm bg-surface-panel-hover px-1.5 text-xs text-content-primary"
            >
              {label}
              <span
                :if={@deletable_badge}
                role="button"
                tabindex="-1"
                data-polaris-multi-select-badge-remove
                data-value={value}
                aria-label={"Remove #{label}"}
                class="ml-1 cursor-pointer text-content-muted transition-colors hover:text-content-secondary"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="size-3"
                  aria-hidden="true"
                >
                  <path d="M18 6 6 18" />
                  <path d="m6 6 12 12" />
                </svg>
              </span>
            </span>
          <% end %>
          <%= if @overflow_text do %>
            <span
              data-polaris-multi-select-overflow
              class="shrink-0 rounded-sm bg-surface-panel-hover px-1.5 text-xs text-content-primary"
            >
              {@overflow_text}
            </span>
          <% end %>
          <span
            id={"#{@id}-label"}
            class={"ml-1 whitespace-nowrap leading-5 text-content-muted transition-opacity #{@label_visibility}"}
          >
            {@label}
          </span>
          <input
            :if={@mode == "inline-combobox"}
            type="text"
            data-polaris-multi-select-input
            placeholder={@label}
            autocomplete="off"
            class="min-w-[85px] flex-1 truncate border-none bg-transparent px-1 py-0 text-sm outline-none placeholder:text-content-muted"
          />
        </div>
        <svg
          :if={@show_icon}
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="ml-1.5 size-4 shrink-0 text-content-muted"
          aria-hidden="true"
        >
          <path d="m7 15 5 5 5-5" />
          <path d="m7 9 5-5 5 5" />
        </svg>
      </button>

      <div
        id={"#{@id}-listbox"}
        role="listbox"
        aria-multiselectable="true"
        data-polaris-multi-select-popover
        class={@popover_classes}
      >
        <div
          :if={@mode == "combobox"}
          class="flex items-center gap-2 border-b border-surface-border px-2"
          data-polaris-multi-select-search
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-4 text-content-muted"
            aria-hidden="true"
          >
            <circle cx="11" cy="11" r="8" />
            <path d="m21 21-4.3-4.3" />
          </svg>
          <input
            id={"#{@id}-search"}
            type="text"
            data-polaris-multi-select-input
            placeholder={@placeholder}
            autocomplete="off"
            class="h-9 w-full border-none bg-transparent text-sm outline-none placeholder:text-content-muted"
          />
        </div>
        <div
          data-polaris-multi-select-list
          class="flex max-h-[300px] w-full flex-col overflow-y-auto p-1"
        >
          <%= for {option, index} <- Enum.with_index(@options) do %>
            <% selected = option.value in @values %>
            <div
              role="option"
              id={"#{@id}-option-#{index}"}
              tabindex="-1"
              aria-selected={to_string(selected)}
              aria-disabled={option.disabled && "true"}
              data-polaris-multi-select-option
              data-value={option.value}
              data-label={option.label}
              data-disabled={to_string(option.disabled)}
              data-selected={to_string(selected)}
              class={
                cn([
                  "relative flex w-full items-center space-x-2 rounded-xs px-2 py-1.5 text-left text-sm text-content-secondary transition-colors hover:bg-surface-panel-hover hover:text-content-primary data-[selected=true]:bg-surface-panel-hover",
                  if(option.disabled, do: "pointer-events-none opacity-50")
                ])
              }
            >
              <span class={
                cn([
                  "flex h-4 w-4 shrink-0 items-center justify-center rounded-sm border transition-colors",
                  if(selected,
                    do: "border-content-primary bg-content-primary text-surface-ground",
                    else: "border-surface-border"
                  )
                ])
              }>
                <%= if selected do %>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="size-3"
                    aria-hidden="true"
                  >
                    <path d="M20 6 9 17l-5-5" />
                  </svg>
                <% end %>
              </span>
              <span class="grow leading-none">{option.label}</span>
              <%= if option.description do %>
                <span class="text-xs text-content-muted">{option.description}</span>
              <% end %>
            </div>
          <% end %>
          <div
            :if={@creatable}
            role="option"
            tabindex="-1"
            aria-selected="false"
            data-polaris-multi-select-option
            data-polaris-multi-select-create
            hidden
            class="relative flex w-full items-center space-x-2 rounded-xs px-2 py-1.5 text-left text-sm text-content-secondary transition-colors hover:bg-surface-panel-hover hover:text-content-primary"
          >
            Create "<span data-polaris-multi-select-create-label></span>"
          </div>
          <div data-polaris-multi-select-empty class="hidden px-2 py-1.5 text-sm text-content-muted">
            {@empty_label}
          </div>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Select" runtime>
      {
        mounted() {
          const root = this.el
          this._open = false
          this._activeIndex = -1

          const trigger = () => root.querySelector("[data-polaris-multi-select-trigger]")
          const popover = () => root.querySelector("[data-polaris-multi-select-popover]")
          const input = () => root.querySelector("[data-polaris-multi-select-input]")

          this._push = (event, payload) => {
            if (event && typeof this.pushEvent === "function") {
              this.pushEvent(event, payload)
            }
          }

          // Options that currently participate in keyboard navigation: not
          // hidden by the filter and not disabled. The creatable item counts
          // when the filter reveals it.
          this._visibleOptions = () =>
            Array.from(root.querySelectorAll("[data-polaris-multi-select-option]")).filter(
              (el) => !el.hasAttribute("hidden") && el.dataset.disabled !== "true"
            )

          this._setActive = (index) => {
            const options = this._visibleOptions()
            options.forEach((el) => {
              el.removeAttribute("data-active")
              el.classList.remove("bg-surface-panel-hover")
            })
            if (index >= 0 && index < options.length) {
              this._activeIndex = index
              const el = options[index]
              el.setAttribute("data-active", "true")
              el.classList.add("bg-surface-panel-hover")
              el.scrollIntoView({ block: "nearest" })
            } else {
              this._activeIndex = -1
            }
          }

          // Open/close: toggle the hidden popover, sync aria-expanded and
          // data-open, brighten the trigger border while open, and focus the
          // search input (combobox) or inline input (inline-combobox). Simple
          // flip: drop up when there is no room below the trigger.
          this._applyOpen = (open, focus) => {
            const t = trigger()
            const p = popover()
            this._open = open
            if (!t || !p) {
              return
            }
            if (open) {
              const rect = t.getBoundingClientRect()
              if (window.innerHeight - rect.bottom < 260 && rect.top > 260) {
                p.style.top = "auto"
                p.style.bottom = "100%"
                p.style.marginTop = "0"
                p.style.marginBottom = "4px"
              } else {
                p.style.top = ""
                p.style.bottom = ""
                p.style.marginTop = ""
                p.style.marginBottom = ""
              }
              p.classList.remove("hidden")
              t.setAttribute("aria-expanded", "true")
              t.setAttribute("data-open", "true")
              t.classList.add("border-surface-border-hover")
              if (focus !== false) {
                const i = input()
                if (i) {
                  i.focus()
                }
              }
            } else {
              p.classList.add("hidden")
              t.setAttribute("aria-expanded", "false")
              t.setAttribute("data-open", "false")
              t.classList.remove("border-surface-border-hover")
              this._setActive(-1)
            }
          }

          // Filter: match value + label case-insensitively, toggle the hidden
          // attribute on misses, then reconcile the empty state and the
          // creatable item.
          this._filter = () => {
            const i = input()
            const query = i ? i.value : ""
            const needle = query.toLowerCase()
            const options = root.querySelectorAll(
              "[data-polaris-multi-select-option]:not([data-polaris-multi-select-create])"
            )
            let visibleCount = 0
            options.forEach((el) => {
              const haystack = ((el.dataset.value || "") + " " + (el.dataset.label || "")).toLowerCase()
              const matches = haystack.includes(needle)
              if (matches) {
                visibleCount = visibleCount + 1
                el.removeAttribute("hidden")
              } else {
                el.setAttribute("hidden", "")
              }
            })
            const empty = root.querySelector("[data-polaris-multi-select-empty]")
            if (empty) {
              if (visibleCount === 0) {
                empty.removeAttribute("hidden")
              } else {
                empty.setAttribute("hidden", "")
              }
            }
            const create = root.querySelector("[data-polaris-multi-select-create]")
            if (create) {
              if (visibleCount === 0 && root.dataset.creatable === "true" && root.dataset.createEvent) {
                const label = create.querySelector("[data-polaris-multi-select-create-label]")
                if (label) {
                  label.textContent = query
                }
                create.removeAttribute("hidden")
              } else {
                create.setAttribute("hidden", "")
              }
            }
            this._setActive(-1)
          }

          this._resetFilter = () => {
            const i = input()
            if (i) {
              i.value = ""
            }
            this._filter()
          }

          this._create = () => {
            const i = input()
            const value = i ? i.value : ""
            if (!value || !root.dataset.createEvent) {
              return
            }
            this._push(root.dataset.createEvent, { value: value })
            this._resetFilter()
            const create = root.querySelector("[data-polaris-multi-select-create]")
            if (create) {
              create.setAttribute("hidden", "")
            }
          }

          // All interaction is delegated from this.el (root), so LiveView
          // morphs never orphan a listener.
          this._onClick = (event) => {
            const remove = event.target.closest("[data-polaris-multi-select-badge-remove]")
            if (remove) {
              event.stopPropagation()
              this._push(root.dataset.changeEvent, {
                value: remove.dataset.value,
                selected: "false"
              })
              return
            }
            const option = event.target.closest("[data-polaris-multi-select-option]")
            if (option) {
              if (option.hasAttribute("data-polaris-multi-select-create")) {
                this._create()
                return
              }
              if (option.dataset.disabled === "true") {
                return
              }
              this._push(root.dataset.changeEvent, {
                value: option.dataset.value,
                selected: option.dataset.selected === "true" ? "false" : "true"
              })
              // Multi-select: keep the popover open, clear the filter.
              this._resetFilter()
              return
            }
            if (event.target.closest("[data-polaris-multi-select-input]")) {
              if (!this._open) {
                this._applyOpen(true)
              }
              return
            }
            if (event.target.closest("[data-polaris-multi-select-trigger]")) {
              this._applyOpen(!this._open)
            }
          }
          root.addEventListener("click", this._onClick)

          this._onInput = (event) => {
            if (event.target.matches("[data-polaris-multi-select-input]")) {
              this._filter()
            }
          }
          root.addEventListener("input", this._onInput)

          // Keyboard navigation over the currently visible options.
          this._onKeydown = (event) => {
            if (event.key === "Escape") {
              this._applyOpen(false)
              const t = trigger()
              if (t) {
                t.focus()
              }
              return
            }
            if (
              event.key === "Backspace" &&
              event.target.matches("[data-polaris-multi-select-input]") &&
              event.target.value === ""
            ) {
              const badges = root.querySelectorAll("[data-polaris-multi-select-badge]")
              const last = badges[badges.length - 1]
              if (last) {
                this._push(root.dataset.changeEvent, {
                  value: last.dataset.value,
                  selected: "false"
                })
              }
              return
            }
            if (!this._open) {
              if ((event.key === "ArrowDown" || event.key === "Enter") && event.target === trigger()) {
                event.preventDefault()
                this._applyOpen(true)
              }
              return
            }
            const options = this._visibleOptions()
            if (event.key === "ArrowDown") {
              event.preventDefault()
              const next = this._activeIndex + 1 >= options.length ? 0 : this._activeIndex + 1
              this._setActive(next)
            } else if (event.key === "ArrowUp") {
              event.preventDefault()
              const next = this._activeIndex <= 0 ? options.length - 1 : this._activeIndex - 1
              this._setActive(next)
            } else if (event.key === "Home") {
              event.preventDefault()
              this._setActive(0)
            } else if (event.key === "End") {
              event.preventDefault()
              this._setActive(options.length - 1)
            } else if (event.key === "Enter") {
              event.preventDefault()
              const active =
                this._activeIndex >= 0 && this._activeIndex < options.length
                  ? options[this._activeIndex]
                  : options[0]
              if (active && active.hasAttribute("data-polaris-multi-select-create")) {
                this._create()
              } else if (active && active.dataset.disabled !== "true") {
                this._push(root.dataset.changeEvent, {
                  value: active.dataset.value,
                  selected: active.dataset.selected === "true" ? "false" : "true"
                })
                this._resetFilter()
              }
            }
          }
          root.addEventListener("keydown", this._onKeydown)

          // Focusing the search input opens the popover (the fragment's
          // onFocus -> setOpen(true)).
          this._onFocusIn = (event) => {
            if (!this._open && event.target.matches("[data-polaris-multi-select-input]")) {
              this._applyOpen(true)
            }
          }
          root.addEventListener("focusin", this._onFocusIn)

          // Click-outside closes.
          this._onDocumentClick = (event) => {
            if (!root.contains(event.target)) {
              this._applyOpen(false)
            }
          }
          document.addEventListener("click", this._onDocumentClick)
        },

        updated() {
          // The server always renders the popover hidden; after a patch
          // re-assert the open state (without stealing focus) and the
          // current filter.
          if (this._open) {
            this._applyOpen(true, false)
            this._filter()
          }
        },

        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onClick)
          this.el.removeEventListener("input", this._onInput)
          this.el.removeEventListener("keydown", this._onKeydown)
          this.el.removeEventListener("focusin", this._onFocusIn)
          document.removeEventListener("click", this._onDocumentClick)
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

  # badge_limit is :any so :wrap can pass; validate at render time like the
  # mode check so a dynamic "3" fails loudly instead of mis-rendering.
  defp validate_badge_limit!(badge_limit) do
    unless badge_limit == :wrap or is_integer(badge_limit) do
      raise ArgumentError,
            "invalid value for :badge_limit: #{inspect(badge_limit)} — expected an integer or :wrap"
    end
  end

  # Overflow badge text: "+K" for a normal cap, "N items selected" when the
  # cap is below 1, nothing when wrapping or everything fits.
  defp overflow_text(_limit, true = _wrap, _extra), do: nil
  defp overflow_text(_limit, _wrap, 0), do: nil

  defp overflow_text(limit, _wrap, extra) when limit < 1,
    do: "#{extra} item#{if extra > 1, do: "s"} selected"

  defp overflow_text(_limit, _wrap, extra), do: "+#{extra}"

  # The label stays beside the badges when persist_label is set or nothing is
  # selected — never in inline mode (the input takes its place).
  defp label_visibility(%{persist_label: persist, values: values, mode: mode}) do
    if (persist or values == []) and mode != "inline-combobox" do
      "inline opacity-100"
    else
      "hidden opacity-0"
    end
  end

  defp normalize_options(options), do: Enum.map(options, &normalize_option/1)

  defp normalize_option(%{value: value} = option) do
    %{
      value: value,
      label: Map.get(option, :label) || value,
      disabled: !!Map.get(option, :disabled, false),
      description: Map.get(option, :description)
    }
  end

  defp normalize_option(option) do
    raise ArgumentError, "each option must be a map with a :value key, got: #{inspect(option)}"
  end

  # Badge label lookup with raw-value fallback (unknown values still render,
  # so server-driven state never blanks out).
  defp label_for(options, value) do
    case Enum.find(options, &(&1.value == value)) do
      %{label: label} -> label
      _ -> value
    end
  end
end
