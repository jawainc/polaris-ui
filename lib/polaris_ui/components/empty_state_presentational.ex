defmodule PolarisUI.Components.EmptyStatePresentational do
  @moduledoc """
  The Polaris empty state (presentational): a dashed-border encouragement
  card for the *initial* state of a feature — when the user is learning it
  for the first time and the empty canvas should teach the next action.

  Port of the Supabase design system fragment
  `ui-patterns/EmptyStatePresentational`. It is deliberately not for
  zero-results in tables (mirror the data-present presentation instead) or
  missing routes (use a centered admonition) — those read as absence, while
  this reads as invitation.

  ## Anatomy

      <.empty_state_presentational
        title="Create a vector bucket"
        description="Store, index, and query your vector embeddings at scale."
      >
        <.button variant="primary" size="tiny">
          <:icon><svg data-icon="plus" /></:icon>
          Create bucket
        </.button>
      </.empty_state_presentational>

    * **root** — a full-width `border-dashed` card on the recessed base
      surface, generous `py-10` padding, everything centered.
    * **icon** — a muted glyph (default: the square-plus) at 24px with a
      1.5 stroke, above the text.
    * **title** — an `<h3>` written as the action prompt.
    * **description** — one line selling the value of doing it, capped at a
      readable measure.
    * **inner block** — the actions, dropped after the text group.

  ## Microcopy

  All text uses active language per the Supabase copywriting guidelines:
  the title prompts the action ("Create a vector bucket", never "No vector
  buckets found") and the description explains the value of doing so. Bad:
  "You don't have any tables" — good: "No tables yet. Create your first
  table to get started."

  ## Repeating entry points

  It is acceptable to repeat a button that already exists outside the
  empty state — conditional placement causes layout shift during polling,
  and consistent entry points teach a pattern that outlives the empty
  state. When repeating, use a `default`-variant button so the original
  `primary` stays the only primary action on display.

  ## Accessibility

    * The title is a real `<h3>` and the description a `<p>`; both derive
      their semantics from document structure.
    * The icon is decoration (`aria-hidden`) — the copy carries the meaning.
    * Actions come through the inner block, so they bring their own
      semantics (compose `<.button>` for the full state machine: rest,
      hover, focus-ring, active, loading, disabled).

  Purely presentational — no colocated hook and no client state.
  """

  use PolarisUI.Component

  @icon_sizes ~w(small medium large)

  attr(:title, :string,
    required: true,
    doc: "Action-prompt heading rendered as an `<h3>` (\"Create a vector bucket\")."
  )

  attr(:description, :string,
    default: nil,
    doc: """
    One line explaining the value of acting — omitted entirely when blank,
    exactly like the fragment's conditional `<p>`.
    """
  )

  attr(:icon_size, :string,
    values: @icon_sizes,
    default: "medium",
    doc: "Glyph scale: `small` 16px, `medium` 24px (the fragment default), `large` 32px."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root `<aside>` — caller classes win via `cn/1`."
  )

  attr(:content_class, :string,
    default: nil,
    doc: "Additional classes merged onto the title/description text block."
  )

  attr(:icon_class, :string,
    default: nil,
    doc: "Additional classes merged onto the icon wrapper (tints, sizing overrides)."
  )

  attr(:rest, :global, doc: "Forwarded to the root `<aside>`: `id`, `data-*`, `aria-*`, …")

  slot(:icon,
    doc: """
    Custom icon markup (an inline SVG). Replaces the default square-plus
    glyph; sized by `icon_size` unless your markup carries its own size.
    """
  )

  slot(:inner_block,
    doc: "Actions — typically `<.button>` calls — rendered under the text group."
  )

  def empty_state_presentational(assigns) do
    validate_in!(:icon_size, assigns.icon_size, @icon_sizes)

    assigns =
      assigns
      |> assign(
        icon_classes:
          cn([
            "flex items-center justify-center text-content-muted",
            svg_size_classes(assigns.icon_size),
            assigns.icon_class
          ])
      )

    ~H"""
    <aside
      class={
        cn([
          "flex w-full flex-col items-center gap-y-3 rounded-lg",
          "border border-dashed border-surface-border bg-surface-base px-4 py-10",
          assigns.class
        ])
      }
      {@rest}
    >
      <div class="flex flex-col items-center gap-y-3">
        <%= if @icon != [] do %>
          <span data-polaris-empty-state-icon class={@icon_classes}>{render_slot(@icon)}</span>
        <% else %>
          <span data-polaris-empty-state-icon class={@icon_classes}>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <rect width="18" height="18" x="3" y="3" rx="2" />
              <path d="M12 8v8" /><path d="M8 12h8" />
            </svg>
          </span>
        <% end %>
        <div class={cn(["flex flex-col items-center text-center text-balance", @content_class])}>
          <h3
            class="text-base font-normal text-content-primary"
            data-polaris-empty-state-title
          >
            {@title}
          </h3>
          <p
            :if={@description}
            class="max-w-[640px] text-sm text-content-secondary"
            data-polaris-empty-state-description
          >
            {@description}
          </p>
        </div>
      </div>
      {render_slot(@inner_block)}
    </aside>
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

  # Static per-size glyph sizing (Tailwind cannot see dynamically built
  # classes). A slotted icon carrying its own size- class wins via cn/1.
  defp svg_size_classes("small"), do: "[&>svg]:size-4"
  defp svg_size_classes("medium"), do: "[&>svg]:size-6"
  defp svg_size_classes("large"), do: "[&>svg]:size-8"
end
