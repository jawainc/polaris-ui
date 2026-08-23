defmodule PolarisUI.Components.Checkbox do
  @moduledoc """
  The Polaris checkbox: a control that toggles between checked and not
  checked — the port of the Supabase design system Checkbox
  (`packages/ui`, a shadcn wrapper over the Radix Checkbox).

  ## Anatomy

      <.checkbox id="terms" name="terms" on_change="toggle-terms">
        Accept terms and conditions
      </.checkbox>

    * **box** — the 16px interactive square: `rounded-sm` border over a
      faint panel fill, inverting to a bright fill when checked (the
      Supabase signature — foreground fill, background check, never
      emerald).
    * **label** — the inner block renders into a `<label for>` wired to
      the box, dimming alongside it (`peer-disabled:opacity-70`).
    * **hidden input** — with `name` set, a visually-hidden native
      checkbox carries the value into form submissions, kept in sync by
      the hook (the Radix form-participation pattern).

  ## State model

  Toggling is **client-side**, like Radix: the colocated runtime hook owns
  the state machine — unchecked → checked → unchecked, and
  indeterminate → checked on first activation — then syncs the hidden
  input (dispatching bubbling `input`/`change` so `phx-change` forms
  observe the toggle) and optionally mirrors the toggle to the server via
  `on_change` (`%{"state" => "checked" | "unchecked" | "indeterminate",
  "value" => value}`). The hook re-applies its state after LiveView
  patches, so toggles survive re-renders without a round trip.

  ## States

    * **rest / hover** — `border-surface-border` over `bg-surface-panel/25`,
      brightening to `border-surface-border-hover` on hover; the fill and
      check cross-fade in 150ms.
    * **focus-ring** — high-visibility emerald ring on `:focus-visible`
      only, with offset from the ground surface.
    * **checked / indeterminate** — the box inverts: bright
      `bg-content-primary` fill with the dark check (`text-surface-ground`)
      like the source's `data-[state=checked]:bg-foreground
      data-[state=checked]:text-background`; the mixed state shows a dash.
    * **disabled** — native `disabled`, `tabindex="-1"` (the Supabase
      `getExplicitTabIndex` Safari fix), `cursor-not-allowed` at 50%
      opacity, and the label dims through the `peer` relationship.

  ## Accessibility

    * The box is a `<button role="checkbox">` carrying `aria-checked`
      (`"true"` / `"false"` / `"mixed"`); `Enter`/`Space` toggle (native
      button behavior) and the paired `<label for>` gives it an accessible
      name — clicking the label activates the box.
    * The hidden input is `sr-only` and out of the tab order; the button
      is the single keyboard/assistive face.
    * Forward `aria-describedby` / `aria-required` through the global
      attributes to wire field-level validation.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the checkbox button — required because the colocated
    hook that owns the state anchors on it. The label derives
    `"<id>-label"` for the `aria-labelledby` wiring.
    """
  )

  attr(:name, :string,
    default: nil,
    doc: """
    Form field name — renders the hidden native checkbox that carries the
    value into form submissions (omit for purely interactive toggles).
    """
  )

  attr(:value, :string, default: "on", doc: "Value submitted with the form when checked.")

  attr(:checked, :boolean,
    default: false,
    doc: "Initial checked state (the hook owns toggles from then on)."
  )

  attr(:indeterminate, :boolean,
    default: false,
    doc: """
    Renders the mixed state (`aria-checked="mixed"` + dash): a parent
    aggregate with both checked and unchecked children. First activation
    checks it, like Radix.
    """
  )

  attr(:disabled, :boolean, default: false, doc: "Disables the box and dims the label.")

  attr(:on_change, :string,
    default: nil,
    doc: """
    Optional LiveView event pushed on every toggle with
    `%{"state" => "checked" | "unchecked" | "indeterminate", "value" => value}`.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the 16px box (e.g. `h-5 w-5`)."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the checkbox button: `phx-click`, `aria-describedby`,
    `aria-required`, `data-*`, …
    """
  )

  slot(:inner_block,
    doc: "Label text — concise field microcopy (\"Accept terms and conditions\")."
  )

  def checkbox(assigns) do
    state =
      cond do
        assigns.indeterminate -> "indeterminate"
        assigns.checked -> "checked"
        true -> "unchecked"
      end

    aria_checked =
      case state do
        "checked" -> "true"
        "indeterminate" -> "mixed"
        _ -> "false"
      end

    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Box",
        state: state,
        aria_checked: aria_checked,
        has_label: assigns.inner_block != []
      )

    ~H"""
    <div class="flex items-center gap-2" data-polaris-checkbox>
      <button
        type="button"
        role="checkbox"
        id={@id}
        aria-checked={@aria_checked}
        aria-labelledby={@has_label && "#{@id}-label"}
        data-polaris-checkbox-box
        data-state={@state}
        data-value={@value}
        data-change-event={@on_change}
        disabled={@disabled}
        tabindex={if(@disabled, do: "-1", else: "0")}
        class={
          cn([
            "peer group flex h-4 w-4 shrink-0 cursor-pointer items-center justify-center rounded-sm",
            "border border-surface-border bg-surface-panel/25",
            "transition-colors duration-150 ease-in-out",
            "hover:border-surface-border-hover",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "disabled:cursor-not-allowed disabled:opacity-50",
            "data-[state=checked]:border-content-primary data-[state=checked]:bg-content-primary data-[state=checked]:text-surface-ground",
            "data-[state=indeterminate]:border-content-primary data-[state=indeterminate]:bg-content-primary data-[state=indeterminate]:text-surface-ground",
            @class
          ])
        }
        phx-hook={@hook}
        {@rest}
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="4"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
          class="h-3 w-3 opacity-0 transition-opacity duration-150 ease-in-out group-data-[state=checked]:opacity-100 motion-reduce:transition-none"
        >
          <path d="M20 6 9 17l-5-5" />
        </svg>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="4"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
          class="absolute h-3 w-3 opacity-0 transition-opacity duration-150 ease-in-out group-data-[state=indeterminate]:opacity-100 motion-reduce:transition-none"
        >
          <path d="M5 12h14" />
        </svg>
      </button>
      <input
        :if={@name}
        type="checkbox"
        name={@name}
        value={@value}
        checked={@state != "unchecked"}
        tabindex="-1"
        class="sr-only"
        data-polaris-checkbox-input
      />
      <label
        :if={@has_label}
        for={@id}
        id={"#{@id}-label"}
        class="cursor-pointer text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
      >
        {render_slot(@inner_block)}
      </label>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Box" runtime>
      {
        mounted() {
          this._state = this.el.dataset.state || "unchecked"
          this._input = this.el.parentElement.querySelector("[data-polaris-checkbox-input]")
          this._onClick = () => this._toggle()
          this.el.addEventListener("click", this._onClick)
          this._syncInput()
        },
        updated() {
          // LiveView patches may stomp data-state/aria; re-apply.
          this._apply()
          this._syncInput()
        },
        destroyed() {
          this.el.removeEventListener("click", this._onClick)
        },
        _toggle() {
          // The Radix cycle: indeterminate and unchecked check in; checked checks out.
          this._state = this._state === "checked" ? "unchecked" : "checked"
          this._apply()
          this._syncInput()
          if (this._input) {
            // Bubble through the hidden input so phx-change forms observe the toggle.
            this._input.dispatchEvent(new Event("input", { bubbles: true }))
            this._input.dispatchEvent(new Event("change", { bubbles: true }))
          }
          const name = this.el.dataset.changeEvent
          if (name && typeof this.pushEvent === "function") {
            this.pushEvent(name, { state: this._state, value: this.el.dataset.value })
          }
        },
        _apply() {
          this.el.dataset.state = this._state
          this.el.setAttribute(
            "aria-checked",
            this._state === "checked" ? "true" : this._state === "indeterminate" ? "mixed" : "false"
          )
        },
        _syncInput() {
          if (!this._input) return
          this._input.checked = this._state !== "unchecked"
          this._input.indeterminate = this._state === "indeterminate"
        }
      }
    </script>
    """
  end
end
