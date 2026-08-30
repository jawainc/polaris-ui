defmodule PolarisUI.Components.Label do
  @moduledoc """
  The Polaris label: an accessible caption associated with a form
  control — the port of the Supabase design system Label
  (`packages/ui`, `label.tsx`, built on the Radix Label primitive).

  The Radix primitive is a real `<label>` with peer wiring; once the
  association is explicit (`for` ↔ the control's `id`), a plain `<label
  for>` is the whole contract — so this is a native label with the
  source's exact treatment: label scale (`text-sm`), tight leading, and
  the `peer-disabled:*` dimming for a disabled sibling control.

  ## Anatomy

      <.label for="email">Email</.label>
      <input id="email" type="email" placeholder="Email" class="..." />

  Pair `for` with the control's `id` — always. The `peer-disabled:`
  styles key off a preceding control carrying the `peer` class (the
  source's demo pairs it with a checkbox):

      <input id="terms" type="checkbox" class="peer" />
      <.label for="terms">Accept terms and conditions</.label>

  ## Where it fits

  This is the standalone label. Inside the Form family the changeset
  adapter renders its own label (the source's `FormLabel`, which flips
  danger on errors and wires ids automatically) — use
  `PolarisUI.Components.Form` there, and `field_label` for the
  presentational field anatomy.

  ## Accessibility

    * A real `<label for>` — clicking it focuses (and toggles) the
      control; screen readers announce it as the control's name.
    * `peer-disabled:cursor-not-allowed peer-disabled:opacity-70` dims
      the label while its control is disabled (the control needs the
      `peer` class and must precede the label as a sibling).

  ## Microcopy

  Per the Supabase copywriting guidelines: labels describe the field —
  "Email", "Table name" — never "Name your table".

  Purely presentational — no colocated hook and no client state.
  """

  use PolarisUI.Component

  @doc """
  Renders the label. `for` should always carry the control's id.
  """
  attr(:for, :string,
    default: nil,
    doc: "The associated control's id — always pair it with the control's `id`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the label.")

  attr(:rest, :global, doc: "Forwarded to the `<label>`: `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The label text — describe the field, never the feature."
  )

  def label(assigns) do
    ~H"""
    <label
      data-polaris-label
      for={@for}
      class={
        cn([
          "text-sm text-content-primary leading-none",
          "peer-disabled:cursor-not-allowed peer-disabled:opacity-70",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </label>
    """
  end
end
