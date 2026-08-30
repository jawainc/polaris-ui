defmodule PolarisUI.Components.RadioGroup do
  @moduledoc """
  The Polaris radio group: a mutually exclusive single-select set — the
  port of the Supabase design system RadioGroup family (`packages/ui`):
  the shadcn/Radix base group, the `RadioGroupCard` tiles, and the
  `RadioGroupStacked` segmented list.

  ## Families

      <.radio_group id="plan" name="plan" value={@plan} on_change="pick-plan">
        <.radio_group_item value="pro" id="plan-pro" checked={@plan == "pro"}>
          Pro
        </.radio_group_item>
        <.radio_group_item value="free" id="plan-free">Free</.radio_group_item>
      </.radio_group>

      <.radio_group_card id="themes" value="dark">
        <.radio_group_card_item value="dark" label="Dark">
          <img src="/themes/dark.svg" alt="" class="w-full rounded-sm" />
        </.radio_group_card_item>
      </.radio_group_card>

      <.radio_group_stacked id="density" value="comfortable">
        <.radio_group_stacked_item value="compact" label="Compact"
          description="The most space-efficient layout." />
      </.radio_group_stacked>

    * **base** — `relative grid gap-2` rows of 16px circles with the
      filled brand dot; the inner block is a paired `<label for>` when
      `id` is given.
    * **card** — `w-48` tiles: visual content above a label row with the
      circle indicator (`bg-surface-panel`, border lifting on hover and
      check).
    * **stacked** — full-width segments joined with `-space-y-px`, first/
      last rounded, hover and check brightening the surface; `label` plus
      a `description` line.

  ## State model

  Like Radix, selection is **client-side**: the colocated runtime hook
  owns the state machine — click or arrow keys check an item (radios
  never uncheck), roving tabindex keeps one tab stop (the checked item,
  else the first enabled), and the hook re-applies after LiveView
  patches so selections survive re-renders. Seed the initial selection
  either from the root's `value` or per-item `checked` (which also
  paints the server-rendered HTML); from mount on, the hook is
  authoritative.

  ## Keyboard

  **ArrowDown**/**ArrowRight** check the next enabled item,
  **ArrowUp**/**ArrowLeft** the previous (wrapping), **Home**/**End**
  the first/last; **Tab** enters the group at the single tab stop and
  moves on — the roving model, like the source. Items are real buttons,
  so **Enter**/**Space** check the focused item natively.

  ## Form participation & events

  With `name`, a hidden input carries the selection into form
  submissions (the hook syncs its value and dispatches bubbling
  `input`/`change` so `phx-change` forms observe changes). With
  `on_change`, every selection pushes `%{"value" => value}` to the
  server:

      def handle_event("pick-plan", %{"value" => value}, socket) do
        {:noreply, assign(socket, plan: value)}
      end

  ## States

    * **rest / hover** — the brand-muted border (the source's
      `border-primary`) brightening on hover; the dot cross-fades in
      over 150ms.
    * **focus-ring** — the shared emerald `focus-visible` ring on the
      interactive face (the circle, the tile, the segment).
    * **checked** — `data-state="checked"` / `aria-checked="true"` with
      the emerald border and filled dot; cards and segments lift their
      border and surface like the source's `data-[state=checked]`
      treatments.
    * **disabled** — native `disabled`, 50% opacity,
      `cursor-not-allowed`, dropped from the tab order and skipped by
      arrows (the Safari `tabindex="-1"` fix from the source).

  ## Microcopy

  Per the Supabase copywriting guidelines: labels are concise option
  nouns ("Pro", "Compact"), and stacked descriptions state the
  consequence in one plain sentence.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  # The three roots share one hook, one hidden-input contract, and one
  # item marker; only the container classes and item anatomies differ.
  @hook "#{inspect(__MODULE__)}.Root"

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the group root — required because the colocated hook
    that owns selection anchors on it.
    """
  )

  attr(:name, :string,
    default: nil,
    doc: """
    Form field name — renders the hidden input carrying the selection
    into form submissions (omit for purely interactive groups).
    """
  )

  attr(:value, :string,
    default: nil,
    doc:
      "Initial selection (the item whose `value` matches). The hook owns selection from mount on."
  )

  attr(:on_change, :string,
    default: nil,
    doc: "Optional LiveView event pushed on every selection with `%{\"value\" => value}`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")
  attr(:rest, :global, doc: "Forwarded to the group: `aria-label`, `aria-required`, `data-*`, …")

  slot(:inner_block, required: true, doc: "The `radio_group_item`s.")

  def radio_group(assigns) do
    render_root(assigns, "relative grid gap-2")
  end

  @doc """
  The card family root — the source's `RadioGroupCard`: the same grid
  container hosting `radio_group_card_item` tiles (often re-flowed with
  `class="flex flex-wrap gap-3"`).
  """
  attr(:id, :string, required: true, doc: "Unique id for the group root (see `radio_group`).")
  attr(:name, :string, default: nil, doc: "Form field name — renders the hidden input.")
  attr(:value, :string, default: nil, doc: "Initial selection (the item whose `value` matches).")

  attr(:on_change, :string,
    default: nil,
    doc: "Optional LiveView event pushed with `%{\"value\" => value}`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")
  attr(:rest, :global, doc: "Forwarded to the group: `aria-label`, `aria-required`, `data-*`, …")

  slot(:inner_block, required: true, doc: "The `radio_group_card_item`s.")

  def radio_group_card(assigns) do
    render_root(assigns, "relative grid gap-2")
  end

  @doc """
  The stacked family root — the source's `RadioGroupStacked`: a
  full-width column of segments joined with `-space-y-px`, rounded only
  on the first and last.
  """
  attr(:id, :string, required: true, doc: "Unique id for the group root (see `radio_group`).")
  attr(:name, :string, default: nil, doc: "Form field name — renders the hidden input.")
  attr(:value, :string, default: nil, doc: "Initial selection (the item whose `value` matches).")

  attr(:on_change, :string,
    default: nil,
    doc: "Optional LiveView event pushed with `%{\"value\" => value}`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")
  attr(:rest, :global, doc: "Forwarded to the group: `aria-label`, `aria-required`, `data-*`, …")

  slot(:inner_block, required: true, doc: "The `radio_group_stacked_item`s.")

  def radio_group_stacked(assigns) do
    render_root(assigns, "relative flex w-full flex-col -space-y-px")
  end

  defp render_root(assigns, container) do
    assigns =
      assign(assigns,
        hook: @hook,
        container_classes: cn([container, assigns.class])
      )

    ~H"""
    <div
      id={@id}
      role="radiogroup"
      data-polaris-radio-group
      data-value={@value}
      data-change-event={@on_change}
      class={@container_classes}
      phx-hook={@hook}
      {@rest}
    >
      {render_slot(@inner_block)}
      <input :if={@name} type="hidden" name={@name} value={@value} data-polaris-radio-input />
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          this._items = () => Array.from(root.querySelectorAll("[data-polaris-radio-group-item]"))
          this._input = () => root.querySelector("[data-polaris-radio-input]")
          this._enabled = () => this._items().filter((el) => el.dataset.disabled !== "true")

          // Per-item data-checked wins (it also paints the SSR markup);
          // fall back to the root's value seed.
          const seeded = root.querySelector('[data-polaris-radio-group-item][data-checked="true"]')
          this._value = seeded ? seeded.dataset.value : root.dataset.value || null

          // Radios never uncheck; roving tabindex keeps one tab stop.
          this._apply = () => {
            const enabled = this._enabled()
            const tabstop =
              this._value != null
                ? enabled.find((el) => el.dataset.value === this._value)
                : enabled[0]
            this._items().forEach((el) => {
              const checked = this._value != null && el.dataset.value === this._value
              el.dataset.state = checked ? "checked" : "unchecked"
              el.setAttribute("aria-checked", checked ? "true" : "false")
              el.tabIndex = el === tabstop ? 0 : -1
            })
            const input = this._input()
            if (input) input.value = this._value == null ? "" : this._value
          }

          this._select = (item) => {
            if (!item || item.dataset.disabled === "true") return
            if (item.dataset.value !== this._value) {
              this._value = item.dataset.value
              this._apply()
              const input = this._input()
              if (input) {
                // Bubble through the hidden input so phx-change forms observe it.
                input.dispatchEvent(new Event("input", { bubbles: true }))
                input.dispatchEvent(new Event("change", { bubbles: true }))
              }
              const name = root.dataset.changeEvent
              if (name && typeof this.pushEvent === "function") {
                this.pushEvent(name, { value: this._value })
              }
            }
          }

          // Delegated on the root, so LiveView morphs never orphan it;
          // buttons fire click for pointer, Enter, and Space alike.
          this._onClick = (event) => {
            const item = event.target.closest("[data-polaris-radio-group-item]")
            if (item && root.contains(item)) this._select(item)
          }
          root.addEventListener("click", this._onClick)

          this._onKeydown = (event) => {
            const item = event.target.closest("[data-polaris-radio-group-item]")
            if (!item || !root.contains(item)) return
            const enabled = this._enabled()
            if (!enabled.length) return
            const index = enabled.indexOf(item)
            const move = (i) => {
              event.preventDefault()
              const next = enabled[i]
              this._select(next)
              next.focus()
            }
            if (event.key === "ArrowDown" || event.key === "ArrowRight") {
              move((index + 1) % enabled.length)
            } else if (event.key === "ArrowUp" || event.key === "ArrowLeft") {
              move((index - 1 + enabled.length) % enabled.length)
            } else if (event.key === "Home") {
              move(0)
            } else if (event.key === "End") {
              move(enabled.length - 1)
            }
          }
          root.addEventListener("keydown", this._onKeydown)

          this._apply()
        },
        updated() {
          // LiveView patches may stomp data-state/aria/tabindex; re-apply.
          this._apply()
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onClick)
          this.el.removeEventListener("keydown", this._onKeydown)
        }
      }
    </script>
    """
  end

  @doc """
  The base item: the 16px circle with the filled brand dot — the
  source's RadioGroupItem. Give `id` to wire the inner-block label to
  the circle.
  """
  attr(:value, :string,
    required: true,
    doc: "The choice this item carries (unique in the group)."
  )

  attr(:id, :string,
    default: nil,
    doc:
      "Unique id for the circle — wires the paired label's `for` and the item's accessible name."
  )

  attr(:checked, :boolean,
    default: false,
    doc: "Initial checked paint (the hook seeds from it and owns selection from mount on)."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Locks the item, dims it, and drops it from the tab order."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the circle (e.g. `h-5 w-5`)."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the circle button: `aria-describedby`, `data-*`,
    `phx-*`, …
    """
  )

  slot(:inner_block, doc: "Label text — a concise option noun (\"Pro\"). Pass `id` to wire it.")

  def radio_group_item(assigns) do
    state = if(assigns.checked, do: "checked", else: "unchecked")
    has_label = assigns.inner_block != []

    assigns =
      assign(assigns,
        state: state,
        has_label: has_label
      )

    ~H"""
    <div class="flex items-center gap-2" data-polaris-radio-option>
      <button
        type="button"
        role="radio"
        id={@id}
        aria-checked={to_string(@checked)}
        aria-labelledby={@has_label && @id && "#{@id}-label"}
        data-polaris-radio-group-item
        data-value={@value}
        data-checked={to_string(@checked)}
        data-state={@state}
        data-disabled={to_string(@disabled)}
        disabled={@disabled}
        tabindex={if(@checked, do: "0", else: "-1")}
        class={
          cn([
            "peer group relative aspect-square h-4 w-4 shrink-0 cursor-pointer rounded-full border",
            "transition-colors duration-150 ease-in-out",
            "border-brand-border hover:border-brand-border-hover",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "disabled:cursor-not-allowed disabled:opacity-50",
            "data-[state=checked]:border-brand-emerald data-[state=checked]:text-brand-emerald",
            @class
          ])
        }
        {@rest}
      >
        <span
          data-polaris-radio-indicator
          class="absolute left-1/2 top-1/2 flex -translate-x-1/2 -translate-y-1/2 items-center justify-center"
          aria-hidden="true"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            stroke="none"
            class="size-2.5 fill-current opacity-0 transition-opacity duration-150 ease-in-out group-data-[state=checked]:opacity-100 motion-reduce:transition-none"
          >
            <circle cx="12" cy="12" r="10" />
          </svg>
        </span>
      </button>
      <label
        :if={@has_label && @id}
        for={@id}
        id={"#{@id}-label"}
        class="cursor-pointer text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
      >
        {render_slot(@inner_block)}
      </label>
      <span
        :if={@has_label && !@id}
        class="text-sm font-medium leading-none peer-disabled:opacity-70"
      >
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  @doc """
  The card item: a `w-48` selectable tile — the source's
  RadioGroupCardItem. The inner block renders as the visual content
  above the label row; `show_indicator` drops the circle.
  """
  attr(:value, :string,
    required: true,
    doc: "The choice this tile carries (unique in the group)."
  )

  attr(:label, :string, required: true, doc: "The tile's label — a concise option noun.")

  attr(:show_indicator, :boolean,
    default: true,
    doc: "Hide the circle indicator when the visual content says it all."
  )

  attr(:checked, :boolean,
    default: false,
    doc: "Initial checked paint (the hook owns selection from mount on)."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Locks the tile, dims it, and drops it from the tab order."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the tile.")

  attr(:rest, :global,
    doc: """
    Forwarded to the tile button: `aria-describedby`, `data-*`,
    `phx-*`, …
    """
  )

  slot(:inner_block, doc: "Visual content above the label row (an image, a preview, …).")

  def radio_group_card_item(assigns) do
    ~H"""
    <button
      type="button"
      role="radio"
      aria-checked={to_string(@checked)}
      data-polaris-radio-group-item
      data-value={@value}
      data-checked={to_string(@checked)}
      data-state={if(@checked, do: "checked", else: "unchecked")}
      data-disabled={to_string(@disabled)}
      disabled={@disabled}
      tabindex={if(@checked, do: "0", else: "-1")}
      class={
        cn([
          "group flex w-48 flex-col gap-2 rounded-md border border-surface-border bg-surface-panel p-2 text-left",
          "outline-none transition-colors",
          "hover:z-1 hover:border-surface-border-hover",
          "focus-visible:z-1 focus-visible:border-surface-border-hover",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
          "disabled:cursor-not-allowed disabled:opacity-50",
          "data-[state=checked]:border-surface-border-hover data-[state=checked]:text-brand-emerald",
          @class
        ])
      }
      aria-label={@label}
      {@rest}
    >
      {render_slot(@inner_block)}
      <span class="flex w-full gap-2">
        <span
          :if={@show_indicator}
          aria-hidden="true"
          class="relative mt-0.5 flex h-4 w-4 min-w-4 shrink-0 items-center justify-center rounded-full border border-brand-border transition-colors group-hover:border-brand-border-hover group-disabled:border-brand-border"
        >
          <span
            data-polaris-radio-indicator
            class="size-2 rounded-full bg-current opacity-0 transition-opacity duration-150 ease-in-out group-data-[state=checked]:opacity-100 motion-reduce:transition-none"
          ></span>
        </span>
        <span class="w-full text-left text-xs leading-none text-content-secondary transition-colors group-hover:text-content-primary group-data-[state=checked]:text-content-primary group-disabled:cursor-not-allowed">
          {@label}
        </span>
      </span>
    </button>
    """
  end

  @doc """
  The stacked item: one full-width segment of the joined list — the
  source's RadioGroupStackedItem, with the `label`, an optional
  `description`, and extra children under them.
  """
  attr(:value, :string,
    required: true,
    doc: "The choice this segment carries (unique in the group)."
  )

  attr(:label, :string, required: true, doc: "The segment's label — a concise option noun.")

  attr(:description, :string,
    default: nil,
    doc: "The one-sentence consequence line under the label."
  )

  attr(:show_indicator, :boolean, default: true, doc: "Hide the circle indicator for bare lists.")

  attr(:checked, :boolean,
    default: false,
    doc: "Initial checked paint (the hook owns selection from mount on)."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Locks the segment, dims it, and drops it from the tab order."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the segment.")

  attr(:rest, :global,
    doc: """
    Forwarded to the segment button: `aria-describedby`, `data-*`,
    `phx-*`, …
    """
  )

  slot(:inner_block, doc: "Extra content under the description.")

  def radio_group_stacked_item(assigns) do
    ~H"""
    <button
      type="button"
      role="radio"
      aria-checked={to_string(@checked)}
      data-polaris-radio-group-item
      data-value={@value}
      data-checked={to_string(@checked)}
      data-state={if(@checked, do: "checked", else: "unchecked")}
      data-disabled={to_string(@disabled)}
      disabled={@disabled}
      tabindex={if(@checked, do: "0", else: "-1")}
      class={
        cn([
          "group flex w-full flex-col gap-2 border border-surface-border bg-surface-panel/50 shadow-xs",
          "first-of-type:rounded-t-lg last-of-type:rounded-b-lg",
          "enabled:cursor-pointer enabled:hover:border-surface-border-hover enabled:hover:bg-surface-panel-hover",
          "hover:z-1 focus-visible:z-1 data-[state=checked]:z-1",
          "data-[state=checked]:border-surface-border-hover data-[state=checked]:bg-surface-panel-hover data-[state=checked]:text-brand-emerald",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
          "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
          "disabled:cursor-not-allowed disabled:opacity-50",
          "transition-colors",
          @class
        ])
      }
      aria-label={@label}
      {@rest}
    >
      <div class="flex w-full gap-3 px-[21px] py-3">
        <span
          :if={@show_indicator}
          aria-hidden="true"
          class="relative mt-0.5 flex h-4 w-4 min-w-4 shrink-0 items-center justify-center rounded-full border border-brand-border transition-colors group-hover:border-brand-border-hover"
        >
          <span
            data-polaris-radio-indicator
            class="size-2 rounded-full bg-current opacity-0 transition-opacity duration-150 ease-in-out group-data-[state=checked]:opacity-100 motion-reduce:transition-none"
          ></span>
        </span>
        <div class="flex flex-col items-start gap-0.5">
          <span class="block text-left text-sm font-medium leading-none text-content-secondary transition-colors group-hover:text-content-primary group-data-[state=checked]:text-content-primary">
            {@label}
          </span>
          <p
            :if={@description}
            class="text-balance text-left text-sm leading-snug text-content-secondary"
          >
            {@description}
          </p>
          {render_slot(@inner_block)}
        </div>
      </div>
    </button>
    """
  end
end
