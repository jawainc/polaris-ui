defmodule PolarisUI.Components.Card do
  @moduledoc """
  The Polaris card: a bordered surface that groups related content — the
  port of the Supabase design system Card (`packages/ui`, the shadcn-style
  compound component the MetricCard and CollapsibleCardSection fragments
  build on).

  ## Anatomy

      <.card class="max-w-sm">
        <.card_header>
          <.card_title>Create project</.card_title>
          <.card_description>
            Deploy a new Postgres database.
          </.card_description>
        </.card_header>
        <.card_content>
          <p>This section stays visible.</p>
        </.card_content>
        <.card_footer>
          <.button variant="primary">Create project</.button>
        </.card_footer>
      </.card>

    * **card** — the root surface: clipped corners (`overflow-hidden`),
      `rounded-lg`, the panel fill, a high-contrast border, and the
      hairline `shadow-xs`.
    * **header** — stacks title + description, closed with a `border-b`
      separator (`space-y-1.5`).
    * **title** — an `<h3>` in the Supabase signature: 12px monospaced
      uppercase.
    * **description** — a muted `<p>` for the one-line summary.
    * **content** — the body section, separated by `border-b` — dropped
      (`last:border-none`) when no footer follows, exactly like the source.
    * **footer** — action row (`flex items-center`).

  Sections share the horizontal rhythm `px-[var(--card-padding-x,1rem)]`
  (the Supabase `--card-padding-x` token, overridable per site; vertical
  rhythm is `py-4`). The sectioned separators — not gaps — are what give
  the Supabase card its dense, document-like feel.

  ## States

  The card is a non-interactive container by design (like the source):
  it owns no hover/focus machinery — interactive states belong to the
  controls composed inside it. Rest styling is the panel surface with
  `border-surface-border`; callers layer interactivity via `class`
  (`hover:border-surface-border-hover transition-colors`) when a whole
  card should feel clickable.

  Presentational only — no colocated hook required.
  """

  use PolarisUI.Component

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root (e.g. `max-w-sm`)."
  )

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "Typically header, content, and footer sections.")

  def card(assigns) do
    ~H"""
    <div
      class={
        cn([
          "overflow-hidden rounded-lg border border-surface-border bg-surface-panel text-content-primary shadow-xs",
          @class
        ])
      }
      data-polaris-card
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the header.")

  attr(:rest, :global, doc: "Forwarded to the header `<div>`: `data-*`, `aria-*`, …")

  slot(:inner_block,
    required: true,
    doc: "A `<.card_title>` plus an optional `<.card_description>`."
  )

  def card_header(assigns) do
    ~H"""
    <div
      class={
        cn([
          "flex flex-col space-y-1.5 border-b border-surface-border py-4 px-[var(--card-padding-x,1rem)]",
          @class
        ])
      }
      data-polaris-card-header
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the title.")

  attr(:rest, :global, doc: "Forwarded to the title `<h3>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "Title text — keep it a noun, not a verb.")

  def card_title(assigns) do
    ~H"""
    <h3 class={cn(["text-xs font-mono uppercase", @class])} data-polaris-card-title {@rest}>
      {render_slot(@inner_block)}
    </h3>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the description.")

  attr(:rest, :global, doc: "Forwarded to the description `<p>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "One-line summary (concise microcopy, no fluff).")

  def card_description(assigns) do
    ~H"""
    <p class={cn(["text-sm text-content-secondary", @class])} data-polaris-card-description {@rest}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the content section.")

  attr(:rest, :global, doc: "Forwarded to the content `<div>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "The card body.")

  def card_content(assigns) do
    ~H"""
    <div
      class={
        cn([
          "border-b border-surface-border py-4 px-[var(--card-padding-x,1rem)] last:border-none",
          @class
        ])
      }
      data-polaris-card-content
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the footer.")

  attr(:rest, :global, doc: "Forwarded to the footer `<div>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "Action row — buttons with direct-verb microcopy.")

  def card_footer(assigns) do
    ~H"""
    <div
      class={cn(["flex items-center py-4 px-[var(--card-padding-x,1rem)]", @class])}
      data-polaris-card-footer
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
