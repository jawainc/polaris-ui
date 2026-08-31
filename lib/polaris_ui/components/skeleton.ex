defmodule PolarisUI.Components.Skeleton do
  @moduledoc """
  The Polaris skeleton: a pulsing placeholder that mirrors the shape of
  content still loading — the port of the Supabase design system
  Skeleton (`packages/ui`, one `<div>` over `animate-pulse bg-muted`).

  The skeleton is a *shape*, not a component tree: size it with the same
  utilities the real content will wear and the loading state reads as a
  ghost of the destination. The Supabase docs' canonical ghost is a row
  — a `rounded-full` avatar square beside two text bars of differing
  widths; their card ghost stacks a media block over the same bars.
  Wrap the group in a `aria-busy="true"` container so screen readers
  announce the region as loading.

  ## Anatomy

      <div class="flex items-center gap-4" aria-busy="true" aria-label="Loading members">
        <.skeleton class="size-12 rounded-full" />
        <div class="flex flex-col gap-2">
          <.skeleton class="h-4 w-[250px]" />
          <.skeleton class="h-4 w-[200px]" />
        </div>
      </div>

    * **placeholder** — a plain `<div>` wearing `animate-pulse
      rounded-md bg-surface-muted`. Everything else — height, width,
      radius (`rounded-full` for avatars, `rounded-xl` for media) —
      arrives through `class`, exactly like the source's single
      `className` prop.

  ## The muted wash

  The fill is the source's `bg-muted`: a low-alpha wash of the content
  color (`--color-surface-muted`), not an opaque surface, so skeletons
  read over whatever panel sits behind them and flip correctly under
  `polaris-light`. The `animate-pulse` keyframes (opacity dipping to
  50% over 2s) are Tailwind's stock pulse.

  ## Accessibility

  The skeleton itself is decorative; the loading semantics belong to
  the container. Forward `aria-hidden="true"` through the global
  attributes if it stands alone, or label the busy region:

      <div aria-busy="true" aria-live="polite">
        <.skeleton class="h-4 w-full" />
      </div>

  No colocated hook is required: the pulse is pure CSS, so skeletons
  ride ordinary LiveView patches — including being swapped out for the
  real content when it lands.
  """

  use PolarisUI.Component

  attr(
    :class,
    :string,
    default: nil,
    doc: """
    The placeholder's shape — sizes and radii for the content being
    loaded (`h-4 w-[250px]`, `size-12 rounded-full`, `h-[125px]
    w-[250px] rounded-xl`, …).
    """
  )

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `aria-*`, …")

  def skeleton(assigns) do
    ~H"""
    <div
      data-polaris-skeleton
      aria-hidden="true"
      class={cn(["animate-pulse rounded-md bg-surface-muted", @class])}
      {@rest}
    />
    """
  end
end
