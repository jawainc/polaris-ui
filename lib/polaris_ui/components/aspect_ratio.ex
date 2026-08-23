defmodule PolarisUI.Components.AspectRatio do
  @moduledoc """
  The Polaris aspect ratio: displays content within a desired ratio.

  Port of the Supabase design system AspectRatio (`packages/ui`), which is a
  pure re-export of the Radix AspectRatio primitive. Like the Radix
  component, it renders a **two-element padding-bottom wrapper**: an
  unstyled outer `<div>` that establishes the ratio via
  `padding-bottom: 100 / ratio %`, and an absolutely-positioned inner
  `<div>` (inset on all sides) that receives the caller's attributes and
  holds the content. Media children fill the box when given
  `h-full w-full object-cover`.

  ## Anatomy

      <div class="w-[450px]">
        <.aspect_ratio ratio={16 / 9} class="rounded-md">
          <img src="..." alt="..." class="h-full w-full rounded-md object-cover" />
        </.aspect_ratio>
      </div>

  The `class` attribute (and all other global attributes) land on the
  **inner** div — never on the padding wrapper — exactly like the Radix
  primitive, so caller classes can never break the ratio math. A
  caller-supplied `style` is appended before the positioning rules, so the
  primitive's `position: absolute; inset: 0` always wins, mirroring Radix's
  spread order.

  ## Ratio

  `ratio` is a positive number (`16 / 9` ≈ 1.778 → `padding-bottom:
  56.25%`), defaulting to `1.0` (square). Any positive float or integer is
  accepted; `0`, negatives, and non-numbers raise at render time.

  No colocated hook is required: the component is pure CSS.
  """

  use PolarisUI.Component

  attr(:ratio, :float,
    default: 1.0,
    doc: """
    Positive width/height ratio (`16 / 9`, `4 / 3`, `1.0`). Defaults to a
    square; rendered as the wrapper's `padding-bottom` percentage.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the inner (absolutely-positioned) div —
    caller classes win conflicts via `cn/1`.
    """
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the inner div: `id`, `style` (merged before the primitive's
    positioning rules), `data-*`, `phx-*`, …
    """
  )

  slot(:inner_block,
    required: true,
    doc: "The content to fit — typically an `<img>` or `<video>`."
  )

  def aspect_ratio(assigns) do
    unless is_number(assigns.ratio) and assigns.ratio > 0 do
      raise ArgumentError, """
      PolarisUI aspect_ratio: :ratio must be a positive number, \
      got: #{inspect(assigns.ratio)}
      """
    end

    # Radix computes `paddingBottom: ${100 / ratio}%`; rounding to 4 decimals
    # keeps repeating ratios (16/9 → 56.25) clean without visible drift.
    padding_bottom = Float.round(100 / assigns.ratio * 1.0, 4)

    # Caller style merges BEFORE the positioning rules so the primitive's
    # absolute inset always wins — the same precedence Radix applies.
    caller_style = assigns.rest[:style]
    rest = Map.drop(assigns.rest, [:style])

    caller_prefix =
      if caller_style, do: String.trim_trailing(caller_style, ";") <> "; ", else: ""

    inner_style =
      caller_prefix <>
        "position: absolute; top: 0; right: 0; bottom: 0; left: 0;"

    assigns =
      assigns
      |> assign(padding_bottom: padding_bottom, inner_style: inner_style, rest: rest)

    ~H"""
    <div
      data-polaris-aspect-ratio-wrapper
      style={"position: relative; width: 100%; padding-bottom: #{@padding_bottom}%"}
    >
      <div class={@class} style={@inner_style} {@rest}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
