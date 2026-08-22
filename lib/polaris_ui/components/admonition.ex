defmodule PolarisUI.Components.Admonition do
  @moduledoc """
  The Polaris admonition: a callout for user attention — the standard
  product callout pattern for situations that require the user to notice
  something before (or instead of) acting.

  Port of the Supabase design system fragment
  `ui-patterns/Admonition` (built there on the shadcn `Alert` primitive):
  a `role="alert"` region with a colored icon badge, an optional paragraph
  title, body copy, and an actions slot — no dismiss button (actions
  replace dismissal).

  ## Types

  Eight semantic types collapse into three visual variants plus an emerald
  success treatment, each carrying an `aria-label` derived from the type:

  | Type                                  | Visual            | Badge / glyph          | `aria-label` |
  |---------------------------------------|-------------------|------------------------|--------------|
  | `note` (the default), `default`       | Neutral surface   | Muted chip, info       | Note         |
  | `caution`, `warning`, `deprecation`   | Amber tint        | Amber chip, triangle   | Caution / Warning / Deprecated |
  | `danger`, `destructive`               | Red tint          | Red chip, triangle     | Danger       |
  | `success`                             | Emerald tint      | Emerald chip, check    | Success      |

  ## Anatomy

      <.admonition type="warning" layout="horizontal" title="OAuth Server is disabled">
        <:description>
          Enable OAuth Server to make your project act as an identity provider.
        </:description>
        <:action>
          <.button>Open OAuth settings</.button>
        </:action>
      </.admonition>

    * **title** — optional short label, rendered as a `<p>` (a paragraph,
      never a heading, matching the Supabase `AlertTitle`). Pair it with a
      description; a title-only admonition reads like an incomplete heading.
    * **description / inner block** — the body copy. `description` is for
      rich markup, the inner block is the drop-in equivalent of the Supabase
      `children` slot; both may be used, and both render as description
      blocks. Description-only callouts work for short notes next to a
      heading or label that already gives context.
    * **actions** — buttons, links, or menus (see below).
    * **icon badge** — a 23px chip with a glyph per visual variant;
      suppressed with `show_icon={false}`, replaced wholesale via the
      `icon` slot.

  Body copy is plain content — wrap paragraphs in `<p>` yourself and the
  component applies the Supabase paragraph rhythm (`[&_p]:mb-1.5` etc.).

  ## Layouts

    * `vertical` (default) — content stacks; actions render below the copy.
    * `horizontal` — content and actions share a row, actions right-aligned.
    * `responsive` — vertical when narrow, horizontal at the `@md` container
      breakpoint. The root becomes a `@container`, so the switch is driven
      by the admonition's own width, independent of the page.

  ## Actions

  Style action buttons by the action's context, not the admonition type: a
  warning admonition with an encouraged action still uses a `default`
  button; destructive resolutions take a `danger` button. Reserve `primary`
  for `default` admonitions, and rarely — a callout is already an isolated
  focal point.

  ## States

  The admonition root is a passive `role="alert"` region — it is not a
  control, so it deliberately has no hover, active, or focus affordances
  (adding them would signal clickability the component doesn't have). The
  interactive states — rest, hover, active, `:focus-visible` ring, loading,
  and disabled — live on the slotted action controls; compose `<.button>`
  (or links) into `:action` and they carry their full state machine within
  the admonition.

  ## Accessibility

    * The root renders `role="alert"` with `aria-label` derived from the
      type. Override either through global attributes for passive updates
      (`role="status"` avoids the assertive announcement queue).
    * The icon badge and glyphs are `aria-hidden` decoration — the label
      and text content carry the semantics.

  ## Sandwiched usage

  Inside cards or dialogs, flatten the chrome with caller classes:
  `class="rounded-none border-x-0"` (keep the tinted borders on warning /
  danger admonitions — they are the emphasis).

  No colocated hook is required: everything is static markup and CSS.
  """

  use PolarisUI.Component

  @types ~w(note caution danger deprecation default destructive success warning)
  @layouts ~w(vertical horizontal responsive)

  # Semantic type -> visual variant (Supabase TYPE_TO_VARIANT, with the
  # success special case folded into a dedicated variant).
  @type_to_variant %{
    "note" => "default",
    "default" => "default",
    "caution" => "warning",
    "warning" => "warning",
    "deprecation" => "warning",
    "danger" => "destructive",
    "destructive" => "destructive",
    "success" => "success"
  }

  @type_labels %{
    "note" => "Note",
    "default" => "Note",
    "caution" => "Caution",
    "warning" => "Warning",
    "deprecation" => "Deprecated",
    "danger" => "Danger",
    "destructive" => "Danger",
    "success" => "Success"
  }

  attr(:type, :string,
    values: @types,
    default: "note",
    doc: """
    Semantic type controlling the visual variant, icon badge, and default
    `aria-label`. `"note"` (neutral) is the workhorse; `"warning"` /
    `"danger"` tint amber / red; `"success"` is for completed states where
    the user need not act.
    """
  )

  attr(:layout, :string,
    values: @layouts,
    default: "vertical",
    doc: """
    Content arrangement: `vertical` stacks actions under the copy,
    `horizontal` puts them in a right-aligned row, `responsive` switches
    between the two at the `@md` container breakpoint.
    """
  )

  attr(:title, :string,
    default: nil,
    doc: "Short callout heading, rendered as a `<p>` (not a heading element)."
  )

  attr(:show_icon, :boolean,
    default: true,
    doc: "Render the icon badge (or the `icon` slot) at the start of the callout."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged last — caller classes win conflicts via `cn/1`."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the root `<div>`: `id`, `data-*`, `phx-*`, … A caller
    `role` or `aria-label` overrides the derived defaults (e.g.
    `role="status"` for passive announcements).
    """
  )

  slot(:icon,
    doc: """
    Replaces the default icon badge entirely (chip and glyph) — size the
    replacement yourself. Still gated by `show_icon`.
    """
  )

  slot(:description, doc: "Body copy; render paragraphs as `<p>` for the spacing rhythm.")

  slot(:inner_block,
    doc: "Body copy alias for the inner block — renders like `description`."
  )

  slot(:action, doc: "Buttons / links / menus, arranged per `layout`.")

  def admonition(assigns) do
    validate_in!(:type, assigns.type, @types)
    validate_in!(:layout, assigns.layout, @layouts)

    variant = @type_to_variant[assigns.type]
    layout = assigns.layout

    # LV creates an inner_block even when the do-block holds only <:action>
    # entries (its content is then whitespace), so blank-render is the only
    # reliable signal for whether a body exists.
    has_description? = slot_content?(assigns.description, assigns)
    has_children? = slot_content?(assigns.inner_block, assigns)

    assigns =
      assigns
      |> assign(
        variant: variant,
        # Caller-provided role/aria-label win over the derived defaults.
        role: assigns.rest[:role] || "alert",
        label: assigns.rest[:"aria-label"] || @type_labels[assigns.type],
        rest: Map.drop(assigns.rest, [:role, :"aria-label"]),
        root_classes:
          cn([
            "relative w-full overflow-hidden rounded-lg border p-4 text-sm",
            "text-content-primary",
            variant_classes(variant),
            (layout == "responsive" and "@container") || nil,
            assigns.class
          ]),
        badge_classes: badge_classes(variant),
        content_classes: content_classes(assigns.layout),
        actions_classes: actions_classes(assigns.layout),
        body_classes: body_classes(),
        # Aligns description-only copy with the icon badge (Supabase my-0.5).
        align_body?:
          assigns.show_icon and is_nil(assigns.title) and (has_description? or has_children?),
        has_description?: has_description?,
        has_children?: has_children?
      )

    ~H"""
    <div role={@role} aria-label={@label} class={@root_classes} {@rest}>
      <div class="flex items-start gap-3">
        <%= if @show_icon do %>
          <%= if @icon != [] do %>
            {render_slot(@icon)}
          <% else %>
            <span class={@badge_classes} data-polaris-icon={@variant}>
              <.glyph variant={@variant} />
            </span>
          <% end %>
        <% end %>
        <div class={@content_classes}>
          <div class={cn(["min-w-0", if(@align_body?, do: "my-0.5")])}>
            <p
              :if={@title}
              class="mb-0.5 mt-0 font-medium text-content-primary"
              data-polaris-admonition-title
            >
              {@title}
            </p>
            <div :if={@has_description?} class={@body_classes}>{render_slot(@description)}</div>
            <div :if={@has_children?} class={@body_classes}>{render_slot(@inner_block)}</div>
          </div>
          <div :if={@action != []} class={@actions_classes}>{render_slot(@action)}</div>
        </div>
      </div>
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

  # Tinted translucent fills with visible borders, mirroring the Supabase
  # alertVariants (`bg-surface-200/25 border-default`, warning-200/400, …).
  defp variant_classes("default"), do: "border-surface-border bg-surface-panel/40"
  defp variant_classes("warning"), do: "border-warning-border bg-warning-muted"
  defp variant_classes("destructive"), do: "border-danger-border bg-danger-muted"
  defp variant_classes("success"), do: "border-brand-border bg-brand-emerald-muted"

  # Solid badge chips with inverted glyphs — the glyph inherits the chip's
  # text color (the root surface tone), so chips stay legible in both
  # palettes. 23px chip, 15px glyph, mirroring the Supabase icon badge.
  defp badge_classes(variant) do
    cn([
      "inline-flex shrink-0 items-center justify-center rounded-sm p-1 size-[23px]",
      "[&>svg]:size-full",
      badge_tint(variant)
    ])
  end

  defp badge_tint("default"), do: "bg-content-muted text-surface-ground"
  defp badge_tint("warning"), do: "bg-warning text-surface-ground"
  defp badge_tint("destructive"), do: "bg-danger text-surface-ground"
  defp badge_tint("success"), do: "bg-brand-emerald text-surface-ground"

  defp content_classes("vertical"),
    do: "flex min-w-0 flex-1 flex-col"

  defp content_classes("horizontal"),
    do: "flex min-w-0 flex-1 flex-row items-center justify-between gap-x-6 lg:gap-x-8"

  defp content_classes("responsive"),
    do:
      "flex min-w-0 flex-1 flex-col @md:flex-row @md:items-center @md:justify-between @md:gap-x-6 @lg:gap-x-8"

  defp actions_classes("vertical"), do: "mt-3 flex flex-row items-start gap-2"
  defp actions_classes("horizontal"), do: "flex flex-row items-center gap-2"

  defp actions_classes("responsive"),
    do: "mt-3 flex flex-row items-start gap-2 @md:mt-0 @md:items-center"

  # Supabase's admonitionBodyClassName: the block itself has no bottom
  # margin; paragraphs and lists inside get the callout rhythm.
  defp body_classes do
    cn([
      "mb-0 text-sm text-content-secondary",
      "[&_p]:mt-0 [&_p]:mb-1.5 [&_p:last-child]:mb-0",
      "[&_ul]:my-1.5 [&_ol]:my-1.5 [&_li]:my-0.5"
    ])
  end

  attr(:variant, :string, default: nil, doc: "visual variant selecting the glyph")

  # Lucide-style stroke glyphs at badge scale; danger reuses the warning
  # triangle with destructive chip colors, exactly like the Supabase icons.
  defp glyph(%{variant: variant} = assigns) when variant in ~w(warning destructive) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 20h16a2 2 0 0 0 1.73-2Z" />
      <path d="M12 9v4" /><path d="M12 17h.01" />
    </svg>
    """
  end

  defp glyph(%{variant: "success"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="9.5" />
      <path d="m8.5 12.2 2.4 2.4 4.6-4.9" />
    </svg>
    """
  end

  defp glyph(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="9.5" />
      <path d="M12 11v5" /><path d="M12 7.5h.01" />
    </svg>
    """
  end
end
