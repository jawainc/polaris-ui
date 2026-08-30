defmodule PolarisUI.Components.Select do
  @moduledoc """
  The Polaris select: a single-choice dropdown listbox — the port of
  the Supabase design system Select (`packages/ui`, built on the Radix
  Select primitive with its size-variant scale).

  ## Anatomy

      <.select
        id="fruit"
        name="fruit"
        value={@fruit}
        placeholder="Select a fruit"
        on_change="pick-fruit"
        options={[
          %{group: "Fruits", value: "apple", label: "Apple"},
          %{group: "Fruits", value: "banana", label: "Banana"},
          %{group: "Vegetables", value: "carrot", label: "Carrot", disabled: true}
        ]}
      />

      <.select id="timezone" options={["UTC", "CET"]} class="w-[280px]" />

    * **trigger** — the raised plate (`bg-surface-panel`, the source's
      `bg-control-raised`) with the selected label (or the muted
      placeholder) and the chevron; the source's full
      `tiny`/`small`/`medium`/`large`/`xlarge` size scale (`small` by
      default).
    * **content** — the fixed-position `role="listbox"` popup
      (`z-50 max-h-96 min-w-32 rounded-md border bg-surface-panel
      shadow-md`), pinned to the trigger's width, with scroll chevron
      buttons that appear only while the list scrolls.
    * **items** — `role="option"` rows with the reserved indicator
      slot at `left-2`: the checked item carries the filled circle
      (`bg-content-primary rounded-full`) with the bold knocked-out
      check. Options sharing a `group` render under the source's
      uppercase mono group label, with the hairline separator between
      groups.

  Options are data (`"Apple"` shorthand or
  `%{value:, label:, disabled:, group:}` maps) so the trigger label and
  the hidden form input resolve server-side; the `group` key groups in
  insertion order.

  ## State model

  Like Radix, selection is **client-side**: the colocated runtime hook
  owns it — seeded from `value`, re-applied after LiveView patches so
  selections survive re-renders. From mount on, the hook is
  authoritative.

  ## Keyboard

  Closed: **Enter** opens at the first item, **Space**/**ArrowDown**/
  **ArrowUp** open at the selected item (or the first). Open: arrows
  cycle, **Home**/**End** bound the list, **Enter**/**Space** pick the
  highlighted item, typing jumps to matching items (typeahead),
  **Escape** closes, and focus returns to the trigger (the Radix
  `onCloseAutoFocus` default).

  ## Form participation & events

  With `name`, a hidden input carries the selection into form
  submissions (the hook syncs its value and dispatches bubbling
  `input`/`change` so `phx-change` forms observe changes). With
  `on_change`, every selection pushes `%{"value" => value}` to the
  server:

      def handle_event("pick-fruit", %{"value" => value}, socket) do
        {:noreply, assign(socket, fruit: value)}
      end

  ## States

    * **rest / hover** — the bordered plate brightening its border on
      hover and while open.
    * **focus-ring** — the shared emerald `focus-visible` ring.
    * **checked** — `data-state="checked"` / `aria-selected="true"`
      with the circle indicator; highlight (`data-highlighted`) rides
      real DOM focus, like the source's `focus:` treatments.
    * **disabled** — the whole trigger at 50% opacity and locked;
      per-option `disabled` greys the row and skips it in navigation.
    * **loading** — the trigger locked with the brand spinner in place
      of the chevron (`aria-busy`).

  ## Microcopy

  Per the Supabase copywriting guidelines: the `placeholder` names the
  domain concisely ("Select a fruit", "Select a timezone") and option
  labels stay short option nouns.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @sizes ~w(tiny small medium large xlarge)
  @sides ~w(top bottom)
  @alignments ~w(start center end)

  @hook "#{inspect(__MODULE__)}.Root"

  # The source's SIZE_VARIANTS (packages/ui/src/lib/constants.ts):
  # text + padding + height per size.
  defp size_classes("tiny"), do: "text-xs px-2.5 py-1 h-[26px]"
  defp size_classes("small"), do: "text-base md:text-sm leading-4 px-3 py-2 h-[34px]"
  defp size_classes("medium"), do: "text-base md:text-sm px-4 py-2 h-[38px]"
  defp size_classes("large"), do: "text-base px-4 py-2 h-[42px]"
  defp size_classes("xlarge"), do: "text-base px-6 py-3 h-[50px]"

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the select root — required because the colocated hook
    that owns open/close and selection anchors on it. Derived ids:
    `"<id>-trigger"`, `"<id>-listbox"`, `"<id>-viewport"`,
    `"<id>-option-<value>"`.
    """
  )

  attr(:options, :list,
    required: true,
    doc: """
    The choices — `"Apple"` strings or
    `%{value: "apple", label: "Apple", disabled: false, group: "Fruits"}`
    maps (`label` defaults to `value`; falsy `group` renders bare).
    Consecutive options sharing a `group` render under one label.
    """
  )

  attr(:value, :string,
    default: nil,
    doc: "The selected option's value (the initial paint; the hook owns selection from mount on)."
  )

  attr(:placeholder, :string,
    default: nil,
    doc: "Trigger text while nothing is selected — a concise domain prompt (\"Select a fruit\")."
  )

  attr(:name, :string,
    default: nil,
    doc:
      "Form field name — renders the hidden input carrying the selection into form submissions."
  )

  attr(:on_change, :string,
    default: nil,
    doc: "Optional LiveView event pushed on every selection with `%{\"value\" => value}`."
  )

  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc: "The source's shared size scale — `small` is the default everywhere in Supabase."
  )

  attr(:side, :string,
    values: @sides,
    default: "bottom",
    doc:
      "Edge of the trigger the listbox anchors to. The hook flips it when the viewport runs out."
  )

  attr(:align, :string,
    values: @alignments,
    default: "center",
    doc: "Cross-axis position of the listbox relative to the trigger."
  )

  attr(:side_offset, :integer,
    default: 4,
    doc: "Gap between trigger and listbox in pixels."
  )

  attr(:disabled, :boolean, default: false, doc: "Locks the trigger.")

  attr(:loading, :boolean,
    default: false,
    doc: "Locks the trigger and swaps the chevron for the brand spinner while options load."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root wrapper.")

  attr(:trigger_class, :string, default: nil, doc: "Additional classes merged onto the trigger.")

  attr(:content_class, :string,
    default: nil,
    doc: "Additional classes merged onto the listbox popup."
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  def select(assigns) do
    validate_in!(:size, assigns.size, @sizes)
    validate_in!(:side, assigns.side, @sides)
    validate_in!(:align, assigns.align, @alignments)

    normalized = normalize_options(assigns.options)
    selected = Enum.find(normalized, &(&1.value == assigns.value))

    assigns =
      assign(assigns,
        hook: @hook,
        options: normalized,
        selected: selected,
        locked?: assigns.disabled or assigns.loading,
        root_classes: cn(["relative inline-flex w-full max-w-full", assigns.class]),
        trigger_classes:
          cn([
            "flex w-full items-center justify-between gap-2 rounded-md border bg-surface-panel",
            "border-surface-border text-left text-content-primary transition-colors duration-200",
            "hover:border-surface-border-hover data-[state=open]:border-surface-border-hover",
            "data-[placeholder]:text-content-secondary",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "disabled:cursor-not-allowed disabled:opacity-50",
            "[&>span]:truncate",
            size_classes(assigns.size),
            assigns.trigger_class
          ]),
        content_classes:
          cn([
            "fixed z-50 min-w-32 max-h-96 overflow-hidden rounded-md border border-surface-border",
            "bg-surface-panel text-content-primary shadow-md outline-none",
            assigns.content_class
          ])
      )

    ~H"""
    <div
      id={@id}
      data-polaris-select
      data-value={@value}
      data-placeholder-text={@placeholder}
      data-change-event={@on_change}
      data-side={@side}
      data-align={@align}
      data-side-offset={to_string(@side_offset)}
      data-state="closed"
      class={@root_classes}
      phx-hook={@hook}
      {@rest}
    >
      <input :if={@name} type="hidden" name={@name} value={@value} data-polaris-select-input />
      <button
        id={"#{@id}-trigger"}
        type="button"
        role="combobox"
        aria-haspopup="listbox"
        aria-expanded="false"
        aria-controls={"#{@id}-listbox"}
        data-polaris-select-trigger
        data-state="closed"
        data-placeholder={@selected == nil && "true"}
        disabled={@locked?}
        aria-busy={to_string(@loading)}
        class={@trigger_classes}
      >
        <span data-polaris-select-value>{(@selected && @selected.label) || @placeholder}</span>
        <svg
          :if={!@loading}
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-4 shrink-0 text-content-secondary"
          aria-hidden="true"
        >
          <path d="m6 9 6 6 6-6" />
        </svg>
        <svg
          :if={@loading}
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          class="size-4 shrink-0 animate-spin text-brand-accent"
          aria-hidden="true"
        >
          <path d="M21 12a9 9 0 1 1-6.219-8.56" />
        </svg>
      </button>
      <div
        id={"#{@id}-listbox"}
        data-polaris-select-content
        role="listbox"
        aria-label={@placeholder || "Options"}
        hidden
        data-state="closed"
        class={@content_classes}
      >
        <div
          data-polaris-select-scroll-up
          hidden
          class="flex cursor-default items-center justify-center py-1 text-content-muted"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-4"
            aria-hidden="true"
          >
            <path d="m18 15-6-6-6 6" />
          </svg>
        </div>
        <div
          id={"#{@id}-viewport"}
          data-polaris-select-viewport
          class="max-h-80 overflow-y-auto p-1"
        >
          <%= for {group, index} <- Enum.with_index(group_runs(@options)) do %>
            <div
              :if={group.label && index > 0}
              data-polaris-select-separator
              class="-mx-1 my-1 h-px bg-surface-border"
            />
            <div
              :if={group.label}
              role="group"
              aria-label={group.label}
              data-polaris-select-group
              class="py-1.5 pl-8 pr-2 text-xs font-mono uppercase tracking-wider text-content-secondary/75"
            >
              {group.label}
            </div>
            <div
              :for={option <- group.options}
              id={"#{@id}-option-#{option.value}"}
              role="option"
              tabindex="-1"
              aria-selected={to_string(option.value == @value)}
              aria-disabled={to_string(option.disabled)}
              data-polaris-select-item
              data-value={option.value}
              data-label={option.label}
              data-disabled={to_string(option.disabled)}
              data-state={if(option.value == @value, do: "checked", else: "unchecked")}
              data-highlighted="false"
              class={
                cn([
                  "relative flex w-full cursor-default select-none items-center rounded-xs py-1.5 pl-8 pr-2 text-sm outline-none",
                  "text-content-secondary data-[state=checked]:text-content-primary",
                  "focus:bg-surface-panel-hover focus:text-content-primary",
                  "data-[highlighted=true]:bg-surface-panel-hover data-[highlighted=true]:text-content-primary",
                  "data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50"
                ])
              }
            >
              <span
                class="absolute left-2 flex h-3.5 w-3.5 items-center justify-center"
                aria-hidden="true"
              >
                <span
                  data-polaris-select-item-indicator
                  class={
                      "flex h-3.5 w-3.5 items-center justify-center rounded-full " <>
                        if(option.value == @value,
                          do: "bg-content-primary",
                          else: "bg-transparent"
                        )
                    }
                >
                  <svg
                    :if={option.value == @value}
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="6"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="size-2 text-surface-panel"
                  >
                    <path d="M20 6 9 17l-5-5" />
                  </svg>
                </span>
              </span>
              <span>{option.label}</span>
            </div>
          <% end %>
        </div>
        <div
          data-polaris-select-scroll-down
          hidden
          class="flex cursor-default items-center justify-center py-1 text-content-muted"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-4"
            aria-hidden="true"
          >
            <path d="m6 9 6 6 6-6" />
          </svg>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          const trigger = () => root.querySelector("[data-polaris-select-trigger]")
          const content = () => root.querySelector("[data-polaris-select-content]")
          const viewport = () => root.querySelector("[data-polaris-select-viewport]")
          const input = () => root.querySelector("[data-polaris-select-input]")
          this._items = () =>
            Array.from(root.querySelectorAll("[data-polaris-select-item]"))
          this._enabled = () => this._items().filter((el) => el.dataset.disabled !== "true")
          this._open = false
          this._typeahead = ""
          this._typeaheadAt = 0

          this._labelFor = (value) => {
            const item = this._items().find((el) => el.dataset.value === value)
            return item ? item.dataset.label : null
          }

          // Selection paint: trigger label, placeholder state, hidden
          // input, and every item's checked state — the hook is
          // authoritative from mount on, like the source.
          this._apply = () => {
            const t = trigger()
            const valueSpan = root.querySelector("[data-polaris-select-value]")
            const label = this._labelFor(this._value)
            if (t) {
              if (label != null) {
                t.removeAttribute("data-placeholder")
              } else {
                t.setAttribute("data-placeholder", "true")
              }
            }
            if (valueSpan) {
              valueSpan.textContent = label != null ? label : root.dataset.placeholderText || ""
            }
            const hidden = input()
            if (hidden) hidden.value = this._value == null ? "" : this._value
            this._items().forEach((el) => {
              const checked = el.dataset.value === this._value
              el.dataset.state = checked ? "checked" : "unchecked"
              el.setAttribute("aria-selected", checked ? "true" : "false")
            })
          }

          this._select = (item) => {
            if (!item || item.dataset.disabled === "true") return
            if (item.dataset.value !== this._value) {
              this._value = item.dataset.value
              this._apply()
              const hidden = input()
              if (hidden) {
                // Bubble through the hidden input so phx-change forms observe it.
                hidden.dispatchEvent(new Event("input", { bubbles: true }))
                hidden.dispatchEvent(new Event("change", { bubbles: true }))
              }
              const name = root.dataset.changeEvent
              if (name && typeof this.pushEvent === "function") {
                this.pushEvent(name, { value: this._value })
              }
            }
          }

          this._highlight = (item) => {
            if (!item) return
            this._items().forEach((el) => (el.dataset.highlighted = el === item ? "true" : "false"))
            item.focus({ preventScroll: true })
            // Radix auto-scrolls the highlighted item into view.
            const vp = viewport()
            if (vp) {
              const top = item.offsetTop - vp.clientHeight / 2 + item.offsetHeight / 2
              vp.scrollTop = Math.max(top, 0)
            }
          }

          this._syncScrollButtons = () => {
            const vp = viewport()
            const c = content()
            if (!vp || !c) return
            const up = c.querySelector("[data-polaris-select-scroll-up]")
            const down = c.querySelector("[data-polaris-select-scroll-down]")
            if (up) {
              if (vp.scrollTop > 1) up.removeAttribute("hidden")
              else up.setAttribute("hidden", "")
            }
            if (down) {
              if (vp.scrollTop + vp.clientHeight < vp.scrollHeight - 1) down.removeAttribute("hidden")
              else down.setAttribute("hidden", "")
            }
          }

          // Fixed positioning measured from the trigger's viewport rect —
          // side/align/offset with a viewport flip, pinned to the
          // trigger's width (the popper min-w contract).
          this._position = () => {
            const c = content()
            const t = trigger()
            if (!c || !t) return
            const side = root.dataset.side || "bottom"
            const align = root.dataset.align || "center"
            const offset = parseInt(root.dataset.sideOffset || "4", 10)
            c.style.minWidth = t.offsetWidth + "px"
            const rect = t.getBoundingClientRect()
            const place = (side) => {
              c.style.top = ""
              c.style.bottom = ""
              c.style.left = ""
              c.style.right = ""
              c.style.transform = ""
              if (side === "bottom") c.style.top = rect.bottom + offset + "px"
              else c.style.bottom = window.innerHeight - rect.top + offset + "px"
              if (align === "start") {
                c.style.left = rect.left + "px"
              } else if (align === "end") {
                c.style.left = rect.right - c.offsetWidth + "px"
              } else {
                c.style.left = rect.left + rect.width / 2 + "px"
                c.style.transform = "translateX(-50%)"
              }
            }
            place(side)
            // Flip when the listbox spills past the viewport (the Radix
            // collision behavior, simplified).
            const box = c.getBoundingClientRect()
            const maxH = Math.min(c.offsetHeight, window.innerHeight)
            const spills =
              side === "bottom"
                ? box.top + maxH > window.innerHeight
                : box.bottom - maxH < 0
            if (spills) place(side === "bottom" ? "top" : "bottom")
          }

          this._animateIn = (c) => {
            if (typeof c.animate !== "function") return
            const side = c.dataset.side || root.dataset.side || "bottom"
            const slide = side === "bottom" ? "translateY(-0.5rem)" : "translateY(0.5rem)"
            const zoom = c.animate(
              [
                { opacity: 0, transform: `${slide} scale(0.95)` },
                { opacity: 1, transform: "none" }
              ],
              { duration: 150, easing: "ease-out" }
            )
            zoom.finished
              .then(() => {
                c.style.transform = ""
              })
              .catch(() => {})
          }

          this._show = () => {
            const c = content()
            if (!c) return
            this._previouslyFocused = document.activeElement
            c.removeAttribute("hidden")
            c.setAttribute("data-state", "open")
            c.dataset.side = root.dataset.side || "bottom"
            root.dataset.state = "open"
            this._open = true
            const t = trigger()
            if (t) {
              t.dataset.state = "open"
              t.setAttribute("aria-expanded", "true")
            }
            this._position()
            this._animateIn(c)
            this._syncScrollButtons()
            // Space/arrows open at the selected item; Enter at the first.
            const selected = this._enabled().find((el) => el.dataset.value === this._value)
            this._highlight(selected || this._enabled()[0])
          }

          this._close = () => {
            const c = content()
            if (c) {
              c.setAttribute("hidden", "")
              c.setAttribute("data-state", "closed")
            }
            root.dataset.state = "closed"
            this._open = false
            const t = trigger()
            if (t) {
              t.dataset.state = "closed"
              t.setAttribute("aria-expanded", "false")
            }
            this._items().forEach((el) => (el.dataset.highlighted = "false"))
            if (this._previouslyFocused && typeof this._previouslyFocused.focus === "function") {
              this._previouslyFocused.focus()
            } else if (t) {
              t.focus()
            }
            this._previouslyFocused = null
          }

          // Toggle on trigger click (delegated, so LiveView morphs never
          // orphan it).
          this._onClick = (event) => {
            const t = trigger()
            if (t && t.contains(event.target)) {
              if (t.disabled) return
              event.preventDefault()
              if (this._open) this._close()
              else this._show()
              return
            }
            const item = event.target.closest("[data-polaris-select-item]")
            if (item && root.contains(item)) {
              if (item.dataset.disabled === "true") {
                event.preventDefault()
                return
              }
              this._select(item)
              this._close()
              return
            }
            const up = event.target.closest("[data-polaris-select-scroll-up]")
            if (up && root.contains(up)) {
              const vp = viewport()
              if (vp) vp.scrollTop -= vp.clientHeight * 0.8
            }
            const down = event.target.closest("[data-polaris-select-scroll-down]")
            if (down && root.contains(down)) {
              const vp = viewport()
              if (vp) vp.scrollTop += vp.clientHeight * 0.8
            }
          }
          root.addEventListener("click", this._onClick)

          this._onDocumentClick = (event) => {
            if (this._open && !root.contains(event.target)) this._close()
          }
          document.addEventListener("click", this._onDocumentClick)

          // Closed-trigger keys: Enter opens at the first item,
          // Space/arrows at the selected one.
          this._onTriggerKeydown = (event) => {
            if (this._open) return
            const t = trigger()
            if (!t || event.target !== t) return
            if (["Enter", " ", "ArrowDown", "ArrowUp"].includes(event.key)) {
              event.preventDefault()
              this._show()
              // Enter opens at the first item; Space/arrows at the selected.
              if (event.key === "Enter") this._highlight(this._enabled()[0])
            }
          }
          root.addEventListener("keydown", this._onTriggerKeydown)

          this._onKeydown = (event) => {
            if (!this._open) return
            const items = this._enabled()
            if (!items.length) return
            const focused = document.activeElement
            const c = content()
            const isItem = (el) => el && c && c.contains(el) && el.hasAttribute("data-polaris-select-item")
            if (event.key === "Escape") {
              event.preventDefault()
              this._close()
            } else if (event.key === "ArrowDown" && isItem(focused)) {
              event.preventDefault()
              const index = items.indexOf(focused)
              this._highlight(items[(index + 1) % items.length])
            } else if (event.key === "ArrowUp" && isItem(focused)) {
              event.preventDefault()
              const index = items.indexOf(focused)
              this._highlight(items[(index - 1 + items.length) % items.length])
            } else if (event.key === "Home" && isItem(focused)) {
              event.preventDefault()
              this._highlight(items[0])
            } else if (event.key === "End" && isItem(focused)) {
              event.preventDefault()
              this._highlight(items[items.length - 1])
            } else if ((event.key === "Enter" || event.key === " ") && isItem(focused)) {
              event.preventDefault()
              this._select(focused)
              this._close()
            } else if (event.key === "Tab") {
              this._close()
            } else if (event.key.length === 1 && !event.metaKey && !event.ctrlKey && !event.altKey) {
              // Typeahead: jump to the item whose label starts with the
              // buffered characters.
              const now = performance.now()
              if (now - this._typeaheadAt > 500) this._typeahead = ""
              this._typeaheadAt = now
              this._typeahead += event.key.toLowerCase()
              const match = items.find((item) =>
                (item.dataset.label || item.textContent || "").trim().toLowerCase().startsWith(this._typeahead)
              )
              if (match) {
                event.preventDefault()
                this._highlight(match)
              }
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)

          // Hover highlights via real focus, the Radix pointermove model.
          this._onPointerMove = (event) => {
            if (!this._open) return
            const item = event.target.closest("[data-polaris-select-item]")
            if (
              item &&
              root.contains(item) &&
              item.dataset.disabled !== "true" &&
              item !== document.activeElement
            ) {
              this._highlight(item)
            }
          }
          document.addEventListener("pointermove", this._onPointerMove)

          const vp0 = viewport()
          if (vp0) vp0.addEventListener("scroll", () => this._syncScrollButtons(), { passive: true })

          this._value = root.dataset.value || null
          this._apply()
        },
        updated() {
          // LiveView patches may stomp paint; re-apply the hook-owned state.
          this._apply()
          if (this._open) this._position()
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onClick)
          this.el.removeEventListener("keydown", this._onTriggerKeydown)
          document.removeEventListener("click", this._onDocumentClick)
          document.removeEventListener("keydown", this._onKeydown, true)
          document.removeEventListener("pointermove", this._onPointerMove)
        }
      }
    </script>
    """
  end

  # Options: strings are both value and label; maps fill their gaps
  # (atom or string keys alike).
  defp normalize_options(options) do
    Enum.map(options, fn
      option when is_binary(option) ->
        %{value: option, label: option, disabled: false, group: nil}

      option when is_map(option) ->
        value = option_value(option, :value) || option_value(option, :label)
        label = option_value(option, :label) || option_value(option, :value)
        group = option_value(option, :group)

        %{
          value: to_string(value),
          label: to_string(label),
          disabled: option_value(option, :disabled) == true,
          group: group && to_string(group)
        }
    end)
  end

  defp option_value(option, key) do
    Map.get(option, key) || Map.get(option, to_string(key))
  end

  # Consecutive options sharing a group render as one run under a
  # single label — insertion order preserved, like the source's
  # explicit SelectGroup blocks.
  defp group_runs(options) do
    options
    |> Enum.reduce([], fn option, runs ->
      case runs do
        [%{label: label, options: run} | rest] when label != nil and label == option.group ->
          [%{label: label, options: run ++ [option]} | rest]

        _ ->
          [%{label: option.group, options: [option]} | runs]
      end
    end)
    |> Enum.reverse()
  end

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
