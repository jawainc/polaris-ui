defmodule PolarisUI.Components.Alert do
  @moduledoc """
  The Polaris alert: the low-level callout primitive for user attention.

  Port of the Supabase design system Alert (`packages/ui`, a cva-styled
  primitive): a `role="alert"` region with an absolutely-positioned icon
  badge, an optional paragraph title, and description copy.

  This is the **primitive**, not the product pattern — use `<.admonition>`
  (the port of the Supabase Admonition fragment) for standard product
  callouts; it adds semantic types, layouts, actions, and the standard
  icon glyphs. Reach for `<.alert>` when you need bespoke icons, custom
  internal layouts, or wrapper components building on the variant
  formula. Use `<.collapsible_alert>` when a callout also needs
  expandable detail.

  ## Variants

  Exactly three, like the source (`success` callouts are an Admonition
  concern, not an Alert variant):

  | Variant       | Container                                  | Icon badge                      |
  |---------------|--------------------------------------------|---------------------------------|
  | `default`     | Panel tint, standard border                | Inverted neutral chip           |
  | `destructive` | Red tint fill + translucent red border     | Red chip                        |
  | `warning`     | Amber tint fill + translucent amber border | Amber chip                      |

  ## Anatomy

      <.alert variant="warning" title="Heads up!">
        <:icon><svg data-icon="terminal" /></:icon>
        <:description>
          <p>You can add components to your app using the CLI.</p>
        </:description>
      </.alert>

    * **icon** — rendered as a *direct child* of the root, exactly like
      the React children slot: a leading SVG is picked up by the root's
      `[&>svg]:*` classes and turned into the 23px absolute badge
      (`left-4 top-4`, padded, rounded, tinted per variant). Pass a bare
      `<svg>` — wrapped markup escapes the styling, by design.
    * **title** — short label rendered as a `<p>` (`mt-0 mb-0.5
      font-medium`), the equivalent of the React `AlertTitle`.
    * **description / inner block** — body copy (`text-sm`, secondary
      color) with the paragraph rhythm `[&_p]:mb-0.5 [&_p:last-child]:mb-0`;
      the inner block is the drop-in equivalent of the React `children`.
      When an icon is present, the following content is padded past it
      (`[&>svg~*]:pl-10`) — the exact selector the source uses.

  ## States

  The alert root is a passive `role="alert"` region — it is not a
  control, so it deliberately has no hover, active, or focus affordances.
  Interactive states live on whatever controls you compose into the
  description (e.g. `<.button>`).

  ## Accessibility

    * The root renders `role="alert"`. For passive updates override with
      `role="status"` through the global attributes (announces politely
      instead of assertively).
    * The icon badge is decoration — mark slotted SVGs `aria-hidden="true"`.

  No colocated hook is required: everything is static markup and CSS.
  """

  use PolarisUI.Component

  @variants ~w(default destructive warning)

  attr(:variant, :string,
    values: @variants,
    default: "default",
    doc: """
    Visual treatment: neutral `default`, red `destructive`, amber
    `warning`. Tints the container fill, border, and the icon badge.
    """
  )

  attr(:title, :string,
    default: nil,
    doc: "Short callout heading, rendered as a `<p>` — pair it with description copy."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged last — caller classes win conflicts via `cn/1`."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the root `<div>`: `id`, `role`, `aria-label`, `data-*`, …
    A caller `role` overrides the `alert` default (e.g. `role="status"`).
    """
  )

  slot(:icon,
    doc: """
    A bare leading `<svg>`, rendered as a direct child of the root where
    the auto-icon classes apply (23px absolute badge, tinted per variant).
    """
  )

  slot(:description, doc: "Body copy; render paragraphs as `<p>` for the spacing rhythm.")

  slot(:inner_block, doc: "Body copy alias for the inner block — renders like `description`.")

  def alert(assigns) do
    validate_in!(:variant, assigns.variant, @variants)

    # LV creates an inner_block even when the do-block holds only <:icon> or
    # <:description> entries, so blank-render is the reliable signal.
    has_description? = slot_content?(assigns.description, assigns)
    has_children? = slot_content?(assigns.inner_block, assigns)

    assigns =
      assigns
      |> assign(
        # Caller-provided role wins over the assertive default.
        role: assigns.rest[:role] || "alert",
        rest: Map.drop(assigns.rest, [:role]),
        root_classes: cn([base_classes(), variant_classes(assigns.variant), assigns.class]),
        has_description?: has_description?,
        has_children?: has_children?
      )

    ~H"""
    <div role={@role} class={@root_classes} data-polaris-alert={@variant} {@rest}>
      {render_slot(@icon)}
      <p :if={@title} class="mt-0 mb-0.5 font-medium text-content-primary" data-polaris-alert-title>
        {@title}
      </p>
      <div
        :if={@has_description?}
        class="mb-0.5 text-sm font-normal text-content-secondary [&_p]:mb-0.5 [&_p:last-child]:mb-0"
        data-polaris-alert-description
      >
        {render_slot(@description)}
      </div>
      <div
        :if={@has_children?}
        class="mb-0.5 text-sm font-normal text-content-secondary [&_p]:mb-0.5 [&_p:last-child]:mb-0"
      >
        {render_slot(@inner_block)}
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

  # Container + the direct-child SVG badge styling, mirroring the source's
  # cva base (`[&>svg~*]:pl-10` pads content past the absolute icon badge).
  defp base_classes do
    [
      "relative w-full rounded-lg border p-4 text-sm text-content-primary",
      "[&>svg~*]:pl-10",
      "[&>svg]:absolute [&>svg]:left-4 [&>svg]:top-4",
      "[&>svg]:flex [&>svg]:size-[23px] [&>svg]:p-1 [&>svg]:rounded-sm"
    ]
  end

  # Translucent tinted fills with visible borders and matching badge chips,
  # mapping the source's surface-200/25 / destructive-200/400 / warning-200/400
  # formula onto the Polaris tokens.
  defp variant_classes("default") do
    [
      "bg-surface-panel/40 border-surface-border",
      "[&>svg]:bg-content-primary [&>svg]:text-surface-ground"
    ]
  end

  defp variant_classes("destructive") do
    [
      "bg-danger-muted border-danger-border",
      "[&>svg]:bg-danger [&>svg]:text-surface-ground"
    ]
  end

  defp variant_classes("warning") do
    [
      "bg-warning-muted border-warning-border",
      "[&>svg]:bg-warning [&>svg]:text-surface-ground"
    ]
  end
end
