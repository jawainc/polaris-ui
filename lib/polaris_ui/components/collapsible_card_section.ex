defmodule PolarisUI.Components.CollapsibleCardSection do
  @moduledoc """
  The Polaris collapsible card section: a mono-uppercase disclosure trigger
  for progressively hiding optional or advanced fields inside a card or panel
  form.

  Port of the Supabase design system fragment
  `ui-patterns/CollapsibleCardSection`: the trigger is styled like a card
  section heading (`font-mono uppercase tracking-widest text-xs`), the
  chevron rotates 90° while open, and the content animates its height in and
  out over 100ms. The card chrome itself is the caller's responsibility —
  wrap it in your panel (e.g. `border rounded-lg px-6 py-4`), exactly like
  the Supabase demo.

  ## Anatomy

      <.collapsible_card_section
        id="advanced-settings"
        title="Advanced settings"
        description="These settings cannot be changed after creation"
      >
        <!-- fields -->
      </.collapsible_card_section>

    * **trigger** — the mono-uppercase heading-as-button: muted at rest,
      brighter on hover and while open, with a trailing chevron.
    * **description** — an optional short qualifier under the heading that
      only renders while expanded. Use it only when the content needs
      context the title alone doesn't provide.
    * **inner block** — the disclosed fields.

  ## States and behavior

  Open state is client-side and uncontrolled (like the Radix original): the
  colocated runtime hook toggles `data-state` between `"open"`/`"closed"`
  on the root, trigger, and content with no server round trip;
  `default_open` only sets the initial state, and the hook re-applies the
  client's state after LiveView patches so re-renders never snap the
  section shut.

  The height animation uses the CSS grid-rows technique (animated
  `grid-template-rows: 0fr → 1fr` over `duration-100 ease-out`, matching
  the Supabase `collapsible-down`/`collapsible-up` keyframes) and
  `visibility` so collapsed content drops out of the tab order and the
  accessibility tree at the end of the close transition.

  Unlike the Supabase original, the trigger carries a visible
  `:focus-visible` ring — the design system's accessibility rules require a
  shared focus indicator, and the fragment simply omits one.

  ## Accessibility

    * The trigger is a real `<button type="button">` with `aria-expanded`
      and `aria-controls`; it is keyboard operable via Enter/Space.
    * The "heading" is purely visual — never a heading element — so the
      card's own heading outline stays intact.
    * The chevron glyph is `aria-hidden` decoration.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the disclosure root — required because the colocated hook
    that manages open/close state anchors on it. The trigger and content ids
    derive from it as `"<id>-trigger"` / `"<id>-content"`.
    """
  )

  attr(:title, :string,
    required: true,
    doc: "The mono-uppercase section heading (e.g. \"Advanced settings\")."
  )

  attr(:description, :string,
    default: nil,
    doc: """
    Optional short qualifier rendered under the heading while expanded —
    only when the content needs context the title alone doesn't provide.
    """
  )

  attr(:default_open, :boolean,
    default: false,
    doc: "Start expanded instead of collapsed (initial state only — state is client-side)."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root — caller classes win conflicts via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The disclosed fields/content.")

  def collapsible_card_section(assigns) do
    state = if assigns.default_open, do: "open", else: "closed"

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Toggle",
        state: state,
        content_id: "#{assigns.id}-content",
        root_classes: cn(["relative", assigns.class])
      )

    ~H"""
    <div id={@id} class={@root_classes} data-state={@state} phx-hook={@hook} {@rest}>
      <button
        type="button"
        id={"#{@id}-trigger"}
        class="group/trigger flex items-center gap-1 rounded-sm font-mono text-xs uppercase tracking-widest text-content-muted transition hover:text-content-secondary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground data-[state=open]:text-content-secondary"
        aria-expanded={to_string(@state == "open")}
        aria-controls={@content_id}
        data-state={@state}
        data-polaris-collapsible-trigger
      >
        {@title}
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="mr-2 size-4 transition group-hover/trigger:text-content-secondary group-data-[state=open]/trigger:rotate-90"
          aria-hidden="true"
        >
          <path d="m9 18 6-6-6-6" />
        </svg>
      </button>
      <div
        id={@content_id}
        class="grid grid-rows-[0fr] [overflow-y:clip] pb-px invisible transition-[grid-template-rows,visibility] duration-100 ease-out data-[state=open]:grid-rows-[1fr] data-[state=open]:visible"
        data-state={@state}
        data-polaris-collapsible-content
      >
        <%!-- pt-2 lives inside the collapsing row so it animates away too;
             pb-px + overflow-y:clip keep child borders from being clipped. --%>
        <div class="min-h-0 overflow-hidden pt-2">
          <p :if={@description} class="mb-6 text-xs text-content-muted" data-polaris-description>
            {@description}
          </p>
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Toggle" runtime>
      {
        mounted() {
          const root = this.el
          this._open = root.dataset.state === "open"
          this._apply = (open) => {
            this._open = open
            root.dataset.state = open ? "open" : "closed"
            const content = root.querySelector("[data-polaris-collapsible-content]")
            if (content) {
              content.dataset.state = open ? "open" : "closed"
            }
            root.querySelectorAll("[data-polaris-collapsible-trigger]").forEach((trigger) => {
              trigger.dataset.state = open ? "open" : "closed"
              trigger.setAttribute("aria-expanded", String(open))
            })
          }
          // Delegated on the root so the listener survives any child re-patch.
          this._onClick = (event) => {
            const trigger = event.target.closest("[data-polaris-collapsible-trigger]")
            if (trigger && root.contains(trigger)) {
              event.preventDefault()
              this._apply(!this._open)
            }
          }
          root.addEventListener("click", this._onClick)
        },
        updated() {
          // A LiveView patch resets the server-rendered data-state to the
          // initial default; restore the client's current state.
          if (this._apply) {
            this._apply(this._open)
          }
        },
        destroyed() {
          if (this.el && this._onClick) {
            this.el.removeEventListener("click", this._onClick)
          }
        }
      }
    </script>
    """
  end
end
