defmodule PolarisUI.Components.Dialog do
  @moduledoc """
  The Polaris dialog: a generic modal for bespoke layouts — the port of
  the Supabase design system Dialog (`packages/ui`, built on the Radix
  Dialog primitive), the raw rung of the Supabase modality ladder.

  Unlike the AlertDialog (a critical decision that cannot be dismissed
  from outside), this dialog is dismissible by design: the ✕ button,
  Escape, and clicking the overlay all push `on_close`, exactly like
  the source's Radix wiring. Reach for the right rung: short critical
  confirmations are the AlertDialog, decision forms the Confirmation
  Modal, typed-intent destructive actions the Text Confirm Dialog, and
  everything else (settings panels, editors, previews) this Dialog.

  ## Anatomy

      <.dialog
        id="edit-profile"
        open={@show_edit}
        title="Edit profile"
        description="Make changes to your profile here. Click save when you're done."
        on_close="close-edit"
      >
        <.dialog_section>
          ...inputs...
        </.dialog_section>
        <.dialog_section_separator />
        <.dialog_section padding="medium">
          ...more...
        </.dialog_section>
        <:footer>
          <.button type="button" phx-click="close-edit" variant="default">Cancel</.button>
          <.button type="button" phx-click="save-profile" variant="primary">Save changes</.button>
        </:footer>
      </.dialog>

    * **header** — title (`text-base font-normal`) plus an optional
      `description` (`text-sm text-content-secondary`, wired to
      `aria-describedby`), laid out by the source's DialogHeader
      (`flex flex-col gap-1.5 text-center sm:text-left`).
    * **body** — the inner block, free-form; compose it from
      `dialog_section`/`dialog_section_separator` for the padded
      full-bleed sections the source ships.
    * **footer** — right-aligned from `sm:` up, stacked on mobile
      (`flex flex-col-reverse`), over a top border — put the cancel
      first and the action after.
    * **✕** — top-right close button (drop it with `hide_close`),
      low-opacity until hover, firing `on_close`.

  ## Visibility and events

  Visibility is server-driven via `open`; the **✕ button**, **Escape**,
  and **overlay clicks** (pushed by the colocated hook) all fire
  `on_close`. Loading states belong to the buttons inside — the dialog
  itself stays open until your server sets `open` back to false, which
  is the LiveView equivalent of the source's controlled `onOpenChange`.

  ## Sizes and padding

  `size` follows the Supabase dialog widths — `tiny`/`small`/`medium`
  (the default, 512px)/`large`/`xlarge`/`xxlarge`/`xxxlarge`. `padding`
  tunes the header/footer rhythm: `small` (the source default:
  `py-4 px-4 md:px-5`) or `medium` (`py-6 px-4 md:px-7`); pass it through
  to `dialog_section` too for consistent section rhythm.

  `centered={false}` anchors the panel near the top instead of the
  viewport middle — the source's top-anchored variant for tall,
  scroll-heavy content.

  ## Accessibility

    * The container renders `role="dialog"` `aria-modal="true"` with
      `aria-labelledby` wired to the title id (`aria-describedby` joins
      the description when present).
    * The hook traps Tab within the panel, focuses the first focusable
      on open, restores focus to the invoking element on close, and
      locks background scroll.

  ## Microcopy

  Per the Supabase copywriting guidelines: the title names the task
  ("Edit profile"), the description states the consequence or guidance
  in one plain sentence, and footer buttons use the specific verb —
  "Save changes", "Revoke access" — never "Submit" or "OK".

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @sizes ~w(tiny small medium large xlarge xxlarge xxxlarge)
  @paddings ~w(small medium)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the dialog root — required because the colocated hook
    that manages focus trapping and dismissal anchors on it. The
    title/description ids derive from it (`"<id>-title"`).
    """
  )

  attr(:open, :boolean,
    default: false,
    doc: "Server-driven visibility. Toggle it from the `on_close` handler."
  )

  attr(:title, :string,
    required: true,
    doc: "Dialog heading — name the task (\"Edit profile\")."
  )

  attr(:description, :string,
    default: nil,
    doc: "One-sentence guidance under the title, wired to aria-describedby."
  )

  attr(:on_close, :string,
    required: true,
    doc: """
    LiveView event fired by every dismiss path — the ✕ button, Escape,
    and overlay clicks (the latter two via the hook's pushEvent).
    """
  )

  attr(:size, :string,
    values: @sizes,
    default: "medium",
    doc: """
    Panel max-width: `tiny` up to `xxxlarge` (80rem). `medium` (512px) is
    the source default.
    """
  )

  attr(:padding, :string,
    values: @paddings,
    default: "small",
    doc: "Header/footer rhythm: `small` (`py-4 px-4 md:px-5`, the source default) or `medium`."
  )

  attr(:centered, :boolean,
    default: true,
    doc: """
    Center the panel in the viewport (the default). `false` anchors it
    near the top — the source's variant for tall, scroll-heavy content.
    """
  )

  attr(:hide_close, :boolean,
    default: false,
    doc: "Drop the built-in ✕ button (e.g. for flows that must use the footer)."
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the content panel — where the source's
    DialogContent `className` lands.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, …")

  slot(:inner_block, doc: "The body — free-form; compose it from `dialog_section` and friends.")

  slot(:footer,
    doc: """
    Footer actions over a top border — cancel first, action after, both
    specific verbs ("Save changes").
    """
  )

  def dialog(assigns) do
    validate_in!(:size, assigns.size, @sizes)
    validate_in!(:padding, assigns.padding, @paddings)

    has_body? = slot_content?(assigns.inner_block, assigns)
    has_footer? = slot_content?(assigns.footer, assigns)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Dialog",
        state: if(assigns.open, do: "open", else: "closed"),
        has_body?: has_body?,
        has_footer?: has_footer?,
        container_classes:
          cn([
            "fixed inset-0 z-50 overflow-y-auto py-8",
            if(assigns.centered,
              do: "grid place-items-center",
              else: "flex flex-col justify-start px-5 pb-8 sm:pt-12 md:pt-20 lg:pt-32 xl:pt-40"
            )
          ]),
        header_classes:
          cn([
            "flex flex-col gap-1.5 text-center sm:text-left",
            padding_classes(assigns.padding)
          ]),
        footer_classes:
          cn([
            "flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2 border-t border-surface-border",
            padding_classes(assigns.padding)
          ]),
        describedby_id: assigns.description && "#{assigns.id}-description"
      )

    ~H"""
    <div
      id={@id}
      class="contents"
      data-state={@state}
      data-close-event={@on_close}
      phx-hook={@hook}
      {@rest}
    >
      <div
        :if={@open}
        data-polaris-dialog-overlay
        aria-hidden="true"
        class="fixed inset-0 z-50 bg-overlay backdrop-blur-xs"
      >
      </div>
      <div :if={@open} data-polaris-dialog-container class={@container_classes}>
        <div
          data-polaris-dialog-panel
          role="dialog"
          aria-modal="true"
          aria-labelledby={"#{@id}-title"}
          aria-describedby={@describedby_id}
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
          <div data-polaris-dialog-header class={@header_classes}>
            <h2
              id={"#{@id}-title"}
              data-polaris-dialog-title
              class="text-base leading-none font-normal max-w-[calc(100%-1.5rem)]"
            >
              {@title}
            </h2>
            <p
              :if={@description}
              id={"#{@id}-description"}
              data-polaris-dialog-description
              class="text-sm text-content-secondary"
            >
              {@description}
            </p>
          </div>
          <div :if={@has_body?} data-polaris-dialog-body>
            {render_slot(@inner_block)}
          </div>
          <div :if={@has_footer?} data-polaris-dialog-footer class={@footer_classes}>
            {render_slot(@footer)}
          </div>
          <button
            :if={not @hide_close}
            type="button"
            data-polaris-dialog-close
            phx-click={@on_close}
            aria-label="Close"
            class={
              cn([
                "absolute p-0.5 right-3.5 top-3.5 rounded-xs opacity-20 transition-opacity",
                "hover:opacity-100 cursor-pointer",
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
                "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
                "disabled:pointer-events-none"
              ])
            }
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
              <path d="M18 6 6 18" />
              <path d="m6 6 12 12" />
            </svg>
          </button>
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
          const container = this.el.querySelector("[data-polaris-dialog-container]")
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
          const container = root.querySelector("[data-polaris-dialog-container]")
          const overlay = root.querySelector("[data-polaris-dialog-overlay]")
          this._onKeydown = (event) => {
            if (event.key === "Escape") {
              event.preventDefault()
              this._close()
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
          // Unlike the alert dialog, an overlay click dismisses — the
          // source's onInteractOutside behavior.
          this._onOverlayClick = (event) => {
            if (event.target === overlay) {
              this._close()
            }
          }
          overlay && overlay.addEventListener("click", this._onOverlayClick)
          // Initial focus lands on the first focusable, then the panel.
          const items = this._focusables()
          const panel = root.querySelector("[data-polaris-dialog-panel]")
          const target = items[0] || panel
          if (target) {
            target.focus()
          }
        },
        _close() {
          const name = this.el.dataset.closeEvent
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
          const overlay = this.el.querySelector("[data-polaris-dialog-overlay]")
          overlay && overlay.removeEventListener("click", this._onOverlayClick)
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

  @doc """
  The dialog section: a padded full-bleed band of body content — the
  source's DialogSection (`overflow-hidden` + the shared padding
  variants). Stack sections separated by `dialog_section_separator`.
  """
  attr(:padding, :string,
    values: @paddings,
    default: "small",
    doc: "`small` (`py-4 px-4 md:px-5`, the source default) or `medium` (`py-6 px-4 md:px-7`)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the section.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, doc: "The section's content.")

  def dialog_section(assigns) do
    validate_in!(:padding, assigns.padding, @paddings)

    ~H"""
    <div
      data-polaris-dialog-section
      class={cn(["overflow-hidden", padding_classes(assigns.padding), @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The dialog section separator: a full-width hairline between sections —
  the source's DialogSectionSeparator (`w-full h-px bg-border`).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the separator.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  def dialog_section_separator(assigns) do
    ~H"""
    <div
      data-polaris-dialog-section-separator
      class={cn(["w-full h-px bg-surface-border", @class])}
      {@rest}
    />
    """
  end

  # The source's DialogPaddingVariants, shared by header, footer, and sections.
  defp padding_classes("small"), do: "py-4 px-4 md:px-5"
  defp padding_classes("medium"), do: "py-6 px-4 md:px-7"

  # Max-widths mirror the Supabase DialogContent size variants.
  defp size_classes("tiny"), do: "sm:w-full sm:max-w-xs"
  defp size_classes("small"), do: "sm:w-full sm:max-w-sm"
  defp size_classes("medium"), do: "sm:w-full sm:max-w-lg"
  defp size_classes("large"), do: "sm:w-full md:max-w-xl"
  defp size_classes("xlarge"), do: "sm:w-full md:max-w-3xl"
  defp size_classes("xxlarge"), do: "sm:w-full md:max-w-6xl"
  defp size_classes("xxxlarge"), do: "sm:w-full md:max-w-7xl"

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
