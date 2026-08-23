defmodule PolarisUI.Components.Accordion do
  @moduledoc """
  The Polaris accordion: a vertically stacked set of interactive headings
  that each reveal a section of content.

  Port of the Supabase design system Accordion (`packages/ui`, a shadcn
  wrapper over the Radix Accordion): separated `border-b` items, a
  full-width underlined trigger with a rotating chevron, and animated
  height-collapsing content regions — adhering to the WAI-ARIA accordion
  design pattern.

  ## Anatomy

      <.accordion id="faq" type="single" collapsible>
        <:item value="item-1" title="Is it accessible?">
          Yes. It adheres to the WAI-ARIA design pattern.
        </:item>
        <:item value="item-2" title="Is it animated?" hide_icon>
          Yes. 150ms ease-out, disabled under reduced motion.
        </:item>
      </.accordion>

    * **item** — one `<:item>` slot entry per section (the Radix
      `AccordionItem`), separated by the item's bottom border.
    * **trigger** — the `title` renders into the full-width trigger
      button (`flex-1 py-4 font-medium hover:underline`), with an
      auto-rotating chevron suppressed via `hide_icon` (the Supabase
      `hideIcon` prop).
    * **content** — the item's inner block, padded `pb-4 pt-0` inside an
      animated, `overflow-hidden` region.

  ## Open-state model

  Visibility is **client-side**, like Radix: the colocated runtime hook
  owns the open set, starting from `default_open`. `type="single"`
  (the default) keeps at most one item open; `collapsible` (default
  `true`) allows closing it again — `type="single"` without
  `collapsible` pins one item open. `type="multiple"` toggles items
  independently. Pass `on_change` to mirror toggles back to the server
  (the hook pushes the event with `%{"value" => value, "state" =>
  "open" | "closed"}`); otherwise the accordion never needs a round
  trip — the hook re-applies its state after LiveView patches, so
  toggles survive re-renders.

  ## States

    * **rest / hover** — `hover:underline` on the trigger; the chevron
      rotates 180° while open (`[&[data-state=open]>svg]:rotate-180`,
      exactly like the source).
    * **focus-ring** — a high-visibility emerald ring on
      `:focus-visible` only. Triggers carry an explicit `tabindex` (the
      Supabase `getExplicitTabIndex` Safari fix) with roving tabindex:
      one tab stop for the whole accordion, moved with ArrowUp /
      ArrowDown / Home / End.
    * **disabled** — per item: native `disabled`, `tabindex="-1"`
      (dropped from the tab order), `cursor-not-allowed` at 50% opacity,
      and skipped by keyboard navigation. A caller-provided `tabindex`
      on the item always wins.
    * **motion** — the 150ms ease-out height animation and the 200ms
      chevron rotation both switch off under `prefers-reduced-motion`.

  The content height animates with the CSS `grid-template-rows` technique
  (`grid-rows-[0fr]` → `grid-rows-[1fr]`) instead of Radix's measured
  `--radix-accordion-content-height` keyframes — the same 150ms ease-out
  feel with zero measurement, adapting to dynamic content. Closed regions
  are `invisible` (unreachable by screen readers) but stay visible during
  the closing transition, since `visibility` interpolates as a discrete
  step that holds `visible` until the transition ends.

  ## Accessibility

    * Triggers are `<button>`s carrying `aria-expanded` + `aria-controls`;
      content regions render `role="region"` + `aria-labelledby`, wired by
      derived ids (`<id>-<value>-trigger` / `-content`).
    * The chevron is `aria-hidden` decoration.
    * `Enter`/`Space` toggle (native button behavior); arrows move between
      triggers; `Home`/`End` jump to the first/last.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @types ~w(single multiple)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the accordion root — required because the colocated hook
    that owns the open state anchors on it. Per-item element ids derive
    from it (`"<id>-<value>-trigger"` / `"<id>-<value>-content"`).
    """
  )

  attr(:type, :string,
    values: @types,
    default: "single",
    doc: """
    `"single"` keeps at most one item open; `"multiple"` toggles items
    independently (then every item is closable and `collapsible` is moot).
    """
  )

  attr(:collapsible, :boolean,
    default: true,
    doc: """
    With `type="single"`: allow closing the open item (so all can be
    closed). When false, one item stays pinned open.
    """
  )

  attr(:default_open, :list,
    default: [],
    doc: """
    Values of the items open on first render — a bare string opens one
    item. In single mode only the first applies.
    """
  )

  attr(:on_change, :string,
    default: nil,
    doc: """
    Optional LiveView event pushed on every toggle with
    `%{"value" => value, "state" => "open" | "closed"}`.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged last — caller classes win conflicts via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  slot :item, required: true do
    attr(:value, :string,
      required: true,
      doc: "Item identity — used for state tracking and the derived element ids."
    )

    attr(:title, :string,
      required: true,
      doc: "Trigger label (plain text — style it through the trigger's `class`)."
    )

    attr(:disabled, :boolean,
      doc: """
      Disables the trigger: native disabled, out of the tab order, skipped
      by arrows. Defaults to false at access time (slot attrs carry no defaults).
      """
    )

    attr(:hide_icon, :boolean,
      doc: "Suppress the auto-rotating chevron (the Supabase `hideIcon` prop). Defaults to false."
    )

    attr(:class, :string, doc: "Additional classes merged onto the item.")

    attr(:tabindex, :string,
      doc: "Override the computed roving tabindex of the trigger (caller wins)."
    )
  end

  def accordion(assigns) do
    validate_in!(:type, assigns.type, @types)

    # Normalize default_open (a bare string opens one item, like Radix's
    # defaultValue), clamped to a single value in single mode.
    open_values =
      assigns.default_open
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.uniq()
      |> then(&if(assigns.type == "multiple", do: &1, else: Enum.take(&1, 1)))

    assigns =
      assign(assigns,
        open_values: open_values,
        hook: "#{inspect(__MODULE__)}.Root"
      )

    ~H"""
    <div
      id={@id}
      class={@class}
      data-polaris-accordion
      data-type={@type}
      data-collapsible={if @type == "single" and @collapsible, do: "true", else: "false"}
      data-change-event={@on_change}
      phx-hook={@hook}
      {@rest}
    >
      <div
        :for={item <- @item}
        data-polaris-accordion-item
        data-value={item.value}
        data-state={if item.value in @open_values, do: "open", else: "closed"}
        class={cn(["border-b", item[:class]])}
      >
        <div class="flex">
          <button
            type="button"
            id={"#{@id}-#{item.value}-trigger"}
            data-polaris-accordion-trigger
            data-state={if item.value in @open_values, do: "open", else: "closed"}
            aria-expanded={to_string(item.value in @open_values)}
            aria-controls={"#{@id}-#{item.value}-content"}
            disabled={item[:disabled] || false}
            tabindex={item[:tabindex] || if(item[:disabled], do: "-1", else: "0")}
            data-polaris-tabindex={item[:tabindex] && "true"}
            class={
              cn([
                "flex flex-1 cursor-pointer items-center justify-between gap-2 py-4 text-left",
                "font-medium transition-all hover:underline",
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
                "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
                "disabled:cursor-not-allowed disabled:opacity-50",
                "[&[data-state=open]>svg]:rotate-180"
              ])
            }
          >
            <span>{item.title}</span>
            <.chevron :if={!(item[:hide_icon] || false)} />
          </button>
        </div>
        <div
          id={"#{@id}-#{item.value}-content"}
          data-polaris-accordion-content
          data-state={if item.value in @open_values, do: "open", else: "closed"}
          role="region"
          aria-labelledby={"#{@id}-#{item.value}-trigger"}
          class={
            cn([
              "grid overflow-hidden text-sm transition-all duration-150 ease-out",
              "data-[state=closed]:invisible data-[state=closed]:grid-rows-[0fr]",
              "data-[state=open]:grid-rows-[1fr]",
              "motion-reduce:transition-none"
            ])
          }
        >
          <div class="overflow-hidden">
            <div class="pb-4 pt-0">{render_slot(item)}</div>
          </div>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          this._onClick = (event) => {
            const trigger = event.target.closest("[data-polaris-accordion-trigger]")
            if (!trigger || trigger.disabled || !this.el.contains(trigger)) return
            this._toggle(trigger.closest("[data-polaris-accordion-item]").dataset.value)
          }
          this._onKeydown = (event) => {
            const triggers = this._triggers().filter((t) => !t.disabled)
            if (triggers.length === 0) return
            const index = triggers.indexOf(event.target)
            if (index === -1) return
            if (event.key === "ArrowDown") {
              event.preventDefault()
              triggers[(index + 1) % triggers.length].focus()
            } else if (event.key === "ArrowUp") {
              event.preventDefault()
              triggers[(index - 1 + triggers.length) % triggers.length].focus()
            } else if (event.key === "Home") {
              event.preventDefault()
              triggers[0].focus()
            } else if (event.key === "End") {
              event.preventDefault()
              triggers[triggers.length - 1].focus()
            }
          }
          // Seed the open set from the server-rendered data-state.
          this._open = new Set(
            this._items()
              .filter((item) => item.dataset.state === "open")
              .map((item) => item.dataset.value)
          )
          this.el.addEventListener("click", this._onClick)
          this.el.addEventListener("keydown", this._onKeydown)
          this._apply()
        },
        updated() {
          // LiveView patches may stomp data-state/aria/tabindex; re-apply.
          this._apply()
        },
        destroyed() {
          this.el.removeEventListener("click", this._onClick)
          this.el.removeEventListener("keydown", this._onKeydown)
        },
        _items() {
          return Array.from(this.el.querySelectorAll("[data-polaris-accordion-item]"))
        },
        _triggers() {
          return Array.from(this.el.querySelectorAll("[data-polaris-accordion-trigger]"))
        },
        _toggle(value) {
          const multiple = this.el.dataset.type === "multiple"
          const collapsible = this.el.dataset.collapsible === "true"
          const wasOpen = this._open.has(value)
          if (multiple) {
            wasOpen ? this._open.delete(value) : this._open.add(value)
          } else if (wasOpen && collapsible) {
            this._open.clear()
          } else if (!wasOpen) {
            this._open.clear()
            this._open.add(value)
          }
          this._apply()
          const name = this.el.dataset.changeEvent
          if (name && typeof this.pushEvent === "function") {
            this.pushEvent(name, { value: value, state: wasOpen ? "closed" : "open" })
          }
        },
        _apply() {
          const items = this._items()
          for (const item of items) {
            const open = this._open.has(item.dataset.value)
            const state = open ? "open" : "closed"
            item.dataset.state = state
            const trigger = item.querySelector("[data-polaris-accordion-trigger]")
            const content = item.querySelector("[data-polaris-accordion-content]")
            if (trigger) {
              trigger.dataset.state = state
              trigger.setAttribute("aria-expanded", String(open))
            }
            if (content) {
              content.dataset.state = state
            }
          }
          this._rove()
        },
        _rove() {
          // One tab stop for the whole accordion: the first open item's
          // trigger, else the first enabled trigger (the Radix pattern).
          const triggers = this._triggers()
          const active =
            triggers.find((t) => !t.disabled && t.getAttribute("aria-expanded") === "true") ||
            triggers.find((t) => !t.disabled)
          for (const trigger of triggers) {
            if (trigger.hasAttribute("data-polaris-tabindex")) continue
            trigger.tabIndex = trigger === active ? 0 : -1
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

  # The chevron: lucide ChevronDown at 16px, rotating on open via the
  # trigger's [&[data-state=open]>svg]:rotate-180 selector (exact source).
  defp chevron(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      class="h-4 w-4 shrink-0 transition-transform duration-200 motion-reduce:transition-none motion-reduce:duration-0"
    >
      <path d="m6 9 6 6 6-6" />
    </svg>
    """
  end
end
