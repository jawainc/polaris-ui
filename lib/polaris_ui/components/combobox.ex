defmodule PolarisUI.Components.Combobox do
  @moduledoc """
  The Polaris combobox: a single-select trigger that opens a searchable
  list popover — the port of the Supabase design system Combobox, which
  the docs define as *a composition of the Popover and the Command
  components* (`packages/ui` ships no standalone file; the canonical
  demo wires Button + Popover + Command).

  This port keeps that anatomy and styling 1:1 — a `default`-variant
  small button with the chevrons-up-down glyph, a borderless
  trigger-width panel, the Command search row, and check-marked items —
  while splitting the React demo's brain in two, the established
  LiveView split:

    * the **server** owns the selection — every item click pushes
      `on_change` with `%{"value" => v}` (the empty string when the
      selected item is clicked again, the demo's toggle), and the
      re-rendered trigger label is the single source of truth;
    * the colocated **hook** owns only the view layer — popover
      open/close, option filtering, and arrow-key navigation. It holds
      no selection state, so the two layers can never drift.

  ## Anatomy

      <.combobox
        id="framework"
        options={@frameworks}
        value={@framework}
        on_change="pick-framework"
        placeholder="Select framework..."
        search_placeholder="Search framework..."
        empty_label="No framework found."
      />

    * **trigger** — the Supabase `default` button (`w-[200px]
      justify-between`, override via `class`) with `role="combobox"`,
      showing the selected label or the placeholder, closed out by the
      half-opacity chevrons-up-down glyph.
    * **popover** — always in the DOM (`hidden` until the hook opens
      it), the same width as the trigger (`p-0` PopoverContent): the
      Command search row under a bottom border, the scrollable option
      list, and the "No framework found." empty state.
    * **items** — one per option, led by the check glyph
      (`opacity-0` until selected, `opacity-100` on the selected
      value — the demo's exact pattern).

  ## Data shape

      options: [%{value: "next.js", label: "Next.js", disabled: false, description: nil}]
      value:   "next.js"

  `value` is required per option; `label` defaults to `value`,
  `disabled` to `false`, and an optional `description` renders muted
  next to the label. An unknown `value` (no matching option) still
  renders in the trigger as the raw value, so server-driven state never
  blanks out.

  ## Keyboard map

    * **ArrowDown / ArrowUp** — cycle the highlighted option (wraps).
    * **Enter** — pick the highlighted option (the first visible one
      when none is highlighted); picking the already-selected value
      clears the selection (the demo's toggle).
    * **Escape** — close the popover and refocus the trigger.

  ## Microcopy

  Per the Supabase copywriting guidelines: the `placeholder` names the
  domain ("Select framework..."), the `search_placeholder` narrows it
  ("Search framework..."), and `empty_label` covers the miss ("No
  framework found.").

  ## States

    * **rest / hover / focus-ring / disabled** — inherited from the
      Supabase button (hover fill, emerald focus ring, 50% dim).
    * **open** — the popover visible, the trigger's pressed styling
      via `data-open`.
    * **disabled option** — greyed, inert, skipped by keyboard nav.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  import PolarisUI.Components.Button, only: [button: 1]

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the root — the colocated hook anchors on it. Derived
    ids: `"<id>-listbox"` (popover), `"<id>-search"` (search input),
    `"<id>-option-<index>"` (items).
    """
  )

  attr(:name, :string,
    default: nil,
    doc: """
    Form field name — when set, a hidden input carrying the selected
    value is rendered so the control submits with normal forms.
    """
  )

  attr(:options, :list,
    required: true,
    doc: """
    Option maps — `%{value: "next.js", label: "Next.js", disabled:
    false, description: nil}`. `value` is required; `label` defaults to
    `value`, `disabled` to `false`; `description` renders muted.
    """
  )

  attr(:value, :any,
    default: nil,
    doc: "Selected value (server-owned) — its label renders in the trigger."
  )

  attr(:on_change, :string,
    required: true,
    doc: """
    LiveView event pushed on selection with payload `%{"value" => v}`
    — the empty string when the selected value is clicked again.
    """
  )

  attr(:disabled, :boolean, default: false, doc: "Disables the trigger.")

  attr(:placeholder, :string,
    default: "Select...",
    doc: "Trigger text when nothing is selected — \"Select framework...\" names the domain."
  )

  attr(:search_placeholder, :string,
    default: "Search...",
    doc: "Search field placeholder — \"Search framework...\" narrows the domain."
  )

  attr(:empty_label, :string,
    default: "No results found.",
    doc: "Text for the filtered-empty state (\"No framework found.\")."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the trigger button (`w-[200px]` sizing, …)."
  )

  attr(:popover_class, :string, default: nil, doc: "Additional classes merged onto the popover.")

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  def combobox(assigns) do
    options = normalize_options(assigns.options)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Select",
        options: options,
        selected_label: label_for(options, assigns.value),
        popover_classes:
          cn([
            "absolute left-0 z-50 mt-1 hidden w-full overflow-hidden rounded-md border border-surface-border",
            "bg-surface-panel p-0 shadow-md",
            assigns.popover_class
          ])
      )

    ~H"""
    <div
      id={@id}
      class="relative inline-block max-w-full text-left"
      data-polaris-combobox
      phx-hook={@hook}
      data-change-event={@on_change}
      {@rest}
    >
      <input :if={@name} type="hidden" name={@name} value={@value} />

      <.button
        type="button"
        variant="default"
        size="small"
        role="combobox"
        aria-expanded="false"
        aria-haspopup="listbox"
        aria-controls={"#{@id}-listbox"}
        disabled={@disabled}
        data-polaris-combobox-trigger
        data-open="false"
        class={cn(["w-[200px] justify-between", @class])}
      >
        <%= if @selected_label do %>
          {@selected_label}
        <% else %>
          <span class="text-content-muted font-normal">{@placeholder}</span>
        <% end %>
        <:icon_right>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-4 shrink-0 opacity-50"
            aria-hidden="true"
          >
            <path d="m7 15 5 5 5-5" />
            <path d="m7 9 5-5 5 5" />
          </svg>
        </:icon_right>
      </.button>

      <div id={"#{@id}-listbox"} data-polaris-combobox-popover class={@popover_classes}>
        <div
          class="flex items-center border-b border-surface-border px-4"
          data-polaris-combobox-search
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-4 shrink-0 opacity-50"
            aria-hidden="true"
          >
            <circle cx="11" cy="11" r="8" />
            <path d="m21 21-4.3-4.3" />
          </svg>
          <input
            id={"#{@id}-search"}
            type="text"
            data-polaris-combobox-input
            placeholder={@search_placeholder}
            autocomplete="off"
            role="combobox"
            aria-expanded="true"
            aria-autocomplete="list"
            aria-controls={"#{@id}-list"}
            class="flex h-9 w-full rounded-md bg-transparent py-3 text-sm outline-none border-none placeholder:text-content-muted"
          />
        </div>
        <div
          id={"#{@id}-list"}
          data-polaris-combobox-list
          role="listbox"
          aria-label={@placeholder}
          class="max-h-[300px] overflow-y-auto overflow-x-hidden"
        >
          <div class="overflow-hidden p-1">
            <div
              :for={{option, index} <- Enum.with_index(@options)}
              id={"#{@id}-option-#{index}"}
              role="option"
              tabindex="-1"
              aria-selected={to_string(option.value == @value)}
              aria-disabled={to_string(option.disabled)}
              data-polaris-combobox-option
              data-value={option.value}
              data-label={option.label}
              data-disabled={to_string(option.disabled)}
              data-selected={to_string(option.value == @value)}
              class={
                cn([
                  "relative flex cursor-default select-none items-center rounded-xs px-2 py-1.5 text-xs outline-none",
                  "hover:bg-surface-panel-hover data-[active=true]:bg-surface-panel-hover",
                  "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50",
                  "data-[selected=true]:text-content-primary"
                ])
              }
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="3"
                stroke-linecap="round"
                stroke-linejoin="round"
                class={
                  cn([
                    "mr-2 size-4 shrink-0",
                    if(option.value == @value, do: "opacity-100", else: "opacity-0")
                  ])
                }
                aria-hidden="true"
              >
                <path d="M20 6 9 17l-5-5" />
              </svg>
              <span class="grow leading-none">{option.label}</span>
              <span :if={option.description} class="pl-2 text-xs text-content-muted">
                {option.description}
              </span>
            </div>
            <div
              data-polaris-combobox-empty
              hidden
              class="py-6 text-center text-xs text-content-muted"
            >
              {@empty_label}
            </div>
          </div>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Select" runtime>
      {
        mounted() {
          const root = this.el
          this._open = false
          this._active = null

          const trigger = () => root.querySelector("[data-polaris-combobox-trigger]")
          const popover = () => root.querySelector("[data-polaris-combobox-popover]")
          const input = () => root.querySelector("[data-polaris-combobox-input]")

          this._push = (value) => {
            const event = root.dataset.changeEvent
            if (event && typeof this.pushEvent === "function") {
              this.pushEvent(event, { value: value })
            }
          }

          // Options that currently participate in keyboard navigation:
          // visible to the filter and not disabled.
          this._visibleOptions = () =>
            Array.from(root.querySelectorAll("[data-polaris-combobox-option]")).filter(
              (el) => !el.hasAttribute("hidden") && el.dataset.disabled !== "true"
            )

          this._setActive = (option) => {
            this._active = option
            root.querySelectorAll("[data-polaris-combobox-option]").forEach((el) => {
              const active = el === option
              el.setAttribute("data-active", String(active))
              el.setAttribute("aria-selected", String(active || el.dataset.selected === "true"))
            })
            const i = input()
            if (i) {
              i.setAttribute("aria-activedescendant", option ? option.id : "")
            }
            if (option) {
              option.scrollIntoView({ block: "nearest" })
            }
          }

          // Filter: match value + label case-insensitively (substring,
          // falling back to cmdk-style in-order fuzzy), then reconcile
          // the empty state.
          this._filter = () => {
            const i = input()
            const needle = (i ? i.value : "").trim().toLowerCase()
            const options = root.querySelectorAll("[data-polaris-combobox-option]")
            let visible = 0
            options.forEach((el) => {
              const haystack = ((el.dataset.value || "") + " " + (el.dataset.label || ""))
                .toLowerCase()
                .trim()
              const hit =
                !needle ||
                haystack.includes(needle) ||
                (() => {
                  let k = 0
                  for (const ch of haystack) {
                    if (ch === needle[k]) k++
                    if (k === needle.length) return true
                  }
                  return false
                })()
              if (hit) {
                visible = visible + 1
                el.removeAttribute("hidden")
              } else {
                el.setAttribute("hidden", "")
              }
            })
            const empty = root.querySelector("[data-polaris-combobox-empty]")
            if (empty) {
              if (visible === 0) {
                empty.removeAttribute("hidden")
              } else {
                empty.setAttribute("hidden", "")
              }
            }
            this._setActive(this._visibleOptions()[0] || null)
          }

          this._resetFilter = () => {
            const i = input()
            if (i) {
              i.value = ""
            }
            this._filter()
          }

          this._applyOpen = (open, focus) => {
            const t = trigger()
            const p = popover()
            this._open = open
            if (!t || !p) {
              return
            }
            if (open) {
              p.classList.remove("hidden")
              t.setAttribute("aria-expanded", "true")
              t.setAttribute("data-open", "true")
              t.setAttribute("data-state", "open")
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
              t.setAttribute("data-state", "closed")
              this._setActive(null)
              this._resetFilter()
            }
          }

          this._select = (option) => {
            // Picking the selected value again clears it — the demo's toggle.
            const cleared = option.dataset.selected === "true"
            this._push(cleared ? "" : option.dataset.value)
            this._applyOpen(false)
            const t = trigger()
            if (t) {
              t.focus()
            }
          }

          // All interaction is delegated from this.el (root), so LiveView
          // morphs never orphan a listener.
          this._onClick = (event) => {
            const option = event.target.closest("[data-polaris-combobox-option]")
            if (option) {
              if (option.dataset.disabled === "true") {
                return
              }
              this._select(option)
              return
            }
            if (event.target.closest("[data-polaris-combobox-trigger]")) {
              this._applyOpen(!this._open)
            }
          }
          root.addEventListener("click", this._onClick)

          this._onInput = (event) => {
            if (event.target.matches("[data-polaris-combobox-input]")) {
              this._filter()
            }
          }
          root.addEventListener("input", this._onInput)

          this._onKeydown = (event) => {
            if (event.key === "Escape") {
              this._applyOpen(false)
              const t = trigger()
              if (t) {
                t.focus()
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
              const index = options.indexOf(this._active)
              this._setActive(options[(index + 1) % options.length] || options[0] || null)
            } else if (event.key === "ArrowUp") {
              event.preventDefault()
              const index = options.indexOf(this._active)
              this._setActive(options[(index - 1 + options.length) % options.length] || options[0] || null)
            } else if (event.key === "Home") {
              event.preventDefault()
              this._setActive(options[0] || null)
            } else if (event.key === "End") {
              event.preventDefault()
              this._setActive(options[options.length - 1] || null)
            } else if (event.key === "Enter") {
              const option = this._active || options[0]
              if (option) {
                event.preventDefault()
                this._select(option)
              }
            }
          }
          root.addEventListener("keydown", this._onKeydown)

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
          document.removeEventListener("click", this._onDocumentClick)
        }
      }
    </script>
    """
  end

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
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

  # Trigger label lookup with raw-value fallback (an unknown value still
  # renders, so server-driven state never blanks out).
  defp label_for(options, value) do
    case Enum.find(options, &(&1.value == value)) do
      %{label: label} -> label
      _ -> if is_nil(value) or value == "", do: nil, else: to_string(value)
    end
  end
end
