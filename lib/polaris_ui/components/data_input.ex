defmodule PolarisUI.Components.DataInput do
  @moduledoc """
  The Polaris data input: a single-line field for setting, reading, or
  copying a value — the port of the Supabase design system fragment
  `ui-patterns/DataInputs/Input`.

  Use it for values users read as much as type: API keys, connection
  strings, generated tokens. The `<input>` element is both keyboard- and
  mouse-friendly, so it is the right shell for read-only-copyable data;
  for plain form fields prefer the simpler atoms.

  ## Anatomy

      <.data_input
        id="anon-key"
        value={@anon_key}
        readonly
        copy
        class="max-w-sm"
      />

    * **shell** — a `role="group"` wrapper that owns every pixel of chrome:
      the border, panel fill, hover ring, focus ring, error tint, and
      disabled/readonly styling (the Supabase InputGroup pattern).
    * **control** — the inner `<input>`, visually transparent so the shell
      can drive all states through CSS `:has()`.
    * **icon** — an optional leading inline-start addon.
    * **copy / reveal / actions** — the inline-end addon row.

  ## Copy and reveal, only in succession

  Sensitive values can be revealed *and* copied only in succession — while
  the value is masked, only **Reveal** shows; once revealed, **Reveal** is
  gone and **Copy** appears. This reduces on-screen affordances around
  secrets. Reveal is one-way (matching the Supabase behavior); a fresh
  render re-masks.

  Consider whether the value needs to be revealed at all — in most cases
  copying is sufficient. The happy medium for partial disclosure: display a
  pre-masked `value` and copy the real one via `copy_value`.

      <.data_input value="sb_secret_123•••••••" copy_value={@real_secret} readonly copy />

  `copy_value` never renders into the clipboard-visible input — it travels
  as a `data-copy-value` attribute read by the hook at copy time.

  ## States

    * **rest** — panel fill + `border-surface-border`.
    * **hover** — border brightens to `border-surface-border-hover`.
    * **focus-ring** — the shell shows the emerald ring (2px, offset) when
      the inner control receives `:focus-visible`; the control itself stays
      chrome-less so the ring never doubles.
    * **error** — pass `aria-invalid="true"` through the global attributes
      and the shell tints red (`border-danger-border` + `bg-danger-muted`).
    * **disabled** — the control disables; the shell dims its text and
      shows `cursor-not-allowed`.
    * **readonly** — the shell border settles to the button tone, and the
      control text brightens.

  All states are pure CSS driven by the control's own pseudo-classes, so
  they work with zero JavaScript.

  ## Other behavior

    * focusing the control selects the whole value (data fields are
      copied/edited wholesale);
    * password-manager extensions are suppressed on the control (1Password,
      LastPass, Dashlane, Bitwarden) exactly like the Supabase fragment;
    * the **Copy** button label flips to "Copied" for three seconds after a
      successful clipboard write, and `on_copy` (a LiveView event name) is
      pushed after the write succeeds;
    * `show_copy_on_hover` fades the copy button in on shell hover for
      dense layouts.

  ## Sizes

  The Supabase scale: `tiny` 26px, `small` 34px (the default), `medium`
  38px, `large` 42px, `xlarge` 50px.

  ## Accessibility

    * The shell is a labelled group (`role="group"`); give it an
      `aria-label` through global attributes when the input stands alone.
    * Forward `aria-describedby` / `aria-invalid` through the global
      attributes to wire field-level validation from your form layer.
    * The copy/reveal buttons are real buttons carrying the shared
      `<.button>` focus ring.

  The copy/reveal interplay is handled by a colocated *runtime* hook, so it
  works without any JS bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  import PolarisUI.Components.Button, only: [button: 1]

  @sizes ~w(tiny small medium large xlarge)
  @types ~w(text email number search tel url password)

  attr(:id, :string,
    default: nil,
    doc: """
    Id for the shell group — required when `copy` or `reveal` is set (the
    colocated hook anchors on it; LiveView hooks need an id). The inner
    control derives `"<id>-input"` for label wiring.
    """
  )

  attr(:name, :string, default: nil, doc: "The control's `name` attribute.")

  attr(:value, :string, default: nil, doc: "The displayed value (may be pre-masked).")

  attr(:type, :string,
    values: @types,
    default: "text",
    doc: """
    Control type. With `reveal`, the control renders as `password` until
    revealed, then switches to this type.
    """
  )

  attr(:placeholder, :string,
    default: nil,
    doc: """
    Placeholder — partially truncate long read-only values by overriding it
    (the Supabase truncation trick).
    """
  )

  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc:
      "Height/text scale: tiny 26px, small 34px (default), medium 38px, large 42px, xlarge 50px."
  )

  attr(:readonly, :boolean, default: false, doc: "Read-only display of the value.")

  attr(:disabled, :boolean, default: false, doc: "Disables the control and dims the shell.")

  attr(:copy, :boolean, default: false, doc: "Shows the Copy button in the inline-end addon.")

  attr(:copy_value, :string,
    default: nil,
    doc: """
    Clipboard payload when the displayed value is masked — never rendered
    as the control's value; read from `data-copy-value` at copy time.
    """
  )

  attr(:show_copy_on_hover, :boolean,
    default: false,
    doc: "Fades the Copy button in on shell hover (dense layouts)."
  )

  attr(:reveal, :boolean,
    default: false,
    doc: """
    Masks the value as a password behind a one-way Reveal button; Copy
    appears only after revealing.
    """
  )

  attr(:on_copy, :string,
    default: nil,
    doc: "LiveView event pushed after a successful clipboard write."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the shell (e.g. `max-w-sm`)."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the inner `<input>`: `phx-blur`/`phx-change`/`phx-focus`,
    `form`, `autocomplete`, `aria-describedby`, `aria-invalid`, …
    """
  )

  slot(:icon, doc: "Leading inline-start addon (an inline SVG icon).")

  slot(:actions,
    doc: "Extra inline-end addon content (buttons, kbd hints) rendered after copy/reveal."
  )

  def data_input(assigns) do
    validate_in!(:size, assigns.size, @sizes)
    validate_in!(:type, assigns.type, @types)

    needs_hook? = assigns.copy or assigns.reveal

    if needs_hook? and is_nil(assigns.id) do
      raise ArgumentError, """
      PolarisUI data_input: copy/reveal features need an id — the colocated \
      hook that drives them anchors on the shell element, and LiveView hooks \
      require a unique id. Pass id="..." (the control becomes "<id>-input").
      """
    end

    control_id = assigns.id && "#{assigns.id}-input"
    # With reveal, the control starts masked; the real type travels along
    # for the hook to restore on reveal.
    control_type = if assigns.reveal, do: "password", else: assigns.type

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Input",
        needs_hook?: needs_hook?,
        control_id: control_id,
        control_type: control_type,
        shell_classes:
          cn([
            "group relative flex items-center rounded-md border",
            "border-surface-border bg-surface-panel text-sm text-content-primary",
            "transition-colors duration-200",
            "hover:border-surface-border-hover",
            "has-[input:focus-visible]:border-surface-border-hover",
            "has-[input:focus-visible]:outline-none",
            "has-[input:focus-visible]:ring-2 has-[input:focus-visible]:ring-brand-emerald",
            "has-[input:focus-visible]:ring-offset-2 has-[input:focus-visible]:ring-offset-surface-ground",
            "has-[input[aria-invalid=true]]:border-danger-border",
            "has-[input[aria-invalid=true]]:bg-danger-muted",
            "has-[input[aria-invalid=true]]:hover:border-danger",
            "has-[input:disabled]:cursor-not-allowed",
            "has-[input:disabled]:text-content-muted",
            "has-[input:read-only]:border-surface-border",
            assigns.class
          ]),
        control_classes:
          cn([
            "w-full min-w-0 flex-1 bg-transparent text-content-primary",
            "placeholder:text-content-muted read-only:text-content-secondary",
            "focus:outline-none disabled:cursor-not-allowed disabled:text-content-muted",
            size_classes(assigns.size)
          ])
      )

    ~H"""
    <div
      id={@id}
      class={@shell_classes}
      role="group"
      data-polaris-data-input
      data-copy-event={@on_copy}
      phx-hook={@needs_hook? && @hook}
    >
      <input
        id={@control_id}
        name={@name}
        type={@control_type}
        value={@value}
        placeholder={@placeholder}
        readonly={@readonly}
        disabled={@disabled}
        data-polaris-control
        data-reveal-type={@reveal && @type}
        data-copy-value={@copy_value}
        autocomplete="off"
        spellcheck="false"
        data-1p-ignore
        data-lpignore="true"
        data-form-type="other"
        data-bwignore
        class={@control_classes}
        {@rest}
      />
      <div :if={@icon != []} class="order-first flex items-center pl-2 text-content-secondary">
        {render_slot(@icon)}
      </div>
      <div :if={@copy or @reveal or @actions != []} class="order-last flex items-center gap-1 pr-1">
        <.button
          :if={@reveal}
          type="button"
          variant="default"
          size="tiny"
          class="h-6 px-2"
          data-polaris-reveal
        >
          Reveal
        </.button>
        <.button
          :if={@copy}
          type="button"
          variant="default"
          size="tiny"
          class={
            cn(["h-6 px-2", @show_copy_on_hover && "opacity-0 transition group-hover:opacity-100"])
          }
          hidden={@reveal}
          data-polaris-copy
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
              aria-hidden="true"
            >
              <rect width="14" height="14" x="8" y="8" rx="2" ry="2" />
              <path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" />
            </svg>
          </:icon>
          <span data-polaris-copy-label>Copy</span>
        </.button>
        {render_slot(@actions)}
      </div>
      <script :if={@needs_hook?} :type={Phoenix.LiveView.ColocatedHook} name=".Input" runtime>
        {
          mounted() {
            const shell = this.el
            const input = shell.querySelector("input[data-polaris-control]")
            const copyBtn = shell.querySelector("[data-polaris-copy]")
            const revealBtn = shell.querySelector("[data-polaris-reveal]")
            const copyLabel = shell.querySelector("[data-polaris-copy-label]")

            // Data fields are selected/copied wholesale on focus.
            this._onFocus = () => {
              if (input) {
                input.select()
              }
            }
            if (input) {
              input.addEventListener("focus", this._onFocus)
            }

            // Reveal is one-way: unmask, drop Reveal, surface Copy.
            this._onReveal = () => {
              if (input) {
                input.type = input.dataset.revealType || "text"
                input.focus()
              }
              if (revealBtn) {
                revealBtn.hidden = true
              }
              if (copyBtn) {
                copyBtn.hidden = false
              }
            }
            if (revealBtn) {
              revealBtn.addEventListener("click", this._onReveal)
            }

            this._onCopy = (event) => {
              event.preventDefault()
              const text = (input && (input.dataset.copyValue || input.value)) || ""
              const done = () => {
                if (copyLabel) {
                  copyLabel.textContent = "Copied"
                  window.setTimeout(() => {
                    copyLabel.textContent = "Copy"
                  }, 3000)
                }
                const evt = shell.dataset.copyEvent
                if (evt && typeof this.pushEvent === "function") {
                  this.pushEvent(evt)
                }
              }
              if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(done).catch(() => {})
              }
            }
            if (copyBtn) {
              copyBtn.addEventListener("click", this._onCopy)
            }
          },
          destroyed() {
            const shell = this.el
            if (!shell) {
              return
            }
            const input = shell.querySelector("input[data-polaris-control]")
            const copyBtn = shell.querySelector("[data-polaris-copy]")
            const revealBtn = shell.querySelector("[data-polaris-reveal]")
            if (input && this._onFocus) {
              input.removeEventListener("focus", this._onFocus)
            }
            if (copyBtn && this._onCopy) {
              copyBtn.removeEventListener("click", this._onCopy)
            }
            if (revealBtn && this._onReveal) {
              revealBtn.removeEventListener("click", this._onReveal)
            }
          }
        }
      </script>
    </div>
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

  # Heights/padding/text mirror the Supabase SIZE_VARIANTS for inputs.
  defp size_classes("tiny"), do: "h-[26px] px-2.5 text-xs"
  defp size_classes("small"), do: "h-[34px] px-3 text-sm"
  defp size_classes("medium"), do: "h-[38px] px-4 text-sm"
  defp size_classes("large"), do: "h-[42px] px-4 text-base"
  defp size_classes("xlarge"), do: "h-[50px] px-6 text-base"
end
