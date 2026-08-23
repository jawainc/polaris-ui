defmodule PolarisUI.Components.AlertDialog do
  @moduledoc """
  The Polaris alert dialog: a modal dialog for critical confirmations and
  acknowledgements that require an explicit user decision.

  Port of the Supabase design system AlertDialog (`packages/ui`, built on
  the Radix AlertDialog primitive). Unlike a generic dialog, an alert
  dialog **cannot be dismissed by clicking outside** and renders no ✕
  button — the user must confirm, cancel, or press Escape. The enforced
  decision prevents accidental dismissal of critical warnings or
  destructive actions.

  Pick the right rung of the Supabase modality ladder: a short critical
  confirmation (title + one paragraph + buttons) is this component; a
  decision needing explanatory copy, callouts, or small form controls is
  the Confirmation Modal; typed-intent destructive actions use the Text
  Confirm Dialog; bespoke layouts the raw Dialog.

  ## Anatomy

      <.alert_dialog
        id="delete-function"
        open={@show_delete}
        title="Delete hello-world?"
        description="This action cannot be undone. Ensure you have a backup in case you want to restore this edge function."
        variant="destructive"
        action_label="Delete"
        on_confirm="delete-function"
        on_cancel="close-delete"
      />

    * **title** — a full-bleed header bar over its own bottom border
      (`text-base border-b px-5 py-3`), phrase it as the action or a
      short question ("Delete hello-world?").
    * **description** — one plain-paragraph consequence statement
      (`text-sm px-5 pt-3.5 pb-4`), wired to `aria-describedby`. Must not
      contain block-level content — richer explanations belong in the
      Confirmation Modal.
    * **body** — the optional inner block for inline feedback: an
      `<.admonition>` (kept full-bleed via the body's flattening
      selectors, taking over the footer's separator) rendered when an
      async action fails, exactly like the source's `AlertDialogBody`.
    * **footer** — cancel first, action after (`flex-col-reverse` stacks
      the action above the cancel on mobile, a right-aligned row from
      `sm:` up), over a top border. Cancel is the neutral `default`
      button; the action tints per `variant`. Omit `action_label` for
      acknowledgement-only dialogs (a single "Close" cancel, like the
      source's close-only pattern — relabel via `cancel_label`).

  ## Visibility, events, and loading

  Visibility is server-driven via `open`. The **cancel button** and
  **Escape** (pushed by the colocated hook) fire `on_cancel`. There is
  no ✕ and no outside-click dismissal — by design.

  `loading` mirrors the source's async machinery: the action button
  spins with `action_label_loading` (the gerund — "Deleting"), both
  buttons lock, and the hook refuses to push Escape while loading, so a
  pending decision cannot be walked away from mid-flight. Drive it from
  your `handle_event/3` for `on_confirm`; the dialog closes only when
  your server sets `open` back to false, and failures stay open with the
  error rendered into the body — the LiveView equivalent of the source's
  rejected-promise behavior.

  Initial focus lands on the **cancel button** (the Radix safety
  default), so Enter never confirms anything destructive accidentally.

  ## Variants and sizes

  `variant` tints only the action button: `default` → emerald `primary`,
  `warning` → amber, `destructive` → red. Buttons render at the `tiny`
  26px size, exactly like the source. `size` follows the Supabase dialog
  widths — `tiny`/`small` (the default, 384px)/`medium`/`large`/
  `xlarge`/`xxlarge`/`xxxlarge`.

  ## Accessibility

    * The container renders `role="alertdialog"` `aria-modal="true"` with
      `aria-labelledby` wired to the title id (`aria-describedby` joins
      the description when present).
    * The hook traps Tab within the panel, focuses the cancel button on
      open, restores focus to the invoking element on close, and locks
      background scroll.

  ## Microcopy

  Per the Supabase copywriting guidelines: state consequences plainly in
  the description ("This action cannot be undone."), use active voice
  ("Deleting this project will remove all data"), and match the action
  button to the specific verb — "Delete", "Create keys", "Revoke access"
  — never "Submit" or "OK". Loading labels gerundize: "Delete project"
  becomes "Deleting project". Keep `cancel_label` non-destructive
  ("Cancel"; "Close" for acknowledgements).

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  import PolarisUI.Components.Button, only: [button: 1]

  @variants ~w(default warning destructive)
  @sizes ~w(tiny small medium large xlarge xxlarge xxxlarge)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the dialog root — required because the colocated hook that
    manages focus trapping and Escape anchors on it. The title/description
    ids derive from it (`"<id>-title"`).
    """
  )

  attr(:open, :boolean,
    default: false,
    doc: "Server-driven visibility. Toggle it from the `on_confirm`/`on_cancel` handlers."
  )

  attr(:title, :string,
    required: true,
    doc: "Dialog heading — the action or a short question (\"Delete hello-world?\")."
  )

  attr(:description, :string,
    default: nil,
    doc: """
    Single-paragraph consequence statement, wired to aria-describedby. No
    block-level content — richer explanations belong in the Confirmation Modal.
    """
  )

  attr(:variant, :string,
    values: @variants,
    default: "default",
    doc: """
    Tints the action button: `default` confirms with emerald `primary`,
    `warning` with amber, `destructive` with red.
    """
  )

  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc: "Panel max-width: `small` (384px, the default) up to `xxxlarge` (80rem)."
  )

  attr(:loading, :boolean,
    default: false,
    doc: """
    Action spins with `action_label_loading`, both buttons lock, and Escape
    stops dismissing — mirrors the source's pending async action.
    """
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Locks the action button independent of loading."
  )

  attr(:action_label, :string,
    default: nil,
    doc: """
    Confirm button text — always the specific verb ("Delete"). Omit for
    acknowledgement-only dialogs (footer renders the cancel button alone).
    """
  )

  attr(:action_label_loading, :string,
    default: nil,
    doc: "Confirm text while loading (the gerund — \"Deleting\"); falls back to action_label."
  )

  attr(:cancel_label, :string,
    default: "Cancel",
    doc: "Cancel button text — keep non-destructive (\"Close\" for acknowledgements)."
  )

  attr(:on_confirm, :string,
    default: nil,
    doc: "LiveView event fired by the action button (phx-click)."
  )

  attr(:on_cancel, :string,
    default: nil,
    doc: """
    LiveView event fired by every dismiss path — the cancel button and
    Escape (the latter via the hook's pushEvent).
    """
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the content panel — where the source's
    AlertDialogContent `className` lands.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, …")

  slot(:inner_block,
    doc: """
    Optional body for inline feedback — e.g. an `<.admonition type="destructive">`
    rendered into it when an async action fails.
    """
  )

  def alert_dialog(assigns) do
    validate_in!(:variant, assigns.variant, @variants)
    validate_in!(:size, assigns.size, @sizes)

    # LV creates an inner_block even when the do-block is empty, so
    # blank-render is the reliable signal for the body section.
    has_body? = slot_content?(assigns.inner_block, assigns)
    state = if assigns.open, do: "open", else: "closed"

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Dialog",
        state: state,
        confirm_variant: confirm_variant(assigns.variant),
        action_text:
          if(assigns.loading and assigns.action_label_loading,
            do: assigns.action_label_loading,
            else: assigns.action_label
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
      data-loading={to_string(@loading)}
      phx-hook={@hook}
      {@rest}
    >
      <div
        :if={@open}
        data-polaris-alert-dialog-overlay
        aria-hidden="true"
        class="fixed inset-0 z-50 bg-overlay backdrop-blur-xs"
      >
      </div>
      <div
        :if={@open}
        data-polaris-alert-dialog-container
        role="alertdialog"
        aria-modal="true"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={@describedby_id}
        class="fixed inset-0 z-50 grid place-items-center overflow-y-auto py-8"
      >
        <div
          data-polaris-alert-dialog-panel
          tabindex="-1"
          class={
            cn([
              "relative z-50 w-full border shadow-md sm:rounded-lg",
              "bg-surface-panel text-content-primary",
              size_classes(@size),
              assigns.class
            ])
          }
        >
          <h2
            id={"#{@id}-title"}
            class="border-b border-surface-border px-5 py-3 text-base text-content-primary"
            data-polaris-alert-dialog-title
          >
            {@title}
          </h2>
          <p
            :if={@description}
            id={"#{@id}-description"}
            class="px-5 pb-4 pt-3.5 text-sm text-content-secondary"
            data-polaris-alert-dialog-description
          >
            {@description}
          </p>
          <div
            :if={@has_body?}
            data-polaris-alert-dialog-body
            class="[&>[role=alert]]:mb-0 [&>[role=alert]]:rounded-none [&>[role=alert]]:border-x-0"
          >
            {render_slot(@inner_block)}
          </div>
          <div
            data-polaris-alert-dialog-footer
            class={
              cn([
                "flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2 border-t border-surface-border py-3 px-5",
                # A full-bleed alert in the body owns the visual separator
                # above the footer (the source's :has() selector, verbatim).
                "[[data-polaris-alert-dialog-body]:has(>[role=alert])+&]:border-t-0"
              ])
            }
          >
            <.button
              type="button"
              variant="default"
              size="tiny"
              class="mt-2 sm:mt-0"
              disabled={@loading}
              phx-click={@on_cancel}
              data-polaris-alert-dialog-cancel
            >
              {@cancel_label}
            </.button>
            <.button
              :if={@action_label}
              type="button"
              variant={@confirm_variant}
              size="tiny"
              class="w-full sm:w-auto"
              loading={@loading}
              disabled={@disabled}
              phx-click={@on_confirm}
              data-polaris-alert-dialog-action
            >
              {@action_text}
            </.button>
          </div>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Dialog" runtime>
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
          const container = this.el.querySelector("[data-polaris-alert-dialog-container]")
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
          const container = root.querySelector("[data-polaris-alert-dialog-container]")
          this._onKeydown = (event) => {
            if (event.key === "Escape") {
              // A pending action cannot be walked away from mid-flight.
              if (root.dataset.loading === "true") {
                event.preventDefault()
                return
              }
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
          // No outside-click dismissal: an alert dialog demands an explicit
          // decision (Radix preventDefault on interact-outside).
          // Initial focus lands on the cancel button — the Radix safety
          // default — falling back to the first focusable, then the panel.
          const cancel = root.querySelector("[data-polaris-alert-dialog-cancel]")
          const items = this._focusables()
          const panel = root.querySelector("[data-polaris-alert-dialog-panel]")
          const target = cancel || items[0] || panel
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

  # Max-widths mirror the Supabase AlertDialogContent size variants.
  defp size_classes("tiny"), do: "sm:max-w-xs"
  defp size_classes("small"), do: "sm:max-w-sm"
  defp size_classes("medium"), do: "sm:max-w-lg"
  defp size_classes("large"), do: "md:max-w-xl"
  defp size_classes("xlarge"), do: "md:max-w-3xl"
  defp size_classes("xxlarge"), do: "md:max-w-6xl"
  defp size_classes("xxxlarge"), do: "md:max-w-7xl"
end
