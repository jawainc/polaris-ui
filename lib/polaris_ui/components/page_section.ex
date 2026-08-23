defmodule PolarisUI.Components.PageSection do
  @moduledoc """
  The Polaris page section: a titled block of page content under the page
  header — the port of the Supabase design system fragment
  `ui-patterns/PageSection`.

  Reach for sections when a page has multiple distinct blocks of content:
  header titles describe the page, section titles describe a distinct
  block of content on that page. The component renders the meta row
  (title, optional description, optional aside actions) followed by the
  section body. The root pads every section with `pt-12` and drops the
  trailing gap via `last:pb-12`, so a run of sections breathes evenly.

  The React fragment is a composable family (Root / Meta / Summary /
  Title / Description / Aside / Content) that wires its layout through
  CSS child selectors keyed on `data-slot` markers. LiveView knows the
  whole arrangement at render time, so this port collapses the family
  into a single component and applies those rules server-side — the
  summary centers against the aside only when no description is present,
  for instance.

  ## Anatomy

      <.page_section
        title="Connections"
        description="External services this project talks to."
      >
        <:aside>
          <button type="button" phx-click="new-connection">New connection</button>
        </:aside>
        <div class="rounded-lg border border-surface-border p-6">
          Section content
        </div>
      </.page_section>

    * **root** — the section `div`: `pt-12 last:pb-12 gap-6` in both
      orientations, plus the orientation layout (`flex flex-col`, or
      `grid` splitting meta from content `1fr`/`2fr` at `@3xl`).
    * **meta row** — an `@container` wrapper (so the row adapts to the
      section's own width, not the viewport) around the summary/aside
      row: stacks on narrow sections, spreads (`@xl:flex-row
      @xl:justify-between @xl:items-center`) once wide enough.
    * **summary** — the `<h2>` title over the optional description,
      stacked `gap-1`; flexes (`@xl:flex-1`) so the aside lands at the
      trailing edge.
    * **aside** — section-level actions (`flex items-center gap-2`),
      held at size (`shrink-0`) and aligned to the bottom of the
      description (`@xl:self-end`).
    * **content** — the inner block in a plain wrapper `div` (no default
      classes, like the fragment's Content), omitted entirely when the
      block renders blank.

  ## Orientations

  | Orientation  | Layout                                                            |
  |--------------|-------------------------------------------------------------------|
  | `vertical`   | meta row above content, one column (the default)                  |
  | `horizontal` | meta left, content right (`@3xl:grid-cols-[1fr_2fr] @3xl:gap-12`) |

  `horizontal` suits detail-heavy sections whose context should stay
  visible while the content scrolls; it still stacks below `@3xl`.

  ## States

  None — the section is pure layout and renders no interactive element
  of its own. Hover and focus states belong to the caller's aside
  controls; there is nothing to load or disable.

  ## Microcopy

  The `title` is a noun phrase naming the block ("Connections", "Danger
  zone"), never a verb. The `description` is one short sentence of
  context and should be omitted when the title alone suffices — per the
  Supabase copywriting guidance, a section title earns its description
  only when the content needs context the title doesn't provide.

  ## Accessibility

    * The title is a real `<h2>` — one per section, one level below the
      `page_header`'s `<h1>`; keep every section on the page at the same
      heading level and don't skip.
    * Document order is visual order: the meta row renders before the
      content, the summary before the aside.
    * The aside is a plain `div`; whatever landmarks or labeling its
      slotted controls carry is up to the caller.

  Presentational only — no states, no events, no hook.
  """

  use PolarisUI.Component

  @orientations ~w(vertical horizontal)

  attr(:title, :string,
    required: true,
    doc: """
    The section heading — a noun phrase naming the block, rendered as
    the section's `<h2>`.
    """
  )

  attr(:description, :string,
    default: nil,
    doc: """
    Optional supporting sentence rendered under the title — omit it
    when the title alone suffices.
    """
  )

  attr(:orientation, :string,
    values: @orientations,
    default: "vertical",
    doc: """
    `vertical` (default) stacks the meta row above the content;
    `horizontal` puts meta left of content on `@3xl` containers
    (`grid-cols-[1fr_2fr]`), stacking below.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root — caller classes win via `cn/1`."
  )

  attr(:title_class, :string, default: nil, doc: "Additional classes merged onto the `<h2>`.")

  attr(:description_class, :string,
    default: nil,
    doc: "Additional classes merged onto the description."
  )

  attr(:aside_class, :string,
    default: nil,
    doc: "Additional classes merged onto the aside actions container."
  )

  attr(:content_class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the content wrapper — it carries no
    default classes of its own.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `id`, `data-*`, `phx-*`, …")

  slot(:aside,
    doc: """
    Section-level actions — buttons, dropdowns — aligned with the bottom
    of the description. Rendered only when the slot has content.
    """
  )

  slot(:inner_block,
    doc: """
    The section content. The wrapper `div` (and its marker) is omitted
    entirely when the block renders blank.
    """
  )

  def page_section(assigns) do
    # LV creates an inner_block even when the do-block is empty, so
    # blank-render is the reliable signal for the content wrapper.
    has_content? = slot_content?(assigns.inner_block, assigns)
    has_aside? = slot_content?(assigns.aside, assigns)

    # The React meta centers the summary against the aside via a CSS
    # child selector; the arrangement is known at render time here, so
    # the class is applied only when no description is present.
    summary_align = if is_nil(assigns.description), do: "@xl:self-center"

    assigns =
      assigns
      |> assign(
        has_aside?: has_aside?,
        has_content?: has_content?,
        root_classes:
          cn(["pt-12 last:pb-12 gap-6", orientation_classes(assigns.orientation), assigns.class]),
        summary_classes: cn(["flex flex-col gap-1 @xl:flex-1", summary_align]),
        title_classes: cn(["text-xl text-content-primary", assigns.title_class]),
        description_classes: cn(["text-sm text-content-secondary", assigns.description_class]),
        aside_classes: cn(["flex shrink-0 items-center gap-2 @xl:self-end", assigns.aside_class]),
        # No default classes to merge with — HEEx renders class="" when
        # the caller passes nothing (the fragment's Content is bare too).
        content_classes: cn([assigns.content_class])
      )

    ~H"""
    <div
      class={@root_classes}
      data-polaris-page-section
      data-orientation={@orientation}
      {@rest}
    >
      <div class="@container">
        <div class="flex flex-col @xl:flex-row @xl:justify-between @xl:items-center gap-4">
          <div class={@summary_classes} data-polaris-page-section-summary>
            <h2 class={@title_classes} data-polaris-page-section-title>
              {@title}
            </h2>
            <div
              :if={@description}
              class={@description_classes}
              data-polaris-page-section-description
            >
              {@description}
            </div>
          </div>
          <div :if={@has_aside?} class={@aside_classes} data-polaris-page-section-aside>
            {render_slot(@aside)}
          </div>
        </div>
      </div>
      <div :if={@has_content?} class={@content_classes} data-polaris-page-section-content>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp orientation_classes("vertical"), do: "flex flex-col"
  defp orientation_classes("horizontal"), do: "grid @3xl:grid-cols-[1fr_2fr] @3xl:gap-12"
end
