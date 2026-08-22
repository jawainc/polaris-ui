defmodule PolarisUI.Components.FormItemLayout do
  @moduledoc """
  The Polaris form item layout: the layout engine for one form field —
  label, optional marker, control, validation message, and hint text
  arranged across the Supabase layout variants.

  Port of the Supabase design system fragment
  `ui-patterns/form/FormItemLayout` (there a thin wrapper over
  `FormLayout`, with react-hook-form context providing the error). Here
  the error arrives as a plain `error` assign — your form layer decides
  what "invalid" means.

  ## Anatomy

      <.form_item_layout
        id="username"
        label="Username"
        label_optional="optional"
        description="This is your public display name"
      >
        <input id="username" class="..." />
      </.form_item_layout>

    * **label** — a real `<label for>` wrapping the optional
      `before_label` / `after_label` slots (e.g. an `<.info_tooltip>`),
      the label text, and — on its own row for the stacked layouts — the
      `label_optional` marker. The label turns danger-red while `error`
      is set, matching the fragment's `FormLabel`.
    * **content** — the inner block (your control), in a data container
      whose geometry follows `layout`.
    * **error** — the validation message under the control (`text-sm`
      danger), rendered *before* the description like the fragment.
      Suppressed entirely with `hide_message`.
    * **description** — the hint text, constraints-first.

  ## Layouts

  | `layout` | Arrangement | Use for |
  |---|---|---|
  | `vertical` (default) | label row above, control below | dialogs and narrow forms |
  | `horizontal` | stacked on small screens, then a 12-col grid — label `col-span-4`, content `col-span-8` from `md:` | forms inside side panels and sheets |
  | `flex` | control and label share one row (`gap-3`), description + error under the label | switches and checkboxes |
  | `flex-row-reverse` | label column left, control column right-aligned (`md:w-1/2` / `xl:w-2/5`), stacking reversed on mobile | dashboard settings pages |

  With `layout="horizontal"`, `container_responsive` swaps the `md:`
  viewport breakpoint for `@xl:` container queries, so the split reacts
  to the nearest `@container` ancestor (e.g. next to a sidebar) instead
  of the viewport. The ancestor must carry `@container`.

  `align="right"` flips the content order/text alignment; on `flex` it
  moves the label to the far side.

  ## Sizing

  `size` scales all text: `tiny` (`text-xs`), `small`
  (`text-base md:text-sm leading-4`), `medium` (the default,
  `text-base md:text-sm`), `large` / `xlarge` (`text-base`). The control
  itself is not resized — size your input to match.

  ## Spacing non-box controls

  `non_box_input` adds vertical margin when the control has no box
  chrome of its own (switches, checkboxes, radios) *and* a label exists —
  the default is derived (`no label` → `true`), matching the fragment.

  ## Accessibility

    * The label is a real `<label>` with `for={name || id}` — give the
      control the same `id` (or pass `name` matching the control's id).
    * With `id` set, the description renders as
      `id="<id>-description"` and the message as `id="<id>-message"` —
      wire them onto your control via
      `aria-describedby="<id>-description <id>-message"` and
      `aria-invalid="true"` when invalid, which is what the fragment's
      `FormControl` automates in React.
    * Every section carries a `data-formlayout-id` attribute, matching
      the fragment's DOM contract for integration testing.

  ## Microcopy

  Per the Supabase copywriting guidelines: labels describe the field
  ("Table name", never "Name your table"); descriptions state
  constraints ("Letters, numbers, and underscores only"); errors say
  what went wrong and how to fix it ("Table name already exists. Choose
  a different name."); `label_optional` is lowercase ("optional").

  Purely presentational — no colocated hook and no client state.
  """

  use PolarisUI.Component

  @layouts ~w(vertical horizontal flex flex-row-reverse)
  @alignments ~w(left right)
  @sizes ~w(tiny small medium large xlarge)

  attr(:label, :string,
    default: nil,
    doc: "The field label — describe the field (\"Table name\"), never the feature."
  )

  attr(:label_optional, :string,
    default: nil,
    doc: "Muted marker beside/below the label — keep it lowercase (\"optional\")."
  )

  attr(:description, :string,
    default: nil,
    doc:
      "Hint text under the control (under the label for `flex` layouts) — constraints, not concepts."
  )

  attr(:error, :string,
    default: nil,
    doc: "Validation message — what went wrong and how to fix it. Turns the label red."
  )

  attr(:layout, :string,
    values: @layouts,
    default: "vertical",
    doc: """
    Arrangement: `vertical` stacks label over control, `horizontal` is the
    responsive 4/8 split grid, `flex` puts control + label on one row,
    `flex-row-reverse` is the dashboard settings layout.
    """
  )

  attr(:align, :string,
    values: @alignments,
    default: "left",
    doc: "Content order/alignment — `right` flips the content column."
  )

  attr(:size, :string,
    values: @sizes,
    default: "medium",
    doc: "Text scale for label, description, and message (the control keeps its own size)."
  )

  attr(:container_responsive, :boolean,
    default: false,
    doc: """
    With `layout=\"horizontal\"`: switch at the nearest `@container`
    ancestor's width (`@xl:`) instead of the viewport (`md:`) — for forms
    in narrow columns. The ancestor must carry `@container`.
    """
  )

  attr(:hide_message, :boolean,
    default: false,
    doc: "Suppress the error message entirely (e.g. nested checkbox-list rows)."
  )

  attr(:non_box_input, :boolean,
    default: nil,
    doc: """
    Vertical margin for box-less controls (switch/checkbox) alongside a
    label. Defaults to derived (`true` when there is no label), like the
    fragment's `nonBoxInput = !label`.
    """
  )

  attr(:id, :string,
    default: nil,
    doc: """
    Root id — derives the label/description/message wiring ids
    (`<id>-description`, `<id>-message`). Pass the same id to your control
    so the `<label for>` connects.
    """
  )

  attr(:name, :string,
    default: nil,
    doc: "Falls back as the label's `for` target (use when the control's id is its name)."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  slot(:before_label,
    doc: "Content before the label text (e.g. `<.info_tooltip>`) — rendered inside the label."
  )

  slot(:after_label,
    doc:
      "Content after the label text (e.g. an `<.info_tooltip>` or badge) — rendered inside the label."
  )

  slot(:inner_block, required: true, doc: "The form control.")

  def form_item_layout(assigns) do
    validate_in!(:layout, assigns.layout, @layouts)
    validate_in!(:align, assigns.align, @alignments)
    validate_in!(:size, assigns.size, @sizes)

    flex? = assigns.layout in ~w(flex flex-row-reverse)
    has_before_label? = slot_content?(assigns.before_label, assigns)
    has_after_label? = slot_content?(assigns.after_label, assigns)

    has_label? =
      (not is_nil(assigns.label) and assigns.label != "") or has_before_label? or has_after_label?

    # The label column renders when anything label-ish exists — horizontal
    # always shows it (keeps the 4/8 grid aligned), like the fragment.
    show_label_section? =
      has_label? or not is_nil(assigns.label_optional) or assigns.layout == "horizontal"

    show_error? = not is_nil(assigns.error) and assigns.error != "" and not assigns.hide_message

    # non_box_input defaults to !has_label, explicit values win (the
    # fragment's `nonBoxInput = !label` default).
    non_box_input? =
      case Map.get(assigns, :non_box_input) do
        nil -> not has_label?
        explicit -> explicit
      end

    assigns =
      assigns
      |> assign(
        flex?: flex?,
        has_before_label?: has_before_label?,
        has_after_label?: has_after_label?,
        has_label?: has_label?,
        show_label_section?: show_label_section?,
        show_error?: show_error?,
        non_box_input?: non_box_input?,
        label_for: assigns.name || assigns.id,
        container_classes:
          cn([
            "relative",
            size_classes(assigns.size),
            container_layout_classes(assigns.layout, assigns.align, assigns.container_responsive),
            assigns.class
          ]),
        label_container_classes: label_container_classes(assigns.layout, assigns.align),
        flex_container_classes: flex_container_classes(assigns.layout, assigns.align),
        data_container_classes: data_container_classes(assigns.layout, assigns.align),
        non_box_classes: non_box_classes(non_box_input?, has_label?, assigns.layout),
        description_classes: description_classes(assigns.size, assigns.layout),
        label_classes:
          cn([
            "flex flex-wrap items-center gap-2 break-words leading-normal text-content-primary",
            "transition-colors",
            if(show_error?, do: "text-danger")
          ])
      )

    ~H"""
    <div class={@container_classes} data-polaris-form-item-layout {@rest}>
      <%= if @flex? do %>
        <div class={@flex_container_classes} data-formlayout-id="dataContainer">
          {render_slot(@inner_block)}
          <%= if @layout == "flex-row-reverse" do %>
            <.error_message error={@error} show_error={@show_error?} mt={false} id={@id} />
          <% end %>
        </div>
      <% end %>
      <div
        :if={@show_label_section?}
        class={@label_container_classes}
        data-formlayout-id="labelContainer"
      >
        <label for={@label_for} class={@label_classes} data-formlayout-id="label">
          <span
            :if={@has_before_label?}
            id={@id && "#{@id}-before"}
            class="text-content-muted"
            data-formlayout-id="beforeLabel"
          >
            {render_slot(@before_label)}
          </span>
          <span>{@label}</span>
          <span
            :if={@has_after_label?}
            id={@id && "#{@id}-after"}
            class="text-content-muted"
            data-formlayout-id="afterLabel"
          >
            {render_slot(@after_label)}
          </span>
        </label>
        <span
          :if={@label_optional}
          id={@id && "#{@id}-optional"}
          class="text-content-muted"
          data-formlayout-id="labelOptional"
        >
          {@label_optional}
        </span>
        <%= if @flex? do %>
          <.description
            description={@description}
            classes={@description_classes}
            id={@id && "#{@id}-description"}
          />
          <%= if @layout != "flex-row-reverse" do %>
            <.error_message error={@error} show_error={@show_error?} mt={true} id={@id} />
          <% end %>
        <% end %>
      </div>
      <%= if not @flex? do %>
        <div class={@data_container_classes} data-formlayout-id="dataContainer">
          <div class={@non_box_classes} data-formlayout-id="nonBoxInputContainer">
            {render_slot(@inner_block)}
          </div>
          <.error_message error={@error} show_error={@show_error?} mt={true} id={@id} />
          <.description
            description={@description}
            classes={@description_classes}
            id={@id && "#{@id}-description"}
          />
        </div>
      <% end %>
    </div>
    """
  end

  attr(:error, :string, default: nil)
  attr(:show_error, :boolean, default: false)
  attr(:mt, :boolean, default: true, doc: "mt-2 except inside flex-row-reverse content")
  attr(:id, :string, default: nil)

  defp error_message(assigns) do
    ~H"""
    <p
      :if={@show_error}
      id={@id && "#{@id}-message"}
      class={
        cn([
          "text-sm text-danger transition-all duration-300 ease-in-out",
          if(@mt, do: "mt-2")
        ])
      }
      data-formlayout-id="message"
    >
      {@error}
    </p>
    """
  end

  attr(:description, :string, default: nil)
  attr(:classes, :string, default: nil)
  attr(:id, :string, default: nil)

  defp description(assigns) do
    ~H"""
    <div :if={@description} id={@id} class={@classes} data-formlayout-id="description">
      {@description}
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

  # SIZE.text from the Supabase constants.
  defp size_classes("tiny"), do: "text-xs"
  defp size_classes("small"), do: "text-base leading-4 md:text-sm"
  defp size_classes("medium"), do: "text-base md:text-sm"
  defp size_classes("large"), do: "text-base"
  defp size_classes("xlarge"), do: "text-base"

  # ContainerVariants: the stacked baseline plus per-layout arrangement.
  # `horizontal` compounds to a 12-col grid at md (or @xl with a
  # `@container` ancestor when container_responsive).
  defp container_layout_classes("vertical", _align, _responsive), do: "flex flex-col gap-2"

  defp container_layout_classes("horizontal", _align, true),
    do: "flex flex-col gap-2 @xl:grid @xl:grid-cols-12"

  defp container_layout_classes("horizontal", _align, false),
    do: "flex flex-col gap-2 md:grid md:grid-cols-12"

  defp container_layout_classes("flex", "right", _), do: "flex flex-row justify-between gap-3"
  defp container_layout_classes("flex", _left, _), do: "flex flex-row gap-3"

  defp container_layout_classes("flex-row-reverse", "right", _),
    do:
      "flex flex-col-reverse justify-between gap-2 md:flex-row-reverse md:justify-between md:gap-6"

  defp container_layout_classes("flex-row-reverse", _left, _),
    do: "flex flex-col-reverse gap-2 md:flex-row-reverse md:justify-between md:gap-6"

  # LabelContainerVariants: label column geometry per layout, with the
  # flex order compounds for the shared-row layouts.
  defp label_container_classes("horizontal", _align),
    do: "col-span-4 flex flex-col gap-2 transition-all duration-500 ease-in-out"

  defp label_container_classes("vertical", _align),
    do: "flex flex-row justify-between gap-2 transition-all duration-500 ease-in-out"

  defp label_container_classes("flex", "left"),
    do: "order-2 flex min-w-0 flex-col gap-0 transition-all duration-500 ease-in-out"

  defp label_container_classes("flex", "right"),
    do: "order-1 flex min-w-0 flex-col gap-0 transition-all duration-500 ease-in-out"

  defp label_container_classes("flex-row-reverse", _align),
    do: "flex min-w-0 grow flex-col transition-all duration-500 ease-in-out"

  # FlexContainer: geometry of the content column for the shared-row
  # layouts (children render here instead of the data container).
  defp flex_container_classes("flex", "right"), do: "order-last"
  defp flex_container_classes("flex", _left), do: nil

  defp flex_container_classes("flex-row-reverse", _align) do
    "flex shrink-0 flex-col items-start justify-center md:w-1/2 md:items-end xl:w-2/5 [&>div]:md:w-full"
  end

  defp flex_container_classes(_stacked_layout, _align), do: nil

  # DataContainerVariants: the 8-of-12 content column for the stacked
  # layouts (order compounds from align), full-width for vertical.
  defp data_container_classes("vertical", "left"), do: "order-1 col-span-12"
  defp data_container_classes("vertical", "right"), do: "order-2 col-span-12"
  defp data_container_classes("horizontal", "left"), do: "order-1 col-span-8"
  defp data_container_classes("horizontal", "right"), do: "order-2 col-span-8 text-right"
  defp data_container_classes(_flex_layout, _align), do: nil

  # NonBoxInputContainer: breathing room for box-less controls that sit
  # under a label (switches, checkboxes).
  defp non_box_classes(true, true, "vertical"), do: "my-3"
  defp non_box_classes(true, true, "horizontal"), do: "my-3 mb-3 md:mt-0"
  defp non_box_classes(_non_box, _has_label, _layout), do: nil

  # DescriptionVariants: muted hint text at the field's text scale,
  # tucked under the control on the stacked layouts.
  defp description_classes(size, layout) do
    cn([
      "leading-normal text-content-secondary",
      size_classes(size),
      if(layout in ~w(vertical horizontal), do: "mt-2")
    ])
  end
end
