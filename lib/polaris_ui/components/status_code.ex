defmodule PolarisUI.Components.StatusCode do
  @moduledoc """
  The Polaris status code chip: a compact, inert monospaced HTTP
  method + status pair — the port of the Supabase design system
  fragment `ui-patterns/StatusCode`.

  The React fragment is pure display: it maps the status value to one
  of three color families and renders an optional method half-chip
  fused to the status chip. This port is 1:1 — no colocated hook, no
  events, no client state; the LiveView owns whatever surrounds it.

  ## Anatomy

      <.status_code method="GET" status_code={404} />
      <.status_code status_code={502} />

    * **root** — `flex items-center gap-2` div; the caller `class`
      merges here. Carries `data-polaris-status-code`.
    * **inner span** — the shared monospace shell
      (`shrink-0 flex text-xs font-mono`).
    * **method chip** — optional; `rounded-l rounded-r-none` with the
      base surface fill and its right border removed, so it fuses to
      the status chip. Carries `data-polaris-status-method`.
    * **status chip** — always rendered; `rounded-r` (plus `rounded-l`
      when there is no method chip), `tabular-nums`, colored by the
      rules below. Carries `data-polaris-status-value`. `status_code`
      renders verbatim — `nil` renders an empty chip.

  ## Color rules

    | Family  | Normalizes to                                                        | Text                   | Fill                | Border                  |
    |---------|----------------------------------------------------------------------|------------------------|---------------------|-------------------------|
    | muted   | `"1"`, `"2"`, `"3"`, `"info"`, `"success"`, `nil`, unrecognized/invalid | `text-content-secondary` | `bg-surface-panel`  | `border-surface-border` |
    | warning | `"4"`, `"warning"`, `"redirect"`                                     | `text-warning`         | `bg-warning-muted`  | `border-warning-border` |
    | danger  | `"5"`, `"error"`                                                     | `text-danger`          | `bg-danger-muted`   | `border-danger-border`  |

  `status_colors/2` ports the fragment's `getStatusColor` exactly,
  including its two quirks:

    * **validity gate** — with no `method`, a non-`nil` value that
      does not coerce to a number in `[100, 600)` (NaN, `99`, `600`,
      `"abc"`) falls straight to the muted family, before
      normalization.
    * **method skips the gate** — the fragment's first check is
      `!method && value !== undefined`, so a present `method`
      disables the gate entirely. Only named strings can tell the two
      paths apart: `status_colors("error")` is muted (NaN fails the
      gate) while `status_colors("error", "GET")` is danger.

  Token mapping notes (React → Polaris): `text-foreground-lighter`
  and `text-foreground-light` both map to `text-content-secondary` —
  deliberately **not** `text-content-muted`, which would drop below
  AA contrast on the `bg-surface-panel` chip fill; `bg-surface-200` →
  `bg-surface-panel`, `bg-surface-75` → `bg-surface-base`,
  `bg-warning-300` / `bg-destructive-300` → the `*-muted` status
  fills, `border-warning-500/50` / `border-destructive-500/50` → the
  `*-border` button-role tokens, and the plain `border` →
  `border-surface-border` (the muted triple's empty border falls back
  to it in the renderer).

  ## States

  Rest and hover do not apply: the chip is an inert display — no
  pointer affordances, no transitions, no hook, no client state. The
  `select-text` on the method chip is the only interaction nod (it
  opts the method text back into text selection).

  ## Microcopy

  `method` and `status_code` render verbatim — the component never
  uppercases, pads, or reformats them; feed it the method and code
  exactly as your API reports them. `tabular-nums` keeps digit
  columns aligned across 2xx/4xx/5xx in tables and log rows.
  """

  use PolarisUI.Component

  @colors_muted %{text: "text-content-secondary", bg: "bg-surface-panel", border: ""}
  @colors_warning %{text: "text-warning", bg: "bg-warning-muted", border: "border-warning-border"}
  @colors_danger %{text: "text-danger", bg: "bg-danger-muted", border: "border-danger-border"}

  @root_classes "flex items-center gap-2"
  @inner_span_classes "shrink-0 flex text-xs font-mono items-start justify-start"
  @method_wrapper_classes "flex items-center justify-end"
  @status_wrapper_classes "flex items-center justify-start"

  @method_chip_classes "select-text py-0.5 px-2 text-right rounded-l rounded-r-none bg-surface-base text-content-secondary border border-surface-border border-r-0 w-auto"

  @status_chip_base "py-0.5 px-2 border tabular-nums text-left w-auto"

  attr(:status_code, :any,
    default: nil,
    doc: """
    The HTTP status code — integer or string, rendered verbatim in the
    chip (`200`, `404`, `"error"`, `"4"`, …). Drives the color family
    via `status_colors/2`; `nil` renders an empty muted chip.
    """
  )

  attr(:method, :string,
    default: nil,
    doc: """
    Optional HTTP method for the leading half-chip (`"GET"`, `"POST"`)
    — rendered verbatim, right-aligned, fused to the status chip with
    its right border removed. An empty string renders no chip (the
    fragment's JS truthiness) and also re-enables the status-color
    validity gate.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root div — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the root div: `data-*`, `phx-*`, …")

  def status_code(assigns) do
    has_method? = not blank?(assigns.method)
    colors = status_colors(assigns.status_code, assigns.method)

    assigns =
      assign(assigns,
        has_method?: has_method?,
        root_classes: cn([@root_classes, assigns.class]),
        inner_span_classes: @inner_span_classes,
        method_wrapper_classes: @method_wrapper_classes,
        status_wrapper_classes: @status_wrapper_classes,
        method_chip_classes: @method_chip_classes,
        status_chip_classes: status_chip_classes(colors, has_method?)
      )

    ~H"""
    <div data-polaris-status-code class={@root_classes} {@rest}>
      <span class={@inner_span_classes}>
        <span :if={@has_method?} class={@method_wrapper_classes}>
          <span data-polaris-status-method class={@method_chip_classes}>{@method}</span>
        </span>
        <span class={@status_wrapper_classes}>
          <span data-polaris-status-value class={@status_chip_classes}>{@status_code}</span>
        </span>
      </span>
    </div>
    """
  end

  @doc """
  Maps a status code to its chip color triple — the port of the
  fragment's `getStatusColor`, quirks included.

  Returns `%{text: ..., bg: ..., border: ...}` class strings; the
  muted family carries an empty `border` (the renderer falls back to
  the plain `border-surface-border` token).

  ## Rules (ported verbatim)

    * **validity gate** — when `method` is absent (nil or empty, the
      JS falsy values) and the value is not `nil`, anything that does
      not coerce to a number in `[100, 600)` returns the muted triple
      immediately: unparseable (`"abc"`), below 100 (`99`, `"42"`),
      and 600-plus (`600`).
    * **method skips the gate** — the fragment's first check is
      `!method && value !== undefined`, so a present `method`
      disables the gate entirely (visible only for named strings —
      see the `"error"` pair below).
    * **normalization** — numbers below 100 become their own string;
      numbers 100 and up collapse to `floor(value / 100)`; digit-only
      strings of length 3 or more collapse the same way; everything
      else (including `nil`) passes through untouched.
    * **switch** — `"1"` / `"2"` / `"3"` / `"info"` / `"success"` /
      `nil` are muted, `"4"` / `"warning"` / `"redirect"` are warning,
      `"5"` / `"error"` are danger, and the default is muted.

  ## Examples

  Muted defaults — a 2xx and a nil value:

      iex> status_colors(200)
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

      iex> status_colors(nil)
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

  Warning and danger by status class:

      iex> status_colors(404)
      %{bg: "bg-warning-muted", border: "border-warning-border", text: "text-warning"}

      iex> status_colors(500)
      %{bg: "bg-danger-muted", border: "border-danger-border", text: "text-danger"}

  Invalid HTTP statuses fall back to muted before normalization:

      iex> status_colors(99)
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

      iex> status_colors(600)
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

      iex> status_colors("abc")
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

  A present method skips the validity gate — and nil stays muted:

      iex> status_colors(nil, "GET")
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

      iex> status_colors("error")
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

      iex> status_colors("error", "GET")
      %{bg: "bg-danger-muted", border: "border-danger-border", text: "text-danger"}

  Named strings resolve through the switch (they only reach it past
  the gate, i.e. with a method):

      iex> status_colors("warning", "POST")
      %{bg: "bg-warning-muted", border: "border-warning-border", text: "text-warning"}

      iex> status_colors("redirect", "GET")
      %{bg: "bg-warning-muted", border: "border-warning-border", text: "text-warning"}

      iex> status_colors("info", "GET")
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

      iex> status_colors("success", "GET")
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

  Digit strings collapse like numbers — and short ones fail the gate:

      iex> status_colors("404")
      %{bg: "bg-warning-muted", border: "border-warning-border", text: "text-warning"}

      iex> status_colors("42")
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

  Numbers below 100 become their own string (with a method, past the
  gate) and land on the switch default:

      iex> status_colors(42, "GET")
      %{bg: "bg-surface-panel", border: "", text: "text-content-secondary"}

      iex> status_colors("4", "GET")
      %{bg: "bg-warning-muted", border: "border-warning-border", text: "text-warning"}
  """
  @spec status_colors(integer() | float() | String.t() | nil, String.t() | nil) :: %{
          text: String.t(),
          bg: String.t(),
          border: String.t()
        }
  def status_colors(status_code, method \\ nil) do
    if blank?(method) and status_code != nil and not valid_http_status?(status_code) do
      @colors_muted
    else
      status_code |> normalize_status() |> colors_for()
    end
  end

  ## Chip assembly

  # The status chip joins the fragment's geometry with the color
  # triple. The rounding side classes must stay OUT of `cn/1`: this
  # library's merger resolves every `rounded-*` utility as a single
  # conflict family, so one `cn` call would let `rounded-l` swallow
  # `rounded-r`. Inside `cn`, `border-surface-border` is the
  # plain-border fallback for the muted triple's empty `border`, and
  # the warning/danger triples override it — exactly one border color
  # survives.
  defp status_chip_classes(colors, has_method?) do
    [
      @status_chip_base,
      if(has_method?, do: "rounded-l-0 rounded-r", else: "rounded-l rounded-r"),
      cn(["border-surface-border", colors.text, colors.bg, colors.border])
    ]
    |> Enum.join(" ")
  end

  ## Validity gate (the fragment's Number() coercion)

  defp valid_http_status?(value) do
    case coerce_number(value) do
      :nan -> false
      number -> number >= 100 and number < 600
    end
  end

  # JS Number(): numbers pass through, strings are trimmed and parsed
  # ("" coerces to 0), anything else is NaN.
  defp coerce_number(value) when is_integer(value), do: value
  defp coerce_number(value) when is_float(value), do: value

  defp coerce_number(value) when is_binary(value) do
    case String.trim(value) do
      "" ->
        0

      trimmed ->
        case Integer.parse(trimmed) do
          {int, ""} -> int
          _ -> parse_float(trimmed)
        end
    end
  end

  defp coerce_number(_value), do: :nan

  defp parse_float(trimmed) do
    case Float.parse(trimmed) do
      {float, ""} -> float
      _ -> :nan
    end
  end

  ## Normalization (ported verbatim)

  # Numbers below 100 become their own string; numbers 100 and up
  # collapse to floor(value / 100); digit-only strings of length 3 or
  # more collapse the same way; anything else — including nil — passes
  # through untouched.
  defp normalize_status(nil), do: nil

  defp normalize_status(value) when is_number(value) and value < 100,
    do: Kernel.to_string(value)

  defp normalize_status(value) when is_number(value),
    do: value |> Kernel./(100) |> Float.floor() |> trunc() |> Integer.to_string()

  defp normalize_status(value) when is_binary(value) do
    if digit_string?(value) and String.length(value) >= 3 do
      {int, ""} = Integer.parse(value)
      Integer.to_string(div(int, 100))
    else
      value
    end
  end

  defp digit_string?(value), do: value =~ ~r/\A\d+\z/

  ## The switch

  defp colors_for(normalized) when normalized in [nil, "1", "2", "3", "info", "success"],
    do: @colors_muted

  defp colors_for(normalized) when normalized in ["4", "warning", "redirect"],
    do: @colors_warning

  defp colors_for(normalized) when normalized in ["5", "error"],
    do: @colors_danger

  defp colors_for(_normalized), do: @colors_muted

  # JS truthiness for the optional method: nil and "" both count as
  # absent (the fragment's `!method` gate and `method && ...` chip).
  defp blank?(value), do: value in [nil, ""]
end
