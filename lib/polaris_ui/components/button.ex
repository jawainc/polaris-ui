defmodule PolarisUI.Components.Button do
  @moduledoc """
  The Polaris button: an interactive `<button>`, or an `<a>` styled as a
  button when `href` is given (the LiveView equivalent of the Supabase
  `asChild` / `buttonVariants` pattern).

  Styling mirrors the Supabase design system button (`packages/ui`): muted
  brand fills with visible brand borders (the bright emerald is reserved for
  icons, spinners, and link text), regular font weight, and a 26–50px size
  scale.

  ## Variants

  | Variant     | Appearance                                     | Use for                                                             |
  |-------------|------------------------------------------------|---------------------------------------------------------------------|
  | `primary`   | Muted emerald fill + brand border, white text  | Strong positive data actions — CRUD insertion, confirming purchases |
  | `default`   | Panel surface + strong border                  | Opening dialogs, navigating, general non-CRUD actions (the default) |
  | `secondary` | Inverted: bright surface fill, dark text       | Secondary emphasis actions                                          |
  | `warning`   | Amber tint fill + amber border                 | Disruptive-but-recoverable actions                                  |
  | `danger`    | Red tint fill + red border                     | Destructive operations — resource deletion, access revocation       |
  | `outline`   | Transparent + strong border, no fill           | Low-emphasis actions in dense layouts                               |
  | `ghost`     | Transparent, fills on hover                    | Toolbars and tertiary actions                                       |
  | `link`      | Emerald text button, fills emerald-deep on hover | Inline in-text actions                                            |

  ## Sizes

  Heights follow Supabase exactly: `tiny` 26px (dense tables, inline
  toolbars) · `small` 34px · `medium` 38px (the baseline) · `large` 42px
  (prominent CTAs) · `huge` 50px (hero / marketing CTAs). Slotted SVG icons
  auto-size 14/18/20/20/24px per size.

  ## States

    * **rest / hover** — pure CSS (`transition-colors`, 200ms ease-out).
    * **focus-ring** — a high-visibility emerald ring with offset, applied on
      `:focus-visible` only, so keyboard navigation is obvious but pointer
      clicks stay clean.
    * **loading** — replaces the leading icon with a spinner (tinted per
      variant), sets `aria-busy="true"`, and locks interaction: the button
      renders `disabled` with the disabled styling (50% opacity), exactly
      like the Supabase component. The label stays visible.
    * **disabled** — 50% opacity, `cursor-not-allowed`, pointer events off,
      and `tabindex="-1"` so disabled buttons drop out of the tab order.
      A caller-provided `tabindex` always wins.

  ## Icons

      <.button>
        <:icon><svg data-icon="plus" /></:icon>
        Create table
        <:icon_right><svg data-icon="chevron-right" /></:icon_right>
      </.button>

  Icons are tinted per variant (emerald accent on `primary`, red on
  `danger`, …) and auto-sized for the chosen `size` via `[&_svg]:size-*`.
  An icon-only button (no `inner_block`) renders square and requires an
  `aria-label` (or `aria-labelledby`) for an accessible name.

  ## Microcopy

  Per the Supabase copywriting guidelines, button text uses direct verbs:
  "Create table", "Revoke access", "Delete project" — never "Submit" or "OK".

  ## Link buttons

  With `href`, the component renders an anchor carrying the exact same
  variant classes. LiveView navigation attributes (`phx-click`, `data-*`,
  …) pass through `rest` as usual:

      <.button variant="primary" href="/new">Start your project</.button>

  Disabled link buttons carry `aria-disabled="true"` plus
  `pointer-events-none`, since anchors have no native `disabled`.

  No colocated hook is required: every state is CSS- or server-driven.
  """

  use PolarisUI.Component

  @variants ~w(primary default secondary warning danger outline ghost link)
  @sizes ~w(tiny small medium large huge)

  attr(:variant, :string,
    values: @variants,
    default: "default",
    doc: """
    Visual style. `"default"` (panel surface + border) is the workhorse;
    `"primary"` is reserved for strong positive actions.
    """
  )

  attr(:size, :string,
    values: @sizes,
    default: "medium",
    doc: "Height / padding / text scale (26/34/38/42/50px). `medium` is the baseline."
  )

  attr(:type, :string,
    values: ~w(button submit reset),
    default: "button",
    doc: "HTML `type` for button rendering (ignored when `href` is set)."
  )

  attr(:loading, :boolean,
    default: false,
    doc: "Replaces the leading icon with a spinner, sets `aria-busy`, locks interaction."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Dims to 50% opacity, disables pointer events, removes from tab order."
  )

  attr(:href, :string,
    default: nil,
    doc: "Render an `<a>` styled as a button instead of a `<button>`."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged last — caller classes win conflicts via `cn/1`."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the underlying `<button>`/`<a>`: `id`, `name`, `form`,
    `aria-*`, `data-*`, `phx-click`, `phx-*`, …
    """
  )

  slot(:icon,
    doc: "Leading icon (e.g. a Lucide-style inline SVG). Replaced by the spinner while loading."
  )

  slot(:icon_left, doc: "Alias for `icon` — also renders as the leading icon.")

  slot(:icon_right, doc: "Trailing icon, rendered after the label.")

  slot(:inner_block, doc: "Button label. Omit for icon-only buttons (then pass `aria-label`).")

  def button(assigns) do
    validate_in!(:variant, assigns.variant, @variants)
    validate_in!(:size, assigns.size, @sizes)

    # LV creates an inner_block even when the do-block holds only <:icon>
    # entries (its content is then whitespace), so blank-render is the only
    # reliable signal for icon-only buttons.
    icon_only? = not has_label_content?(assigns.inner_block)

    if icon_only? and not Map.has_key?(assigns.rest, :"aria-label") and
         not Map.has_key?(assigns.rest, :"aria-labelledby") do
      raise ArgumentError, """
      PolarisUI button: a button without label content (e.g. an icon-only \
      button) needs an accessible name — pass aria-label or aria-labelledby \
      through the global attributes.
      """
    end

    locked? = assigns.disabled or assigns.loading

    tabindex =
      cond do
        Map.has_key?(assigns.rest, :tabindex) -> nil
        locked? -> "-1"
        true -> nil
      end

    size =
      assigns.size
      |> size_classes()
      |> Kernel.++(if icon_only?, do: ["aspect-square p-0"], else: [])

    classes =
      cn([
        base_classes(),
        size,
        variant_classes(assigns.variant),
        state_classes(locked?),
        assigns.class
      ])

    assigns =
      assign(assigns,
        classes: classes,
        locked?: locked?,
        tabindex: tabindex,
        icon_tint: icon_tint_classes(assigns.variant),
        spinner_tint: spinner_tint_classes(assigns.variant)
      )

    ~H"""
    <button
      :if={is_nil(@href)}
      type={@type}
      class={@classes}
      disabled={@locked?}
      aria-busy={@loading && "true"}
      tabindex={@tabindex}
      {@rest}
    >
      <%= if @loading do %>
        <.spinner tint={@spinner_tint} />
      <% else %>
        <.icon_slot tint={@icon_tint}>{render_slot(@icon)}{render_slot(@icon_left)}</.icon_slot>
      <% end %>
      <span :if={@inner_block != []} class="truncate">{render_slot(@inner_block)}</span>
      <.icon_slot :if={not @loading} tint={@icon_tint}>{render_slot(@icon_right)}</.icon_slot>
    </button>
    <a
      :if={is_binary(@href)}
      href={@href}
      class={@classes}
      aria-busy={@loading && "true"}
      aria-disabled={@locked? && "true"}
      tabindex={@tabindex}
      {@rest}
    >
      <%= if @loading do %>
        <.spinner tint={@spinner_tint} />
      <% else %>
        <.icon_slot tint={@icon_tint}>{render_slot(@icon)}{render_slot(@icon_left)}</.icon_slot>
      <% end %>
      <span :if={@inner_block != []} class="truncate">{render_slot(@inner_block)}</span>
      <.icon_slot :if={not @loading} tint={@icon_tint}>{render_slot(@icon_right)}</.icon_slot>
    </a>
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

  # Whitespace-only inner content (e.g. formatting around a <:icon> slot)
  # still counts as "no label" for icon-only rendering and a11y checks.
  # `render_slot/1` only works inside templates, so the slot's Rendered
  # struct is rendered directly instead.
  defp has_label_content?([]), do: false

  defp has_label_content?(slots) do
    slots
    |> Enum.any?(fn entry ->
      entry.inner_block
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()
      |> String.trim() != ""
    end)
  end

  defp base_classes do
    [
      "relative inline-flex cursor-pointer select-none items-center justify-center gap-2",
      "whitespace-nowrap rounded-md border text-center font-normal",
      "transition-colors ease-out duration-200",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
      "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    ]
  end

  # Heights/padding/text/icon sizes mirror the Supabase SIZE_VARIANTS:
  # 26/34/38/42/50px with 14/18/20/20/24px icons.
  defp size_classes("tiny"),
    do: ["h-[26px] px-2.5 py-1 text-xs [&_svg]:size-3.5"]

  defp size_classes("small"),
    do: ["h-[34px] px-3 py-2 text-sm [&_svg]:size-4.5"]

  defp size_classes("medium"),
    do: ["h-[38px] px-4 py-2 text-sm [&_svg]:size-5"]

  defp size_classes("large"),
    do: ["h-[42px] px-4 py-2 text-base [&_svg]:size-5"]

  defp size_classes("huge"),
    do: ["h-[50px] px-6 py-3 text-base [&_svg]:size-6"]

  defp variant_classes("primary"),
    do: [
      "bg-brand-fill text-content-primary border-brand-border",
      "hover:bg-brand-fill-hover hover:border-brand-border-hover"
    ]

  defp variant_classes("default"),
    do: [
      "bg-surface-panel text-content-primary border-surface-border",
      "hover:bg-surface-panel-hover hover:border-surface-border-hover"
    ]

  # Secondary inverts: bright fill with dark text (Supabase `bg-foreground`).
  defp variant_classes("secondary"),
    do: [
      "bg-content-primary text-surface-ground border-content-primary/40",
      "hover:text-surface-ground/80 hover:border-content-primary/60"
    ]

  defp variant_classes("warning"),
    do: [
      "bg-warning-fill text-content-primary border-warning-border",
      "hover:bg-warning-fill-hover hover:border-warning-border-hover"
    ]

  defp variant_classes("danger"),
    do: [
      "bg-danger-fill text-content-primary border-danger-border",
      "hover:bg-danger-fill-hover hover:border-danger-border-hover"
    ]

  defp variant_classes("outline"),
    do: [
      "bg-transparent text-content-primary border-surface-border",
      "hover:border-content-secondary"
    ]

  defp variant_classes("ghost"),
    do: "border-transparent bg-transparent text-content-primary hover:bg-content-primary/10"

  # Link keeps button chrome: emerald text that fills deep emerald on hover.
  defp variant_classes("link"),
    do: "border-transparent bg-transparent text-brand-accent hover:bg-brand-deep"

  # Supabase tints icons and the loading spinner per variant.
  defp icon_tint_classes("primary"), do: "text-brand-accent"
  defp icon_tint_classes("secondary"), do: "text-surface-ground"
  defp icon_tint_classes("link"), do: "text-brand-accent"
  defp icon_tint_classes("danger"), do: "text-danger"
  defp icon_tint_classes("warning"), do: "text-warning"
  defp icon_tint_classes(_), do: "text-content-secondary"

  defp spinner_tint_classes("primary"), do: "text-brand-accent"
  defp spinner_tint_classes("secondary"), do: "text-surface-ground"
  defp spinner_tint_classes("danger"), do: "text-danger"
  defp spinner_tint_classes("warning"), do: "text-warning"
  defp spinner_tint_classes(_), do: "text-content-secondary"

  # Loading locks interaction exactly like disabled in the Supabase component
  # (`disabled: true` → opacity-50, cursor-not-allowed, pointer-events-none).
  defp state_classes(true), do: "pointer-events-none cursor-not-allowed opacity-50"
  defp state_classes(false), do: nil

  attr(:tint, :string, default: nil, doc: "variant tint applied to the icon")
  slot(:inner_block, doc: "the icon markup")

  defp icon_slot(assigns) do
    ~H"""
    <span class={cn(["inline-flex shrink-0 items-center justify-center", @tint])}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr(:tint, :string, default: nil, doc: "variant tint applied to the spinner")

  defp spinner(assigns) do
    ~H"""
    <svg
      class={cn(["animate-spin", @tint])}
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      data-polaris-spinner
    >
      <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" opacity="0.2" />
      <path
        d="M22 12a10 10 0 0 0-10-10"
        stroke="currentColor"
        stroke-width="3"
        stroke-linecap="round"
      />
    </svg>
    """
  end
end
