defmodule PolarisUI.Components.Separator do
  @moduledoc """
  The Polaris separator: the hairline that visually or semantically
  divides content — the port of the Supabase design system Separator
  (`packages/ui`, built on the Radix Separator primitive).

  ## Anatomy

      <.separator class="my-4" />

      <div class="flex h-5 items-center gap-4 text-sm">
        <span>Blog</span>
        <.separator orientation="vertical" />
        <span>Docs</span>
        <.separator orientation="vertical" />
        <span>Source</span>
      </div>

  A plain `<div>` — one pixel of `bg-surface-border` (the source's
  `bg-border-muted`, a compat alias of its base `--border` token):
  `h-px w-full` horizontal (the default), `h-full w-px` vertical. A
  vertical separator takes its height from the container, so it wants a
  sized flex parent (the source demo's `flex h-5 items-center`).

  ## Semantics

  Like the source, `decorative` defaults to `true`: the divider is
  purely visual — `role="none"` and no `aria-orientation`, removed from
  the accessibility tree. Pass `decorative={false}` for a semantic
  separator: `role="separator"` plus `aria-orientation="vertical"` —
  but only when vertical, since horizontal is the ARIA default for the
  role. `data-orientation` is always rendered either way.

  ## Microcopy

  None — the separator is silent chrome between labeled content.

  No hook is needed; the component is fully presentational.
  """

  use PolarisUI.Component

  @orientations ~w(horizontal vertical)

  attr(:orientation, :string,
    values: @orientations,
    default: "horizontal",
    doc: "Which axis the hairline runs along — vertical separators size from their container."
  )

  attr(:decorative, :boolean,
    default: true,
    doc: """
    `true` (the source default) renders pure chrome — `role="none"`.
    `false` renders a semantic `role="separator"` (with
    `aria-orientation` when vertical).
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the hairline.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `aria-*`, `phx-*`, …")

  def separator(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)

    assigns =
      assign(assigns, :orientation_classes, orientation_classes(assigns.orientation))

    ~H"""
    <div
      data-polaris-separator
      data-orientation={@orientation}
      role={if(@decorative, do: :none, else: :separator)}
      aria-orientation={if(!@decorative && @orientation == "vertical", do: "vertical")}
      class={cn(["shrink-0 bg-surface-border", @orientation_classes, @class])}
      {@rest}
    />
    """
  end

  # The source sizes via a ternary rather than data-[orientation]
  # variants — same result.
  defp orientation_classes("horizontal"), do: "h-px w-full"
  defp orientation_classes("vertical"), do: "h-full w-px"

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
