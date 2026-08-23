defmodule PolarisUI.Components.TextConfirmDialog do
  @moduledoc """
  The Polaris text confirm dialog: a modal dialog that adds a deliberate
  typed-confirmation step for highly destructive actions — the confirm
  button stays disabled until the user types an exact confirmation
  string (usually the resource's name).

  Port of the Supabase design system fragment
  `ui-patterns/Dialogs/TextConfirmModal` (a Dialog wrapper whose
  react-hook-form + zod typed-intent form becomes a server-owned draft
  in LiveView). Pick the right rung of the Supabase modality ladder: a
  short critical confirmation is an Alert Dialog, an extra-context
  confirmation is a Confirmation Modal, a typed-intent destructive
  action is this dialog, and bespoke layouts use the raw Dialog.

  ## Anatomy

      <.text_confirm_dialog
        id="delete-bucket"
        open={@show_delete}
        title="Delete bucket"
        variant="destructive"
        alert_title="This action cannot be undone"
        confirm_string={@bucket_name}
        confirm_placeholder={@bucket_name}
        confirm_value={@confirm_draft}
        confirm_label="Delete bucket"
        on_change="delete-bucket-draft"
        on_confirm="delete-bucket-confirm"
        on_cancel="delete-bucket-cancel"
      >
        <p>Deleting the bucket permanently removes the bucket and all of its contents.</p>
      </.text_confirm_dialog>

    * **header** — `title` (styled `h2`) over a bottom border. There is
      no ghost ✕ close button — the React fragment has none; Escape and
      outside-click dismiss via the colocated hook.
    * **alert** — an optional admonition banner (`alert_title` /
      `alert_description`) sandwiched under the header, tinted by
      `variant`, bleeding to full width like the Supabase `alert` prop.
    * **body** — the inner block (rich context) and/or the older `text`
      paragraph prop, each closed off with a 1px separator. Both may
      render, in that order.
    * **typed-intent form** — the label sentence
      "Type `<confirm_string>` to confirm." (the string selectable, or a
      small copy button with `enable_copy`), the confirmation input, an
      optional `description` hint, and the mismatch error line.
    * **footer** — the button row *inside* the form element, exactly
      like the fragment: a full-width confirm (`type="submit"`, so Enter
      submits), with an optional cancel button before it when
      `block_cancel_button` is `false` (the fragment default hides it).

  ## The LiveView handler contract

  The server owns the typed value — no form state lives on the client
  (the zod resolver becomes a server-side trim + compare computed at
  render):

      def handle_event("delete-bucket-draft", %{"delete-bucket-confirm-value" => value}, socket) do
        {:noreply, assign(socket, :confirm_draft, value)}
      end

      def handle_event("delete-bucket-confirm", %{"delete-bucket-confirm-value" => value}, socket) do
        # Only reachable once the draft trims to a match — the confirm
        # button was disabled until then. Fire the deletion, set
        # loading: true, and close on success.
      end

  The input is named `"<id>-confirm-value"` and pushes `on_change` on
  every edit (`phx-change`, no debounce — the React onChange
  revalidation round-trips instantly); `on_confirm` is the form's
  `phx-submit`, fired by the confirm button and by Enter.

  ## Validation

  `String.trim(confirm_value) == String.trim(confirm_string)` decides
  everything at render time: the confirm button is disabled until the
  trimmed draft matches (or while `loading`), and `mismatch_error`
  renders under the input only when the trimmed draft is non-empty and
  unmatched. Deviation from the fragment: React surfaces the zod
  message after the first submit attempt (`reValidateMode: 'onChange'`
  re-runs it on every change thereafter); the port revalidates on every
  keystroke round-trip, since the draft already lives on the server.

  ## Visibility and events

  Visibility is server-driven via `open` (the LiveView equivalent of the
  React `visible` prop). Every dismiss path means *cancel*: the cancel
  button (when rendered) fires `phx-click={on_cancel}`, while Escape and
  clicking outside the panel are handled by the colocated runtime hook,
  which pushes `on_cancel` — so pass both event names for a fully
  dismissable dialog.

  ## States

    * **loading** — the confirm button shows its spinner + `aria-busy`
      and locks; the cancel button (when rendered) disables too — no
      canceling mid-flight. Drive it from your `handle_event/3` for
      `on_confirm`, exactly like the React controlled `loading` prop.
    * **unmatched** — the confirm button renders disabled; the input
      itself never disables (matching the fragment).
    * **copied** — with `enable_copy`, clicking the string's copy
      button copies `confirm_string` to the clipboard and swaps the icon
      to a check for 2000ms (the hook sets `data-copied` and the icons
      toggle through it).
    * rest / hover / focus-ring / active states come from the composed
      `<.button>` and the input shell.

  ## Variants and sizes

  `variant` tints the confirm button *and* the alert banner: `default` →
  emerald `primary`, `warning` → amber, `destructive` → red. `size`
  follows the Supabase dialog widths — `tiny`/`small` (the default,
  384px)/`medium`/`large`/`xlarge`/`xxlarge`/`xxxlarge`.

  ## Accessibility

    * The dialog container renders `role="dialog"` `aria-modal="true"`
      and `aria-labelledby` wired to the title id. Radix uses
      `role="dialog"` for this fragment — `role="alertdialog"` belongs
      to the Alert Dialog pattern.
    * The input is named by the label sentence: a real
      `<label for="<id>-confirm-value">` (also exposed via
      `aria-labelledby`), so screen readers announce "Type
      profile-pictures to confirm." `aria-describedby` joins the
      `description` hint and the mismatch error when present.
    * The hook traps Tab within the panel, moves initial focus to the
      first focusable control (the input), restores focus to the
      invoking element on close, locks background scroll, and answers
      Escape. The form sets `autocomplete="off"` so browsers never
      resurrect a previous deletion's string.

  ## Microcopy

  Per the Supabase copywriting guidelines: the header and the confirm
  button must match the action ("Delete bucket" / "Delete bucket") —
  the `confirm_label` default of "Submit" exists for React parity and
  must be overridden with the specific verb. `confirm_string` is the
  resource's exact name and `confirm_placeholder` repeats it; the label
  sentence reads "Type `<name>` to confirm." Keep `mismatch_error`
  terse ("Value entered does not match") and `cancel_label`
  non-destructive ("Cancel", never "Discard").

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
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
    Unique id for the dialog root — required because the colocated hook
    that manages focus trapping, Escape, outside clicks, and the copy
    button anchors on it. The label/input ids derive from it
    (`"<id>-label"` / `"<id>-confirm-value"`).
    """
  )

  attr(:open, :boolean,
    default: false,
    doc: "Server-driven visibility. Toggle it from the `on_confirm`/`on_cancel` handlers."
  )

  attr(:title, :string,
    required: true,
    doc: "Dialog heading — phrase it as the action (\"Delete bucket\")."
  )

  attr(:confirm_string, :string,
    required: true,
    doc: """
    The exact text the user must type to unlock the confirm button —
    usually the resource's name (e.g. the project ref). Trimmed before
    comparing, like the fragment's zod `z.literal(confirmString.trim())`.
    """
  )

  attr(:confirm_placeholder, :string, required: true, doc: "Placeholder for the input.")

  attr(:confirm_value, :string,
    default: "",
    doc: """
    The current typed draft, owned by the caller's LiveView. The input
    renders it and every edit pushes `on_change`; the value arrives
    under the `"<id>-confirm-value"` key. Keep it in socket state — the
    component never mutates it.
    """
  )

  attr(:on_change, :string,
    default: nil,
    doc: "LiveView event for input edits (phx-change; store the draft server-side)."
  )

  attr(:on_confirm, :string,
    default: nil,
    doc: """
    LiveView event fired by submitting the form (phx-submit) — the
    confirm button and Enter both submit; only reachable once the draft
    matches.
    """
  )

  attr(:on_cancel, :string,
    default: nil,
    doc: """
    LiveView event fired by every dismiss path — cancel button, Escape,
    and outside click (the last two via the hook's pushEvent).
    """
  )

  attr(:text, :string,
    default: nil,
    doc: """
    Older body paragraph prop from before the fragment's refactor —
    rendered as its own separated body section when the inner block
    alone is not enough. Prefer the inner block.
    """
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
    Tints the confirm button and the alert banner: `default` confirms
    with emerald `primary`, `warning` with amber, `destructive` with
    red.
    """
  )

  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc: "Panel max-width: `small` (384px, the default) up to `xxxlarge` (80rem)."
  )

  attr(:loading, :boolean,
    default: false,
    doc: "Confirm shows its spinner and locks; the cancel button disables too."
  )

  attr(:confirm_label, :string,
    default: "Submit",
    doc: """
    Confirm button text — kept for React parity; always override with
    the specific verb ("Delete bucket").
    """
  )

  attr(:cancel_label, :string,
    default: "Cancel",
    doc: "Cancel button text — keep non-destructive."
  )

  attr(:block_cancel_button, :boolean,
    default: true,
    doc: """
    Mirrors the fragment's `blockDeleteButton`: `true` (the default)
    hides the cancel button for a single full-width confirm — the
    deliberate speed-bump presentation; `false` renders cancel and
    confirm side by side.
    """
  )

  attr(:mismatch_error, :string,
    default: "Value entered does not match",
    doc: """
    The FormMessage port: shown under the input when the trimmed draft
    is non-empty and does not match `confirm_string`.
    """
  )

  attr(:enable_copy, :boolean,
    default: false,
    doc: """
    Render `confirm_string` as a small copy button instead of a
    selectable span — for long, hard-to-type refs. Clicking it copies
    the string (via the hook) and shows a check for 2000ms.
    """
  )

  attr(:description, :string,
    default: nil,
    doc: """
    Hint line under the input (the FormDescription port) — e.g. where
    to find the name being asked for. Wired to `aria-describedby`.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the inner-block body section (not the
    panel) — mirroring the sibling modals, where `class` lands on the
    DialogSection.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, …")

  slot(:inner_block,
    doc: "Optional body: the context needed to decide — copy, callouts, small form controls."
  )

  def text_confirm_dialog(assigns) do
    validate_in!(:variant, assigns.variant, @variants)
    validate_in!(:size, assigns.size, @sizes)

    # LV creates an inner_block even when the do-block is empty, so
    # blank-render is the reliable signal for the body section.
    has_body? = slot_content?(assigns.inner_block, assigns)
    show_alert? = not is_nil(assigns.alert_title) or not is_nil(assigns.alert_description)

    # The zod schema port: trim both sides, then compare literally.
    matched? = String.trim(assigns.confirm_value) == String.trim(assigns.confirm_string)
    trimmed_draft = String.trim(assigns.confirm_value)
    show_error? = trimmed_draft != "" and not matched?

    input_describedby =
      [assigns.description && "#{assigns.id}-description", show_error? && "#{assigns.id}-error"]
      |> Enum.filter(&is_binary/1)
      |> Enum.join(" ")

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Modal",
        state: if(assigns.open, do: "open", else: "closed"),
        show_alert?: show_alert?,
        alert_type: @variant_to_alert_type[assigns.variant],
        confirm_variant: confirm_variant(assigns.variant),
        has_body?: has_body?,
        show_error?: show_error?,
        matched?: matched?,
        input_id: "#{assigns.id}-confirm-value",
        input_describedby: if(input_describedby == "", do: nil, else: input_describedby)
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
        data-polaris-tcd-overlay
        aria-hidden="true"
        class="fixed inset-0 z-50 bg-overlay backdrop-blur-[2px]"
      >
      </div>
      <div
        :if={@open}
        data-polaris-tcd-container
        role="dialog"
        aria-modal="true"
        aria-labelledby={"#{@id}-title"}
        class="fixed inset-0 z-50 grid place-items-center overflow-y-auto p-8"
      >
        <div
          data-polaris-tcd-panel
          tabindex="-1"
          class={
            cn([
              "relative block w-full rounded-lg border border-surface-border",
              "bg-surface-panel pb-5 text-content-primary shadow-lg",
              size_classes(@size)
            ])
          }
        >
          <div class="border-b border-surface-border px-4 py-4 md:px-5">
            <h2
              id={"#{@id}-title"}
              class="max-w-[calc(100%-1rem)] text-base font-normal leading-none text-content-primary"
              data-polaris-tcd-title
            >
              {@title}
            </h2>
          </div>
          <.admonition
            :if={@show_alert?}
            type={@alert_type}
            title={@alert_title}
            class="rounded-none border-x-0 -mt-px"
            data-polaris-tcd-alert
          >
            {@alert_description}
          </.admonition>
          <div
            :if={@has_body?}
            data-polaris-tcd-body
            class={cn(["overflow-hidden px-4 py-4 md:px-5", @class])}
          >
            {render_slot(@inner_block)}
          </div>
          <div :if={@has_body?} class="h-px w-full bg-surface-border" data-polaris-tcd-separator>
          </div>
          <div :if={not is_nil(@text)} data-polaris-tcd-body class="px-4 py-4 md:px-5">
            <p class="text-sm text-content-secondary">{@text}</p>
          </div>
          <div
            :if={not is_nil(@text)}
            class="h-px w-full bg-surface-border"
            data-polaris-tcd-separator
          >
          </div>
          <form
            data-polaris-tcd-form
            autocomplete="off"
            phx-submit={@on_confirm}
            class="px-5 flex flex-col gap-y-3 pt-3"
          >
            <div class="flex flex-col gap-y-2">
              <label
                for={@input_id}
                id={"#{@id}-label"}
                class="text-sm text-content-primary"
                data-polaris-tcd-label
              >
                Type
                <button
                  :if={@enable_copy}
                  type="button"
                  data-polaris-tcd-copy
                  data-copy-value={@confirm_string}
                  data-copied="false"
                  class={
                    cn([
                      "group inline-flex cursor-pointer select-none items-center justify-center gap-2",
                      "rounded-md border border-surface-border bg-surface-panel text-left",
                      "h-[23px] px-1.5 py-0 text-sm text-content-primary",
                      "whitespace-pre break-all transition-colors ease-out duration-200",
                      "hover:bg-surface-panel-hover hover:border-surface-border-hover",
                      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
                      "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
                    ])
                  }
                >
                  {@confirm_string}
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="size-3.5 shrink-0 group-data-[copied=true]:hidden"
                    aria-hidden="true"
                  >
                    <rect width="14" height="14" x="8" y="8" rx="2" ry="2" />
                    <path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" />
                  </svg>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="hidden size-3.5 shrink-0 text-brand-accent group-data-[copied=true]:block"
                    aria-hidden="true"
                  >
                    <path d="M20 6 9 17l-5-5" />
                  </svg>
                </button>
                <span :if={not @enable_copy} class="text-content-primary break-all whitespace-pre">
                  {@confirm_string}
                </span>
                to confirm.
              </label>
              <input
                type="text"
                id={@input_id}
                name={@input_id}
                value={@confirm_value}
                placeholder={@confirm_placeholder}
                autocomplete="off"
                phx-change={@on_change}
                aria-labelledby={"#{@id}-label"}
                aria-describedby={@input_describedby}
                data-polaris-tcd-input
                class={
                  cn([
                    "h-[34px] w-full rounded-md border border-surface-border bg-surface-panel",
                    "px-2.5 text-sm text-content-primary transition-colors",
                    "hover:border-surface-border-hover focus:border-surface-border-hover",
                    "focus:outline-none focus:ring-2 focus:ring-brand-emerald",
                    "focus:ring-offset-2 focus:ring-offset-surface-ground"
                  ])
                }
              />
              <p :if={@description} id={"#{@id}-description"} class="text-xs text-content-secondary">
                {@description}
              </p>
              <p
                :if={@show_error?}
                id={"#{@id}-error"}
                class="text-xs text-danger"
                data-polaris-tcd-error
              >
                {@mismatch_error}
              </p>
            </div>
            <div class="flex gap-2" data-polaris-tcd-footer>
              <.button
                :if={not @block_cancel_button}
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
                type="submit"
                variant={@confirm_variant}
                size="medium"
                class="w-full truncate"
                loading={@loading}
                disabled={not @matched?}
              >
                {@confirm_label}
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Modal" runtime>
      {
        mounted() {
          this._active = false
          this._copyTimer = null
          this._sync()
          this._onCopyClick = (event) => {
            const target = event.target
            if (!target || typeof target.closest !== "function") return
            const el = target.closest("[data-polaris-tcd-copy]")
            if (!el) return
            if (navigator.clipboard && navigator.clipboard.writeText) {
              navigator.clipboard.writeText(el.dataset.copyValue)
            }
            el.setAttribute("data-copied", "true")
            if (this._copyTimer) clearTimeout(this._copyTimer)
            this._copyTimer = setTimeout(() => el.setAttribute("data-copied", "false"), 2000)
          }
          this.el.addEventListener("click", this._onCopyClick)
        },
        updated() {
          this._sync()
        },
        destroyed() {
          this._release()
          if (this._copyTimer) clearTimeout(this._copyTimer)
          this.el.removeEventListener("click", this._onCopyClick)
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
          const container = this.el.querySelector("[data-polaris-tcd-container]")
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
          const container = root.querySelector("[data-polaris-tcd-container]")
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
              const panel = root.querySelector("[data-polaris-tcd-panel]")
              if (panel && !panel.contains(event.target)) {
                this._cancel()
              }
            }
            container.addEventListener("click", this._onContainerClick)
          }
          const items = this._focusables()
          const panel = root.querySelector("[data-polaris-tcd-panel]")
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
          const container = root && root.querySelector("[data-polaris-tcd-container]")
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
