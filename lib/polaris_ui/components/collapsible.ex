defmodule PolarisUI.Components.Collapsible do
  @moduledoc """
  The Polaris collapsible: the low-level disclosure primitive — the port
  of the Supabase design system Collapsible (`packages/ui`, a near-passthrough
  over the Radix Collapsible).

  Use it for generic disclosure behaviour where the trigger and content
  need custom composition — rows, sections, tool details, custom layouts.
  For pre-composed patterns reach for `<.accordion>` (stacked FAQs) or the
  `collapsible_card_section` / `collapsible_alert` fragments instead.

  ## Anatomy

      <.collapsible id="usage">
        <:trigger>View usage instructions</:trigger>
        <:content class="pt-2">
          <p>Run `mix deps.get` to fetch dependencies.</p>
        </:content>
      </.collapsible>

    * **root** — the stateful `<div>` the colocated hook anchors on.
    * **trigger** — the `:trigger` slot renders into a full-width
      `<button>` with `aria-expanded` + `aria-controls` (the Supabase
      primitive is unstyled; Polaris gives it only the shared interaction
      states — cursor and focus ring — leaving its visual identity to you).
    * **content** — the `:content` slot renders into the `role="region"`
      area, hidden from assistive tech while closed.

  ## Open-state model

  Visibility is **client-side**, like Radix: the colocated runtime hook
  owns the state, starting from `default_open`. The hook re-applies its
  state after LiveView patches, so toggles survive re-renders without a
  round trip. Pass `on_change` to mirror toggles back to the server (the
  hook pushes `%{"state" => "open" | "closed"}`).

  ## States

    * **rest / hover** — no visual treatment of its own (a primitive);
      layer `hover:underline` or color shifts via the slot's `class`.
    * **focus-ring** — high-visibility emerald ring on the trigger,
      `:focus-visible` only.
    * **disabled** — the root `disabled` prop disables the trigger:
      native `disabled`, `tabindex="-1"` (the Supabase
      `getExplicitTabIndex` Safari fix), `cursor-not-allowed` at 50%
      opacity, and the hook refuses to toggle.
    * **motion** — the 150ms ease-out height animation (the CSS
      `grid-template-rows` technique, like `<.accordion>`) switches off
      under `prefers-reduced-motion`; opt out entirely with
      `class="transition-none"` on the content slot.

  The Supabase docs ship animation as opt-in (`data-closed:animate-
  collapsible-up`); Polaris animates by default so the primitive feels
  finished, with the same closed regions `invisible` (unreachable by
  screen readers) but held `visible` during the closing transition.

  ## Accessibility

    * The trigger is a real `<button>` carrying `aria-expanded` +
      `aria-controls`; `Enter`/`Space` toggle (native button behavior).
    * The content region renders `role="region"` + `aria-labelledby`,
      wired by derived ids (`<id>-trigger` / `<id>-content`).

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the collapsible root — required because the colocated
    hook that owns the open state anchors on it. Trigger and content
    element ids derive from it (`"<id>-trigger"` / `"<id>-content"`).
    """
  )

  attr(:default_open, :boolean,
    default: false,
    doc: "Reveals the content on first render."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: """
    Disables the whole disclosure (the Radix root `disabled`): the trigger
    locks and the hook refuses to toggle.
    """
  )

  attr(:on_change, :string,
    default: nil,
    doc: """
    Optional LiveView event pushed on every toggle with
    `%{"state" => "open" | "closed"}`.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root `<div>`."
  )

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  slot :trigger, required: true do
    attr(:class, :string,
      doc: """
      Additional classes merged onto the trigger `<button>` — the place for
      visual identity (e.g. `font-medium hover:underline`).
      """
    )
  end

  slot :content, required: true do
    attr(:class, :string, doc: "Additional classes merged onto the content region.")
  end

  def collapsible(assigns) do
    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        state: if(assigns.default_open, do: "open", else: "closed"),
        trigger_class: List.first(assigns.trigger)[:class],
        content_class: List.first(assigns.content)[:class]
      )

    ~H"""
    <div
      id={@id}
      class={@class}
      data-polaris-collapsible
      data-state={@state}
      data-disabled={to_string(@disabled)}
      data-change-event={@on_change}
      phx-hook={@hook}
      {@rest}
    >
      <button
        type="button"
        id={"#{@id}-trigger"}
        data-polaris-collapsible-trigger
        data-state={@state}
        aria-expanded={to_string(@default_open)}
        aria-controls={"#{@id}-content"}
        disabled={@disabled}
        tabindex={if(@disabled, do: "-1", else: "0")}
        class={
          cn([
            "cursor-pointer text-left transition-colors rounded-xs",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "disabled:cursor-not-allowed disabled:opacity-50",
            @trigger_class
          ])
        }
      >
        {render_slot(@trigger)}
      </button>
      <div
        id={"#{@id}-content"}
        data-polaris-collapsible-content
        data-state={@state}
        role="region"
        aria-labelledby={"#{@id}-trigger"}
        class={
          cn([
            "grid overflow-hidden transition-all duration-150 ease-out",
            "data-[state=closed]:invisible data-[state=closed]:grid-rows-[0fr]",
            "data-[state=open]:grid-rows-[1fr]",
            "motion-reduce:transition-none",
            @content_class
          ])
        }
      >
        <div class="overflow-hidden">
          {render_slot(@content)}
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          this._open = this.el.dataset.state === "open"
          this._onClick = (event) => {
            const trigger = event.target.closest("[data-polaris-collapsible-trigger]")
            if (!trigger || !this.el.contains(trigger)) return
            if (trigger.disabled || this.el.dataset.disabled === "true") return
            this._open = !this._open
            this._apply()
            const name = this.el.dataset.changeEvent
            if (name && typeof this.pushEvent === "function") {
              this.pushEvent(name, { state: this._open ? "open" : "closed" })
            }
          }
          this.el.addEventListener("click", this._onClick)
        },
        updated() {
          // LiveView patches may stomp data-state/aria; re-apply.
          this._apply()
        },
        destroyed() {
          this.el.removeEventListener("click", this._onClick)
        },
        _apply() {
          const state = this._open ? "open" : "closed"
          this.el.dataset.state = state
          const trigger = this.el.querySelector("[data-polaris-collapsible-trigger]")
          if (trigger) {
            trigger.dataset.state = state
            trigger.setAttribute("aria-expanded", String(this._open))
          }
          const content = this.el.querySelector("[data-polaris-collapsible-content]")
          if (content) {
            content.dataset.state = state
          }
        }
      }
    </script>
    """
  end
end
