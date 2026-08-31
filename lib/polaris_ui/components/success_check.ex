defmodule PolarisUI.Components.SuccessCheck do
  @moduledoc """
  The Polaris success check: the emerald circle with a check that marks
  an item as chosen or a step as complete — the port of the Supabase
  design system SuccessCheck (`packages/ui/src/components/SuccessCheck.tsx`).

  It is deliberately *static*: one 20px emerald disc, one 12px check,
  no animation — the state change is the signal, so it lands the
  instant the server says so (the source ships no motion either). Use
  it exactly the two ways the Supabase docs prescribe:

    * **Selected state** — position it absolutely in the trailing
      corner of a selectable row; toggle it from your server state.

          <button phx-click="pick-env" aria-pressed={@env == "production"}
                  class="relative flex w-full items-center rounded-md border px-4 py-3 pr-10 text-left text-sm">
            {@env}
            <.success_check :if={@env == "production"}
              class="absolute right-3 top-1/2 -translate-y-1/2" />
          </button>

    * **Completion progress** — completed steps wear the check;
      upcoming steps wear a plain bordered circle of the same 20px
      footprint; the current step wears the ring.

          <div class="flex items-center gap-3">
            <.success_check :if={done} />
            <span :if={not done} class="size-5 shrink-0 rounded-full border border-surface-border" />
            <span class="text-sm">{step}</span>
          </div>

  ## Anatomy

      <.success_check />

    * **disc** — `inline-flex size-5 shrink-0 items-center
      justify-center rounded-full` filled and ringed in the brand
      emerald (`border-brand-emerald bg-brand-emerald`). The check
      stroke rides `currentColor` at the ground color (`text-surface-ground`):
      near-black on the emerald in the dark theme, near-white under
      `polaris-light` — the source's `text-white dark:text-black`.
    * **check** — the Lucide `Check` path (`M20 6 9 17l-5-5`) drawn at
      12px with a 3px stroke and round caps, inline SVG so it needs no
      icon runtime.

  ## Accessibility

  The check is a *visual echo* of state the row already carries — keep
  the semantics there (`aria-pressed` on the selected row, the step
  list's own labels) and let this render `aria-hidden`, like the
  source's unlabelled span.
  """

  use PolarisUI.Component

  attr(
    :class,
    :string,
    default: nil,
    doc: """
    Additional classes merged onto the disc — where the docs' absolute
    positioning lands (`absolute right-3 top-1/2 -translate-y-1/2`) or
    size overrides.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the wrapper `<span>`: `data-*`, …")

  def success_check(assigns) do
    ~H"""
    <span
      data-polaris-success-check
      aria-hidden="true"
      class={
        cn([
          "inline-flex size-5 shrink-0 items-center justify-center rounded-full",
          "border border-brand-emerald bg-brand-emerald text-surface-ground",
          @class
        ])
      }
      {@rest}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="3"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="size-3"
        aria-hidden="true"
      >
        <path d="M20 6 9 17l-5-5" />
      </svg>
    </span>
    """
  end
end
