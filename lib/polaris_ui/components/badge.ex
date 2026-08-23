defmodule PolarisUI.Components.Badge do
  @moduledoc """
  The Polaris badge: contextual metadata attached to another item.

  Port of the Supabase design system Badge (`packages/ui`): a tiny
  high-density pill that displays surrounding state or product category.
  Its purpose should be self-evident from the surrounding context — the
  badge supports other elements, it is never the primary communication
  aid.

  ## Variants

  | Variant       | Appearance                                  | Use for                             |
  |---------------|---------------------------------------------|-------------------------------------|
  | `default`     | Panel surface, muted text, strong border    | Neutral counts and categories (the default) |
  | `warning`     | Amber tint fill, amber text + border        | At-risk / needs-attention states    |
  | `success`     | Emerald tint fill, brand text + border      | Healthy / completed states          |
  | `destructive` | Red tint fill, red text + border            | Failed / error states               |
  | `secondary`   | Faint surface fill, no visible border       | The quietest treatment — counts that must not compete (the only variant with a hover state) |

  Every colored variant follows the Supabase formula: a ~10%-alpha tinted
  fill, the full-strength color for text, and a translucent color border —
  keeping AA contrast in both dark (the default) and light palettes.

  ## Anatomy

      <.badge variant="success">Active</.badge>

  Typography is baked in: 9px medium uppercase with `0.07em` tracking and a
  pill radius. Do not alter text case or roundedness — consistent
  implementation is what makes badges instantly recognizable; use another
  component for other use cases (compute size, status codes, …).

  Keep badge text to one or two words. Badges are designed to stand out,
  so use them sparingly.

  ## States

  The badge is presentational — a non-interactive `<span>` with no hover,
  active, focus, or loading affordances of its own (`secondary`'s subtle
  hover fill mirrors the Supabase source). Interactive states belong to
  the controls a badge accompanies.

  ## Accessibility

  Purely contextual text: no `role`, no `aria-live`. Give the surrounding
  context (not the badge) the semantics — e.g. an `aria-label` on the row
  the badge annotates. Badges sit inline anywhere, including inside
  links and paragraphs, which is why Polaris renders a `<span>` where the
  React source renders a `<div>`.

  No colocated hook is required: everything is static markup and CSS.
  """

  use PolarisUI.Component

  @variants ~w(default warning success destructive secondary)

  attr(:variant, :string,
    values: @variants,
    default: "default",
    doc: """
    Visual treatment. `"default"` is the neutral workhorse; pick the color
    that matches the state, not the emphasis you want.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged last — caller classes win conflicts via `cn/1`."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the root `<span>`: `id`, `title`, `data-*`, `aria-*`, …
    (Wrapping the badge in a tooltip is the supported pattern.)
    """
  )

  slot(:inner_block,
    required: true,
    doc: "One or two words of contextual metadata. Case is enforced by CSS — pass sentence case."
  )

  def badge(assigns) do
    validate_in!(:variant, assigns.variant, @variants)

    assigns =
      assign(
        assigns,
        classes: cn([base_classes(), variant_classes(assigns.variant), assigns.class])
      )

    ~H"""
    <span class={@classes} data-polaris-badge={@variant} {@rest}>
      {render_slot(@inner_block)}
    </span>
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

  # The Supabase badge base: a 9px uppercase medium pill with sub-pixel-scale
  # padding and a 1px border (color per variant; transparent on secondary).
  defp base_classes do
    [
      "inline-flex items-center justify-center gap-1 rounded-full",
      "border whitespace-nowrap uppercase font-medium",
      "text-[9px] leading-none tracking-[0.07em] px-[5.5px] py-[3px]"
    ]
  end

  # Supabase maps bg-surface-75/foreground-light/border-strong and the
  # {color}/10 + {color}-600 + {color}-500 formula onto its semantic
  # palette; these are the Polaris token equivalents.
  defp variant_classes("default"),
    do: "bg-surface-panel text-content-secondary border-surface-border"

  defp variant_classes("warning"),
    do: "bg-warning-muted text-warning border-warning-border"

  defp variant_classes("success"),
    do: "bg-brand-emerald-muted text-brand-accent border-brand-border"

  defp variant_classes("destructive"),
    do: "bg-danger-muted text-danger border-danger-border"

  # "Secondary is invisible" (Supabase source comment): a faint elevated
  # fill that must not compete — and the only variant with a hover state.
  defp variant_classes("secondary"),
    do:
      "bg-surface-panel-hover/50 hover:bg-surface-panel-hover/80 border-transparent text-content-primary"
end
