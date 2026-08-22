defmodule PolarisUI.Components.ConfirmationModal do
  @moduledoc """
  The Polaris confirmation modal: a modal dialog for confirmations that
  need extra context beyond a single paragraph — explanatory copy, a
  callout, or small form elements.

  Port of the Supabase design system fragment
  `ui-patterns/Dialogs/ConfirmationModal` (a convenience wrapper over the
  Dialog primitive with a prop-driven confirmation pattern). Pick the right
  rung of the Supabase modality ladder: a short critical confirmation is an
  Alert Dialog, a typed-intent destructive action is a Text Confirm Dialog,
  and this modal sits between them; bespoke layouts use the raw Dialog.

  ## Anatomy

      <.confirmation_modal
        id="resume-project"
        open={@show_resume}
        title="Resume this project"
        description="The project will be restored to its previous state."
        confirm_label="Resume"
        confirm_label_loading="Resuming"
        on_confirm="resume-project"
        on_cancel="close-resume"
      />

    * **header** — `title` (styled `h2`) and optional `description` over a
      bottom border, with a ghost close ✕ at the top-right corner.
    * **alert** — an optional admonition banner (`alert_title` /
      `alert_description`) sandwiched under the header, tinted by `variant`,
      bleeding to full width like the Supabase `alert` prop.
    * **inner block** — the optional body (context, small form controls),
      closed off with a 1px separator.
    * **footer** — two equal-width buttons: cancel first (`variant="default"`),
      confirm after — `primary`, `warning`, or `danger` per `variant`.

  ## Visibility and events

  Visibility is server-driven via `open` (the LiveView equivalent of the
  React `visible` prop). Every dismiss path means *cancel*:

    * the **cancel button** and the **✕ button** fire `phx-click={on_cancel}`,
    * **Escape** and **clicking outside the panel** are handled by the
      colocated runtime hook, which pushes `on_cancel` — so pass both event
      names for a fully dismissable modal.

  ## States

    * **loading** — the confirm button shows its spinner + `aria-busy`,
      swaps to `confirm_label_loading`, and locks; the cancel button
      disables (no canceling mid-flight). Drive it from your
      `handle_event/3` for `on_confirm`, exactly like the React controlled
      `loading` prop — the modal never sets it itself.
    * **disabled** — locks the confirm button independently of loading.
    * rest / hover / focus-ring / active states come from the composed
      `<.button>`.

  ## Variants and sizes

  `variant` tints the confirm button *and* the alert banner: `default` →
  emerald `primary`, `warning` → amber, `destructive` → red. `size` follows
  the Supabase dialog widths — `tiny`/`small` (the default, 384px)/
  `medium`/`large`/`xlarge`/`xxlarge`/`xxxlarge`.

  ## Accessibility

    * The dialog container renders `role="dialog"` `aria-modal="true"` and
      `aria-labelledby` wired to the title id (`aria-describedby` joins the
      description when present). Radix uses `role="dialog"` for this
      fragment — `role="alertdialog"` belongs to the Alert Dialog pattern.
    * The hook traps Tab within the panel, moves initial focus to the first
      focusable control, restores focus to the invoking element on close,
      locks background scroll, and answers Escape.
    * The ✕ carries an `sr-only` "Close" label.

  ## Microcopy

  Per the Supabase copywriting guidelines the header and the confirm button
  must match the action and flow from the entry point — "Resume this
  project" / "Resume" ("Resuming" while loading), "Delete bucket" /
  "Delete bucket". The `confirm_label` default of "Submit" exists for React
  parity; always override it with the specific verb. Keep `cancel_label`
  non-destructive ("Cancel", never "Discard").

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  import PolarisUI.Components.Button, only: [button: 1]
  import PolarisUI.Components.Admonition, only: [admonition: 1]

  @variants ~w(default destructive warning)
  @sizes ~w(tiny small medium large xlarge xxlarge xxxlarge)

  # Modal variant -> admonition type (mirrors the fragment passing its
  # variant straight into the Admonition).
  @variant_to_alert_type %{
    "default" => "default",
    "destructive" => "destructive",
    "warning" => "warning"
  }

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the modal root — required because the colocated hook that
    manages focus trapping, Escape, and outside clicks anchors on it. The
    title/description ids derive from it (`"<id>-title"`).
    """
  )

  attr(:open, :boolean,
    default: false,
    doc: "Server-driven visibility. Toggle it from the `on_confirm`/`on_cancel` handlers."
  )

  attr(:title, :string,
    required: true,
    doc: "Dialog heading — phrase it as the action (\"Resume this project\")."
  )

  attr(:description, :string,
    default: nil,
    doc: "Optional supporting line under the title; wired to aria-describedby."
  )

  attr(:alert_title, :string,
    default: nil,
    doc: "Title of the optional admonition banner under the header (with `alert_description`)."
  )

  attr(:alert_description, :string,
    default: nil,
    doc: "Body of the optional admonition banner — e.g. \"This action cannot be undone.\""
  )

  attr(:variant, :string,
    values: @variants,
    default: "default",
    doc: """
    Tints the confirm button and the alert banner: `default` confirms with
    emerald `primary`, `warning` with amber, `destructive` with red.
    """
  )

  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc: "Panel max-width: `small` (384px, the default) up to `xxxlarge` (80rem)."
  )

  attr(:loading, :boolean,
    default: false,
    doc: "Confirm shows its spinner + `confirm_label_loading` and both buttons lock."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Locks the confirm button independent of loading."
  )

  attr(:confirm_label, :string,
    default: "Submit",
    doc: "Confirm button text — always override with the specific verb (\"Delete bucket\")."
  )

  attr(:confirm_label_loading, :string,
    default: nil,
    doc: "Confirm text while loading (\"Resuming\"); falls back to confirm_label."
  )

  attr(:cancel_label, :string,
    default: "Cancel",
    doc: "Cancel button text — keep non-destructive."
  )

  attr(:on_confirm, :string,
    default: nil,
    doc: "LiveView event fired by the confirm button (phx-click)."
  )

  attr(:on_cancel, :string,
    default: nil,
    doc: """
    LiveView event fired by every dismiss path — cancel button, ✕ button,
    Escape, and outside click (the last two via the hook's pushEvent).
    """
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the body section (not the panel) —
    mirroring the React fragment, where `className` lands on the DialogSection.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, …")

  slot(:inner_block,
    doc: "Optional body: the context needed to decide — copy, callouts, small form controls."
  )

  def confirmation_modal(assigns) do
    validate_in!(:variant, assigns.variant, @variants)
    validate_in!(:size, assigns.size, @sizes)

    # LV creates an inner_block even when the do-block is empty, so
    # blank-render is the reliable signal for the body section.
    has_body? = slot_content?(assigns.inner_block, assigns)
    show_alert? = not is_nil(assigns.alert_title) or not is_nil(assigns.alert_description)
    state = if assigns.open, do: "open", else: "closed"

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Modal",
        state: state,
        show_alert?: show_alert?,
        alert_type: @variant_to_alert_type[assigns.variant],
        confirm_variant: confirm_variant(assigns.variant),
        confirm_text:
          if(assigns.loading and assigns.confirm_label_loading,
            do: assigns.confirm_label_loading,
            else: assigns.confirm_label
          ),
        has_body?: has_body?,
        describedby_id: assigns.description && "#{assigns.id}-description"
      )

    ~H"""
    <div
      id={@id}
      class="contents"
      data-state={@state}
      data-cancel-event={@on_cancel}
      phx-hook={@hook}
      {@rest}
    >
      <div
        :if={@open}
        data-polaris-modal-overlay
        aria-hidden="true"
        class="fixed inset-0 z-50 bg-overlay backdrop-blur-[2px]"
      >
      </div>
      <div
        :if={@open}
        data-polaris-modal-container
        role="dialog"
        aria-modal="true"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={@describedby_id}
        class="fixed inset-0 z-50 grid place-items-center overflow-y-auto p-8"
      >
        <div
          data-polaris-modal-panel
          tabindex="-1"
          class={
            cn([
              "relative block w-full rounded-lg border border-surface-border",
              "bg-surface-panel pb-5 text-content-primary shadow-lg",
              size_classes(@size)
            ])
          }
        >
          <div class="flex flex-col gap-1.5 border-b border-surface-border px-4 py-4 md:px-5">
            <h2
              id={"#{@id}-title"}
              class="max-w-[calc(100%-1rem)] text-base font-normal leading-none text-content-primary"
              data-polaris-modal-title
            >
              {@title}
            </h2>
            <p
              :if={@description}
              id={"#{@id}-description"}
              class="text-sm text-content-secondary"
              data-polaris-modal-description
            >
              {@description}
            </p>
          </div>
          <button
            type="button"
            phx-click={@on_cancel}
            class="absolute right-3.5 top-3.5 rounded-xs p-0.5 opacity-20 transition-opacity hover:opacity-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald disabled:pointer-events-none"
            aria-label="Close"
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
              <path d="M18 6 6 18" /><path d="m6 6 12 12" />
            </svg>
            <span class="sr-only">Close</span>
          </button>
          <.admonition
            :if={@show_alert?}
            type={@alert_type}
            title={@alert_title}
            class="rounded-none border-x-0 -mt-px"
            data-polaris-modal-alert
          >
            {@alert_description}
          </.admonition>
          <div
            :if={@has_body?}
            data-polaris-modal-body
            class={cn(["overflow-hidden px-4 py-4 md:px-5", @class])}
          >
            {render_slot(@inner_block)}
          </div>
          <div :if={@has_body?} class="h-px w-full bg-surface-border" data-polaris-modal-separator>
          </div>
          <div class="flex gap-2 px-5 pt-5" data-polaris-modal-footer>
            <.button
              type="button"
              variant="default"
              size="medium"
              class="w-full"
              disabled={@loading}
              phx-click={@on_cancel}
            >
              {@cancel_label}
            </.button>
            <.button
              type="button"
              variant={@confirm_variant}
              size="medium"
              class="w-full truncate"
              loading={@loading}
              disabled={@disabled}
              phx-click={@on_confirm}
            >
              {@confirm_text}
            </.button>
          </div>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Modal" runtime>
      {
        mounted() {
          this._active = false
          this._sync()
        },
        updated() {
          this._sync()
        },
        destroyed() {
          this._release()
        },
        _sync() {
          const open = this.el.dataset.state === "open"
          if (open && !this._active) {
            this._trap()
          } else if (!open && this._active) {
            this._release()
          }
        },
        _focusables() {
          const container = this.el.querySelector("[data-polaris-modal-container]")
          if (!container) {
            return []
          }
          return Array.from(
            container.querySelectorAll(
              'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
            )
          ).filter((el) => el.offsetParent !== null)
        },
        _trap() {
          this._active = true
          this._previouslyFocused = document.activeElement
          document.body.style.overflow = "hidden"
          const root = this.el
          const container = root.querySelector("[data-polaris-modal-container]")
          this._onKeydown = (event) => {
            if (event.key === "Escape") {
              event.preventDefault()
              this._cancel()
            } else if (event.key === "Tab") {
              const items = this._focusables()
              if (items.length === 0) {
                event.preventDefault()
                return
              }
              const first = items[0]
              const last = items[items.length - 1]
              if (event.shiftKey && document.activeElement === first) {
                event.preventDefault()
                last.focus()
              } else if (!event.shiftKey && document.activeElement === last) {
                event.preventDefault()
                first.focus()
              } else if (!container.contains(document.activeElement)) {
                event.preventDefault()
                first.focus()
              }
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)
          if (container) {
            this._onContainerClick = (event) => {
              const panel = root.querySelector("[data-polaris-modal-panel]")
              if (panel && !panel.contains(event.target)) {
                this._cancel()
              }
            }
            container.addEventListener("click", this._onContainerClick)
          }
          const items = this._focusables()
          const panel = root.querySelector("[data-polaris-modal-panel]")
          const target = items[0] || panel
          if (target) {
            target.focus()
          }
        },
        _cancel() {
          const name = this.el.dataset.cancelEvent
          if (name && typeof this.pushEvent === "function") {
            this.pushEvent(name)
          }
        },
        _release() {
          if (!this._active) {
            return
          }
          this._active = false
          document.removeEventListener("keydown", this._onKeydown, true)
          const root = this.el
          const container = root && root.querySelector("[data-polaris-modal-container]")
          if (container && this._onContainerClick) {
            container.removeEventListener("click", this._onContainerClick)
          }
          document.body.style.overflow = ""
          if (this._previouslyFocused && typeof this._previouslyFocused.focus === "function") {
            this._previouslyFocused.focus()
          }
          this._previouslyFocused = null
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

  defp confirm_variant("destructive"), do: "danger"
  defp confirm_variant("warning"), do: "warning"
  defp confirm_variant("default"), do: "primary"

  # Max-widths mirror the Supabase DialogContent size variants.
  defp size_classes("tiny"), do: "sm:max-w-xs"
  defp size_classes("small"), do: "sm:max-w-sm"
  defp size_classes("medium"), do: "sm:max-w-lg"
  defp size_classes("large"), do: "md:max-w-xl"
  defp size_classes("xlarge"), do: "md:max-w-3xl"
  defp size_classes("xxlarge"), do: "md:max-w-6xl"
  defp size_classes("xxxlarge"), do: "md:max-w-7xl"
end
