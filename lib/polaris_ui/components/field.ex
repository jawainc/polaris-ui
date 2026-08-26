defmodule PolarisUI.Components.Field do
  @moduledoc """
  The Polaris field: the presentational anatomy for one form field —
  set, legend, group, field, label, content, description, separator,
  and error — the port of the Supabase design system Field
  (`packages/ui`, `field.tsx`).

  Field is purely structural: it generates no ids and wires no
  `aria-describedby` — label↔control association is by explicit
  `for`/`id`, exactly like the source. For the changeset-driven
  equivalent that wires ids and aria automatically, use the Form
  family (`PolarisUI.Components.Form`); for the Studio layout engine
  (label columns, `flex-row-reverse` dashboard rows), the
  `form_item_layout` fragment.

  ## Anatomy

      <.field_set>
        <.field_legend>Profile</.field_legend>
        <.field_description>This appears on invoices and emails.</.field_description>
        <.field_group>
          <.field>
            <.field_label for="name">Full name</.field_label>
            <input id="name" autocomplete="off" placeholder="Evil Rabbit" class="..." />
            <.field_description>This appears on invoices and emails.</.field_description>
          </.field>
          <.field invalid>
            <.field_label for="username">Username</.field_label>
            <input id="username" autocomplete="off" aria-invalid="true" class="..." />
            <.field_error>Choose another username.</.field_error>
          </.field>
          <.field orientation="horizontal">
            <.switch id="newsletter" />
            <.field_label for="newsletter" class="font-normal">Subscribe to the newsletter</.field_label>
          </.field>
        </.field_group>
      </.field_set>

  ## Pieces

    * **`field_set`** — the semantic `<fieldset>` wrapper (gap 7; tightens
      to 3 when it directly contains a checkbox or radio group).
    * **`field_legend`** — the `<legend>` caption; `variant="label"`
      drops it to `text-sm` label scale.
    * **`field_group`** — the column of fields; establishes the
      `@container/field-group` query that `orientation="responsive"`
      switches on.
    * **`field`** — one field's wrapper: `role="group"` with
      `orientation` (`vertical` default / `horizontal` /
      `responsive`), `invalid` (the source's `data-invalid` — turns the
      whole block's text danger), and `disabled` styling hooks.
    * **`field_label`** — a real `<label for>`; wrapping a nested
      `field` inside it builds the source's "choice card" (bordered,
      padded, brand-highlighted while checked).
    * **`field_content`** — the label + description column beside a
      control in horizontal layouts.
    * **`field_title`** — label-styled title for use inside content
      (shares the `field-label` slot so orientation styling treats it
      as the label).
    * **`field_description`** — the hint text; links inside get
      underlined.
    * **`field_separator`** — a hairline with an optional centered
      content chip ("Or continue with").
    * **`field_error`** — the validation message (`role="alert"`,
      `text-danger`); renders nothing without content. `errors` accepts
      a list of `%{message: ...}` maps (or binaries) — one renders as
      text, several as a disc list.

  ## Accessibility

    * `field_set`/`field_legend` give semantic grouping; `field`
      renders `role="group"` with `data-orientation`.
    * Invalid state: `invalid` turns the block's text danger and sets
      `data-invalid="true"` — set `aria-invalid="true"` on the control
      itself for assistive tech.
    * `field_error` renders `role="alert"` so it is announced on
      appearance.

  ## Microcopy

  Per the Supabase copywriting guidelines: labels describe the field
  ("Table name", never "Name your table"); descriptions state
  constraints ("This appears on invoices and emails."); errors say what
  went wrong and how to fix it ("Choose another username.").

  Purely presentational — no colocated hook and no client state.
  """

  use PolarisUI.Component

  @orientations ~w(vertical horizontal responsive)
  @legend_variants ~w(legend label)

  @doc """
  The field set: the semantic `<fieldset>` grouping a form section —
  the source's FieldSet (gap tightens when it directly contains a
  checkbox or radio group).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the set.")
  attr(:rest, :global, doc: "Forwarded to the `<fieldset>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The legend and fields.")

  def field_set(assigns) do
    ~H"""
    <fieldset
      data-polaris-field-set
      class={
        cn([
          "flex flex-col gap-6",
          "has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </fieldset>
    """
  end

  @doc """
  The field legend: the `<legend>` caption for a set — the source's
  FieldLegend. `variant="label"` drops it to label scale (`text-sm`).
  """
  attr(:variant, :string,
    values: @legend_variants,
    default: "legend",
    doc: "`legend` renders `text-base`; `label` renders `text-sm`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the legend.")
  attr(:rest, :global, doc: "Forwarded to the `<legend>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The caption — short and plural (\"Profile\").")

  def field_legend(assigns) do
    validate_in!(:variant, assigns.variant, @legend_variants)

    ~H"""
    <legend
      data-polaris-field-legend
      data-variant={@variant}
      class={
        cn([
          "mb-3 font-medium",
          "data-[variant=legend]:text-base",
          "data-[variant=label]:text-sm",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </legend>
    """
  end

  @doc """
  The field group: the column of fields — the source's FieldGroup.
  Establishes the `@container/field-group` query that
  `orientation="responsive"` fields switch on.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-slot`, `data-*`, …")

  slot(:inner_block, required: true, doc: "The fields.")

  def field_group(assigns) do
    ~H"""
    <div
      data-polaris-field-group
      class={
        cn([
          "group/field-group @container/field-group flex w-full flex-col gap-7",
          "data-[slot=checkbox-group]:gap-3 *:data-[slot=field-group]:gap-4",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The field: one form field's wrapper — the source's Field. Orientation
  picks the arrangement; `invalid` turns the whole block's text danger
  (the source's `data-invalid`); disabled styling keys off
  `disabled`.
  """
  attr(:orientation, :string,
    values: @orientations,
    default: "vertical",
    doc: """
    `vertical` stacks label over control, `horizontal` puts them on one
    row (pair with `field_content`), `responsive` switches from vertical
    to horizontal at the group's `@md` container width.
    """
  )

  attr(:invalid, :boolean,
    default: false,
    doc: "Marks the field invalid — the source's `data-invalid`: turns the block's text danger."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Marks the field disabled — dims its label/title (`data-disabled=\"true\"`)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the field.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The label, control, description, and error.")

  def field(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)

    assigns =
      assign(assigns,
        field_classes:
          cn([
            "group/field data-[invalid=true]:text-danger flex w-full gap-3",
            orientation_classes(assigns.orientation),
            assigns.class
          ])
      )

    ~H"""
    <div
      data-polaris-field
      data-slot="field"
      role="group"
      data-orientation={@orientation}
      data-invalid={if(@invalid, do: "true")}
      data-disabled={if(@disabled, do: "true")}
      class={@field_classes}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The field content: the label + description column beside a control
  in horizontal fields — the source's FieldContent.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the content.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The `field_label`/`field_title` and description.")

  def field_content(assigns) do
    ~H"""
    <div
      data-polaris-field-content
      data-slot="field-content"
      class={cn(["group/field-content flex flex-1 flex-col gap-1.5 leading-snug", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The field label: a real `<label for>` — the source's FieldLabel.
  Wrapping a nested `field` inside it builds the "choice card":
  bordered, padded, brand-highlighted while its control is checked.
  """
  attr(:for, :string,
    default: nil,
    doc: "The control's id — always pair it; Field generates no ids itself."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the label.")
  attr(:rest, :global, doc: "Forwarded to the `<label>`: `data-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The label text — describe the field, never the feature."
  )

  def field_label(assigns) do
    ~H"""
    <label
      data-polaris-field-label
      data-slot="field-label"
      for={@for}
      class={
        cn([
          "group/field-label peer/field-label flex w-fit gap-2 text-sm leading-none",
          "leading-snug group-data-[disabled=true]/field:opacity-50",
          "has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col has-[>[data-slot=field]]:rounded-md",
          "has-[>[data-slot=field]]:border has-[>[data-slot=field]]:border-surface-border",
          "*:data-[slot=field]:p-4",
          "has-[:checked]:bg-brand-emerald-muted has-[:checked]:border-brand-border",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  The field title: a label-styled title for use inside `field_content`
  — the source's FieldTitle (shares the `field-label` slot so
  orientation styling treats it as the label).
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the title.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The title text.")

  def field_title(assigns) do
    ~H"""
    <div
      data-polaris-field-title
      data-slot="field-label"
      class={
        cn([
          "flex w-fit items-center gap-2 text-sm font-medium leading-snug",
          "group-data-[disabled=true]/field:opacity-50",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The field description: the hint text — the source's FieldDescription.
  Links inside get underlined.
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the description.")
  attr(:rest, :global, doc: "Forwarded to the `<p>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The hint — constraints, not concepts.")

  def field_description(assigns) do
    ~H"""
    <p
      data-polaris-field-description
      data-slot="field-description"
      class={
        cn([
          "text-content-secondary text-sm font-normal leading-normal",
          "group-has-data-[orientation=horizontal]/field:text-balance",
          "nth-last-2:-mt-1 last:mt-0 [[data-variant=legend]+&]:-mt-1.5",
          "[&>a:hover]:text-brand-emerald [&>a]:underline [&>a]:underline-offset-4",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  The field separator: a hairline with an optional centered content
  chip — the source's FieldSeparator ("Or continue with").
  """
  attr(:class, :string, default: nil, doc: "Additional classes merged onto the separator.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block,
    doc: "Optional centered text breaking the hairline (\"Or continue with\")."
  )

  def field_separator(assigns) do
    assigns =
      assign(assigns, has_content?: slot_content?(assigns.inner_block, assigns))

    ~H"""
    <div
      data-polaris-field-separator
      data-content={to_string(@has_content?)}
      class={
        cn([
          "relative -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2",
          @class
        ])
      }
      {@rest}
    >
      <div
        data-polaris-field-separator-line
        class="absolute inset-0 top-1/2 h-px w-full bg-surface-border"
      />
      <span
        :if={@has_content?}
        data-polaris-field-separator-content
        class="relative mx-auto block w-fit bg-surface-ground px-2 text-content-secondary"
      >
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  @doc """
  The field error: the validation message — the source's FieldError
  (`role="alert"`, danger text). Renders nothing without content:
  pass the message as the inner block, or an `errors` list of
  `%{message: ...}` maps (or binaries) — one renders as text, several
  as a disc list.
  """
  attr(:errors, :list,
    default: nil,
    doc: """
    Validation errors as `%{message: ...}` maps or binaries — the
    shape of Standard Schema `issues` and changeset-derived error
    lists. Ignored when the inner block has content.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the error.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block,
    doc: "The message — what went wrong and how to fix it. Wins over `errors`."
  )

  def field_error(assigns) do
    has_content? = slot_content?(assigns.inner_block, assigns)

    normalized_errors =
      assigns.errors
      |> List.wrap()
      |> Enum.map(&error_message/1)
      |> Enum.reject(&is_nil/1)

    assigns =
      assign(assigns,
        has_content?: has_content?,
        normalized_errors: normalized_errors,
        single_error: Enum.count(normalized_errors) == 1 && List.first(normalized_errors)
      )

    ~H"""
    <div
      :if={@has_content? or @normalized_errors != []}
      data-polaris-field-error
      data-slot="field-error"
      role="alert"
      class={cn(["text-danger text-sm font-normal", @class])}
      {@rest}
    >
      <%= if @has_content? do %>
        {render_slot(@inner_block)}
      <% else %>
        <%= if @single_error do %>
          {@single_error}
        <% else %>
          <ul class="ml-4 flex list-disc flex-col gap-1">
            <li :for={message <- @normalized_errors}>{message}</li>
          </ul>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp error_message(%{message: message}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(_), do: nil

  # FieldVariants: orientation arrangements. `responsive` compounds to a
  # row at the group's @md container width.
  defp orientation_classes("vertical"), do: "flex-col *:w-full [&>.sr-only]:w-auto"

  defp orientation_classes("horizontal") do
    [
      "flex-row items-center",
      "*:data-[slot=field-label]:flex-auto",
      "has-[>[data-slot=field-content]]:items-start",
      "has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px"
    ]
  end

  defp orientation_classes("responsive") do
    [
      "@md/field-group:flex-row @md/field-group:items-center @md/field-group:*:w-auto flex-col *:w-full",
      "[&>.sr-only]:w-auto",
      "@md/field-group:*:data-[slot=field-label]:flex-auto",
      "@md/field-group:has-[>[data-slot=field-content]]:items-start",
      "@md/field-group:has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px"
    ]
  end

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
