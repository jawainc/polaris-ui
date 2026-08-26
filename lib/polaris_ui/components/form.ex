defmodule PolarisUI.Components.Form do
  @moduledoc """
  The Polaris hook form: the changeset-driven form family — the port
  of the Supabase design system Form (`packages/ui`, `form.tsx`),
  which wraps react-hook-form.

  ## From react-hook-form to LiveView

  The source splits the job in two: `Form` (literally react-hook-form's
  `FormProvider` — context, no DOM) and the `FormField`/`FormItem`/
  `FormLabel`/`FormControl`/`FormDescription`/`FormMessage` family that
  consumes it. In LiveView the form state already lives on the server:
  a changeset (or any `Phoenix.HTML.FormData`) plays the role of the
  hook-form store, and `%Phoenix.HTML.FormField{}` structs (`f[:name]`
  from the form's `:let`) carry each field's `id`, `name`, `value`, and
  `errors` down to the parts. The components below keep the source's
  split: `form` owns the state entry point; every other part takes the
  same `field` and derives the source's id/aria contract from it:

      <id>-form-item            the control's id (the label's `for`)
      <id>-form-item-description
      <id>-form-item-message

  ## Anatomy

      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save">
        <.form_item field={f[:username]}>
          <.form_label field={f[:username]}>Username</.form_label>
          <.form_control field={f[:username]} placeholder="supabase" />
          <.form_description field={f[:username]}>
            This is your public display name.
          </.form_description>
          <.form_message field={f[:username]} />
        </.form_item>
        <.button type="submit" variant="secondary">Save changes</.button>
      </.form>

  ## The aria contract

  `form_control` sets `aria-invalid="true"` when the field has errors
  and its `aria-describedby` conditionally widens — just the
  description id while valid, description *and* message ids once
  invalid (exactly the source's `FormControl`). `form_label` points
  `for` at the control id and forces danger text while errored (the
  source's `!text-destructive`). `form_message` renders nothing until
  there is a message: the first changeset error, or the inner block as
  a fallback — the source's `error ? error.message : children`.

  ## Validation and errors

  The source validates client-side via a zod resolver before submit;
  here the changeset does it (validate on `phx-change`, persist on
  `phx-submit` — the standard LiveView round-trip). Error tuples
  `{message, opts}` interpolate their placeholders (`%{count}` and
  friends) like `Phoenix.HTML`'s `translate_error`.

  ## Microcopy

  Per the Supabase copywriting guidelines — use `form_label`, never a
  bare label; labels describe the field ("Username"); descriptions
  state constraints ("This is your public display name."); messages
  say what went wrong ("Username must be at least 2 characters.");
  the submit button uses the specific verb ("Save changes", never
  "Submit").

  Purely server-driven — no colocated hook and no client state.
  """

  use PolarisUI.Component

  @doc """
  The form: the state entry point — the port of the source's `Form`
  (`FormProvider`) plus the consumer's `<form onSubmit>` rolled into
  one. A thin delegate over `Phoenix.Component.form/1`: give it your
  changeset (or any `Phoenix.HTML.FormData`) and the usual `phx-*`
  bindings; `:let` receives the `%Phoenix.HTML.Form{}` whose `f[:name]`
  fields drive the rest of the family.
  """
  attr(:for, :any,
    required: true,
    doc: """
    The form data — a changeset, map, or any `Phoenix.HTML.FormData`.
    """
  )

  attr(:rest, :global,
    doc: """
    Forwarded to `<.form>`: `phx-change`, `phx-submit`, `action`,
    `as`, `multipart`, …
    """
  )

  slot(:inner_block, required: true, doc: "Receives the `%Phoenix.HTML.Form{}` via `:let`.")

  def form(assigns) do
    ~H"""
    <Phoenix.Component.form :let={f} for={@for} {@rest}>
      {render_slot(@inner_block, f)}
    </Phoenix.Component.form>
    """
  end

  @doc """
  The form item: the structural group for one field — the source's
  `FormItem` + `FormField` collapsed (the `field` struct *is* the
  context). Derives the id/aria contract every other part shares.
  """
  attr(:field, :any,
    required: true,
    doc: "The field struct — `f[:name]` from the form's `:let`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the item.")
  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The label, control, description, and message.")

  def form_item(assigns) do
    ~H"""
    <div data-polaris-form-item class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The form label: the field's label — the source's `FormLabel`
  (`text-foreground-light text-sm`, danger while errored, `for` wired
  to the control id).
  """
  attr(:field, :any, required: true, doc: "The field struct — `f[:name]`.")

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the label. The danger error state
    wins over caller classes, like the source's `!text-destructive`.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the `<label>`: `data-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The label text — describe the field, never the feature."
  )

  def form_label(assigns) do
    assigns =
      assign(assigns,
        has_error?: has_error?(assigns.field),
        control_id: control_id(assigns.field)
      )

    ~H"""
    <label
      data-polaris-form-label
      for={@control_id}
      class={
        cn([
          "text-sm text-content-secondary leading-normal transition-colors",
          @class,
          if(@has_error?, do: "text-danger")
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  The form control: the wired input itself — the source's
  `FormControl` (a Slot merging onto your input; here the control is
  rendered for you, since HEEx cannot merge onto slot children). Sets
  the control id, name, value, `aria-invalid`, and the conditional
  `aria-describedby`; `type="textarea"` renders the multi-line
  variant.
  """
  attr(:field, :any, required: true, doc: "The field struct — `f[:name]`.")

  attr(:type, :string,
    default: "text",
    doc: """
    The input type (`text`, `email`, `password`, …) — or `textarea` for
    the multi-line variant.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the control.")

  attr(:rest, :global,
    doc: """
    Forwarded to the control: `placeholder`, `autocomplete`,
    `phx-blur`, `phx-focus`, `maxlength`, `data-*`, …
    """
  )

  def form_control(assigns) do
    assigns =
      assign(assigns,
        has_error?: has_error?(assigns.field),
        control_id: control_id(assigns.field),
        describedby: describedby(assigns.field),
        control_classes: cn([control_base_classes(assigns.type), assigns.class])
      )

    ~H"""
    <input
      :if={@type != "textarea"}
      data-polaris-form-control
      id={@control_id}
      name={@field.name}
      value={@field.value}
      type={@type}
      aria-invalid={if(@has_error?, do: "true")}
      aria-describedby={@describedby}
      class={@control_classes}
      {@rest}
    />
    <textarea
      :if={@type == "textarea"}
      data-polaris-form-control
      id={@control_id}
      name={@field.name}
      aria-invalid={if(@has_error?, do: "true")}
      aria-describedby={@describedby}
      class={@control_classes}
      {@rest}
    ><%= @field.value %></textarea>
    """
  end

  @doc """
  The form description: the hint text — the source's `FormDescription`
  (`text-sm text-foreground-light`), carrying the description id the
  control's `aria-describedby` references.
  """
  attr(:field, :any, required: true, doc: "The field struct — `f[:name]`.")

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the description.")

  attr(:rest, :global, doc: "Forwarded to the `<div>`: `data-*`, …")

  slot(:inner_block, required: true, doc: "The hint — constraints, not concepts.")

  def form_description(assigns) do
    ~H"""
    <div
      data-polaris-form-description
      id={description_id(assigns.field)}
      class={cn(["text-sm text-content-secondary", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  The form message: the validation message — the source's
  `FormMessage`. Renders nothing until there is a message: the first
  changeset error on the field, else the inner block (the source's
  `error ? String(error.message) : children`).
  """
  attr(:field, :any, required: true, doc: "The field struct — `f[:name]`.")

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the message.")

  attr(:rest, :global, doc: "Forwarded to the `<p>`: `data-*`, …")

  slot(:inner_block,
    doc: "Fallback message when the field has no errors of its own."
  )

  def form_message(assigns) do
    assigns =
      assign(assigns,
        message: field_error_message(assigns.field) || slot_content?(assigns.inner_block, assigns)
      )

    ~H"""
    <p
      :if={@message}
      data-polaris-form-message
      id={message_id(assigns.field)}
      class={cn(["text-sm text-danger", @class])}
      {@rest}
    >
      <%= if field_error_message(@field) do %>
        {field_error_message(@field)}
      <% else %>
        {render_slot(@inner_block)}
      <% end %>
    </p>
    """
  end

  # The source's id contract, derived from the field's id.
  defp control_id(field), do: "#{field.id}-form-item"
  defp description_id(field), do: "#{field.id}-form-item-description"
  defp message_id(field), do: "#{field.id}-form-item-message"

  # The conditional aria-describedby — description alone while valid,
  # description + message once errored (the source's FormControl).
  defp describedby(field) do
    if has_error?(field) do
      "#{description_id(field)} #{message_id(field)}"
    else
      description_id(field)
    end
  end

  defp has_error?(field), do: normalize_errors(field).errors != []

  defp field_error_message(field) do
    normalize_errors(field).errors |> List.first()
  end

  # Field structs are plain maps at heart; work with both the real
  # %Phoenix.HTML.FormField{} and literal maps in tests.
  defp normalize_errors(field) do
    errors =
      field
      |> Map.get(:errors, [])
      |> List.wrap()
      |> Enum.map(&translate_error/1)
      |> Enum.reject(&is_nil/1)

    %{errors: errors}
  end

  # Changeset error tuples ({msg, opts}) with %{placeholder}
  # interpolation — the standard `translate_error` treatment.
  defp translate_error(message) when is_binary(message), do: message

  defp translate_error({message, opts}) when is_binary(message) do
    Enum.reduce(opts || [], message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp translate_error(_), do: nil

  # The control surface treatment — the Supabase Input/Textarea base
  # over Polaris tokens (the source's FormControl adds no classes; the
  # control you slot in carries them, and here that control is ours).
  defp control_base_classes("textarea") do
    [
      "flex min-h-[80px] w-full rounded-md border border-surface-border",
      "bg-surface-panel px-3 py-2 text-base md:text-sm text-content-primary",
      "placeholder:text-content-muted transition-colors duration-200",
      "hover:border-surface-border-hover focus:border-surface-border-hover",
      "focus:outline-none focus:ring-2 focus:ring-brand-emerald",
      "focus:ring-offset-2 focus:ring-offset-surface-ground",
      "aria-[invalid=true]:border-danger-border aria-[invalid=true]:bg-danger-muted",
      "aria-[invalid=true]:hover:border-danger",
      "disabled:cursor-not-allowed disabled:opacity-50"
    ]
  end

  defp control_base_classes(_input) do
    [
      "flex h-10 w-full rounded-md border border-surface-border",
      "bg-surface-panel px-3 py-2 text-base md:text-sm text-content-primary",
      "placeholder:text-content-muted transition-colors duration-200",
      "hover:border-surface-border-hover focus:border-surface-border-hover",
      "focus:outline-none focus:ring-2 focus:ring-brand-emerald",
      "focus:ring-offset-2 focus:ring-offset-surface-ground",
      "aria-[invalid=true]:border-danger-border aria-[invalid=true]:bg-danger-muted",
      "aria-[invalid=true]:hover:border-danger",
      "disabled:cursor-not-allowed disabled:opacity-50"
    ]
  end
end
