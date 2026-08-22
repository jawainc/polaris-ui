defmodule PolarisUI.Components.CollapsibleAlert do
  @moduledoc """
  The Polaris collapsible alert: an alert-styled callout whose detail section
  expands and collapses behind a 26px icon-only toggle.

  Port of the Supabase design system fragment
  `ui-patterns/collapsible-alert` (a Radix Collapsible inside an
  `alertVariants` container): use it when the disclosure itself is a callout —
  the summary (`trigger`) stays visible while optional detail expands beneath
  it. For non-expandable product callouts use `PolarisUI.Components.Admonition`
  instead; for generic reveal/hide outside an alert context, compose a plain
  collapsible.

  ## Anatomy

      <.collapsible_alert id="connection-help" trigger="Need help?">
        <p>Try a different browser or disable extensions that block network requests.</p>
      </.collapsible_alert>

    * **root** — the alert chrome per `variant`, tightened to `p-3` (the
      plain alert's `p-4` is too roomy for a disclosure header).
    * **trigger** — the always-visible `font-medium` summary label.
    * **toggle** — a 26×26 outline icon button (the `<.button>` composition)
      whose chevron rotates 180° over 200ms while open.
    * **inner block** — the collapsible detail, `pt-3` under the header and
      removed from the document entirely while closed (the `hidden`
      attribute, matching the Radix unmount semantics).

  ## Variants

  The same three as the Supabase Alert: `default` (neutral surface),
  `destructive` (red tint), and `warning` (amber tint) — tinted translucent
  fills with visible matching borders, per the dark-first contrast rules.

  ## States and behavior

  Open state is client-side and uncontrolled, exactly like the Radix
  original: the colocated runtime hook toggles `data-state` between
  `"open"`/`"closed"` on the root, trigger, and content, flips
  `aria-expanded`, and hides the detail with `hidden` — no server round
  trip, and `default_open` only sets the initial state. After a LiveView
  patch the hook re-applies the client's current state, so re-renders never
  snap the disclosure shut.

  The interactive state machine — rest, hover, `:focus-visible` ring,
  active, disabled — lives on the toggle button and is inherited from
  `<.button>` (`variant="outline"`, `size="tiny"`). There is no disabled
  mode for the disclosure itself: a callout that cannot be opened is dead
  copy — write the message into an admonition instead.

  ## Accessibility

    * The toggle is a real `<button type="button">` with `aria-expanded`
      and `aria-controls` (wired to the content id), keyboard operable via
      Enter/Space, and carrying `aria-label="Toggle"` because it is
      icon-only.
    * The root is a passive `<div>` — the Supabase fragment deliberately
      does not set `role="alert"` on a disclosure; reach for the
      admonition when you need a live region.
    * The chevron glyph is `aria-hidden` decoration; the `trigger` label
      and the expanded content carry the semantics.

  ## Microcopy

  Per the Supabase copywriting guidelines, triggers are terse sentence-case
  labels ("Need help?", "Details", "Warning") and the expanded copy says
  what happened and what to do next — never filler.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  import PolarisUI.Components.Button, only: [button: 1]

  @variants ~w(default destructive warning)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the disclosure root — required because the colocated hook
    that manages open/close state anchors on it (LiveView hooks need an id).
    The collapsible content id derives from it as `"<id>-content"` and is
    referenced by the toggle's `aria-controls`.
    """
  )

  attr(:trigger, :string,
    required: true,
    doc: "The always-visible summary label (e.g. \"Need help?\", \"Details\")."
  )

  attr(:variant, :string,
    values: @variants,
    default: "default",
    doc: """
    Visual treatment: `default` is the neutral surface workhorse,
    `destructive` tints red for failed/irreversible situations, `warning`
    tints amber for recoverable ones.
    """
  )

  attr(:default_open, :boolean,
    default: false,
    doc: "Start expanded instead of collapsed (initial state only — state is client-side)."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged last — caller classes win conflicts via `cn/1`."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the root `<div>`: `data-*`, `phx-*`, … (a caller `id` in
    `rest` is ignored in favor of the required `id` attribute).
    """
  )

  slot(:inner_block,
    required: true,
    doc: "The collapsible detail. Wrap paragraphs in `<p>` yourself."
  )

  def collapsible_alert(assigns) do
    validate_in!(:variant, assigns.variant, @variants)

    state = if assigns.default_open, do: "open", else: "closed"

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Toggle",
        state: state,
        content_id: "#{assigns.id}-content",
        root_classes:
          cn([
            "relative w-full rounded-lg border p-3 text-sm",
            "text-content-primary",
            variant_classes(assigns.variant),
            assigns.class
          ])
      )

    ~H"""
    <div id={@id} class={@root_classes} data-state={@state} phx-hook={@hook} {@rest}>
      <div class="flex items-center justify-between gap-2">
        <span class="font-medium" data-polaris-collapsible-label>{@trigger}</span>
        <.button
          type="button"
          variant="outline"
          size="tiny"
          class="w-[26px] [&[data-state=open]_svg]:rotate-180"
          aria-label="Toggle"
          aria-expanded={to_string(@state == "open")}
          aria-controls={@content_id}
          data-state={@state}
          data-polaris-collapsible-trigger
        >
          <:icon>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="transition-transform duration-200"
              aria-hidden="true"
            >
              <path d="m6 9 6 6 6-6" />
            </svg>
          </:icon>
        </.button>
      </div>
      <div
        id={@content_id}
        class="pt-3"
        data-state={@state}
        hidden={not @default_open}
        data-polaris-collapsible-content
      >
        {render_slot(@inner_block)}
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
              if (open) {
                content.removeAttribute("hidden")
              } else {
                content.setAttribute("hidden", "")
              }
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
          // A LiveView patch resets the server-rendered data-state/hidden to
          // the initial defaults; restore the client's current state.
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

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end

  # Tinted translucent fills with visible borders, mirroring the Supabase
  # alertVariants reused by the fragment (bg-surface-200/25 border-default,
  # destructive-200/400, warning-200/400) mapped onto Polaris tokens.
  defp variant_classes("default"), do: "border-surface-border bg-surface-panel/40"
  defp variant_classes("destructive"), do: "border-danger-border bg-danger-muted"
  defp variant_classes("warning"), do: "border-warning-border bg-warning-muted"
end
