defmodule PolarisUI.Components.DatePicker do
  @moduledoc """
  The Polaris date picker: a calendar popover behind a date-field
  button — the port of the Supabase design system Date Picker
  (`ui-patterns/DatePicker`), which composes the Popover and Button
  primitives around the Calendar.

  The source is a thin composition — `DatePicker` is a Popover
  passthrough, `DatePickerButton` a `default`-variant Button with the
  calendar glyph and `justify-start text-left font-normal`, and
  `DatePickerContent` the `w-auto p-0` popover. This port keeps that
  anatomy 1:1 while splitting the brain along the established LiveView
  seam:

    * the **server** owns the date — every day click rides the nested
      Calendar's own hook, pushing `on_select` (`%{"date" => iso}` in
      single mode, `%{"from" => iso | nil, "to" => iso | nil}` in
      range mode), and the re-rendered trigger label is the single
      source of truth;
    * the colocated **hook** owns only the view layer — popover
      open/close and dismissal. In single mode a day click also closes
      the popover (the source demo's `setOpen(false)` in `onSelect`);
      range mode stays open until the span is adjusted or dismissed.

  ## Anatomy

      <.date_picker
        id="due-date"
        value={@due_date}
        on_select="pick-due-date"
      />

      <.date_picker
        id="span"
        mode="range"
        value={%{from: @from, to: @to}}
        on_select="pick-span"
        placeholder="Pick a date range"
      />

    * **trigger** — the Supabase `default` button (`w-[240px]
      justify-start text-left font-normal`, override via `class`) with
      the calendar glyph, showing the formatted date
      ("August 23, 2026"), the range ("August 23, 2026 – August 29,
      2026", or just the from-date while open-ended), or the
      placeholder ("Pick a date") in muted text.
    * **popover** — always in the DOM (`hidden` until the hook opens
      it): the Calendar itself, floating below the trigger (flipping
      up when the viewport runs out).

  ## States

    * **rest / hover / focus-ring / disabled** — inherited from the
      Supabase button (hover fill, emerald focus ring, 50% dim).
    * **open** — the popover visible below the trigger.
    * **invalid** — `is_invalid` tints the trigger with the danger
      tokens (the source's `isInvalid` destructive overrides) for
      form-validation feedback.

  ## Microcopy

  Per the Supabase copywriting guidelines: the `placeholder` states the
  intent ("Pick a date"), and the label names the field it belongs to
  in the surrounding form layout ("Due date").

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  import PolarisUI.Components.Button, only: [button: 1]
  import PolarisUI.Components.Calendar, only: [calendar: 1]

  @modes ~w(single range)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the root — the colocated hook anchors on it. Derived
    ids: `"<id>-calendar"` (the nested Calendar).
    """
  )

  attr(:name, :string,
    default: nil,
    doc: """
    Form field name — when set (single mode), a hidden input carrying
    the ISO date is rendered so the control submits with normal forms.
    """
  )

  attr(:value, :any,
    default: nil,
    doc: """
    Server-owned date — a `Date` in single mode, `%{from: Date,
    to: Date | nil}` in range mode.
    """
  )

  attr(:mode, :string,
    values: @modes,
    default: "single",
    doc: """
    `"single"` picks one date; `"range"` picks a from/to span (pass
    `value` as `%{from: Date, to: Date | nil}`).
    """
  )

  attr(:on_select, :string,
    required: true,
    doc: """
    LiveView event pushed on selection (by the nested Calendar's hook) —
    `%{"date" => iso}` in single mode, `%{"from" => iso | nil, "to" =>
    iso | nil}` in range mode.
    """
  )

  attr(:min_date, Date,
    default: nil,
    doc: "Days before this date are disabled (forwarded to the Calendar)."
  )

  attr(:max_date, Date,
    default: nil,
    doc: "Days after this date are disabled (Forwarded to the Calendar)."
  )

  attr(:month, Date,
    default: nil,
    doc: "Any day of the month to display first (Forwarded to the Calendar)."
  )

  attr(:week_starts_on, :integer,
    values: Enum.to_list(0..6//1),
    default: 0,
    doc: "First day of the week: 0 Sunday (default) through 6 Saturday."
  )

  attr(:show_outside_days, :boolean,
    default: true,
    doc: "Render adjacent-month days in the leading/trailing cells (Forwarded to the Calendar)."
  )

  attr(:placeholder, :string,
    default: "Pick a date",
    doc: "Trigger text when no date is selected — \"Pick a date range\" for spans."
  )

  attr(:button_variant, :string,
    default: "default",
    doc: "Trigger button variant — the Supabase button variants (`default`, `outline`, …)."
  )

  attr(:button_size, :string,
    default: "small",
    doc: "Trigger button size (the Supabase size scale; `small` matches the demo)."
  )

  attr(:is_invalid, :boolean,
    default: false,
    doc: """
    Tints the trigger with the danger tokens — the source's `isInvalid`
    destructive overrides, for form-validation feedback.
    """
  )

  attr(:disabled, :boolean, default: false, doc: "Disables the trigger.")

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the trigger button (`w-[280px]` sizing, …)."
  )

  attr(:popover_class, :string, default: nil, doc: "Additional classes merged onto the popover.")

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  def date_picker(assigns) do
    validate_in!(:mode, assigns.mode, @modes)
    validate_value!(assigns.mode, assigns.value)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Root",
        label: format_value(assigns.mode, assigns.value),
        hidden_value: hidden_value(assigns.mode, assigns.value),
        popover_classes:
          cn([
            "absolute left-0 z-50 mt-1 hidden rounded-md",
            assigns.popover_class
          ])
      )

    ~H"""
    <div
      id={@id}
      class="relative inline-block max-w-full text-left"
      data-polaris-date-picker
      data-mode={@mode}
      phx-hook={@hook}
      {@rest}
    >
      <input :if={@name && @mode == "single"} type="hidden" name={@name} value={@hidden_value} />

      <.button
        type="button"
        variant={@button_variant}
        size={@button_size}
        aria-haspopup="dialog"
        aria-expanded="false"
        disabled={@disabled}
        data-polaris-date-picker-trigger
        data-open="false"
        class={
          cn([
            "w-[240px] justify-start text-left font-normal",
            if(@is_invalid,
              do:
                "border-danger-border bg-danger-fill focus-visible:border-danger-border-hover focus-visible:ring-danger"
            ),
            @class
          ])
        }
      >
        <%= if @label do %>
          {@label}
        <% else %>
          <span class="text-content-muted font-normal">{@placeholder}</span>
        <% end %>
        <:icon>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-4"
            aria-hidden="true"
          >
            <path d="M8 2v4" />
            <path d="M16 2v4" />
            <rect width="18" height="18" x="3" y="4" rx="2" />
            <path d="M3 10h18" />
          </svg>
        </:icon>
      </.button>

      <div data-polaris-date-picker-popover class={@popover_classes}>
        <.calendar
          id={"#{@id}-calendar"}
          mode={@mode}
          selected={@value}
          month={@month}
          min_date={@min_date}
          max_date={@max_date}
          week_starts_on={@week_starts_on}
          show_outside_days={@show_outside_days}
          on_select={@on_select}
          class="shadow-md"
        />
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          this._open = false

          const trigger = () => root.querySelector("[data-polaris-date-picker-trigger]")
          const popover = () => root.querySelector("[data-polaris-date-picker-popover]")

          this._applyOpen = (open) => {
            const t = trigger()
            const p = popover()
            this._open = open
            if (!t || !p) {
              return
            }
            if (open) {
              // Flip up when there is no room below the trigger.
              const rect = t.getBoundingClientRect()
              if (window.innerHeight - rect.bottom < 360 && rect.top > 360) {
                p.style.top = "auto"
                p.style.bottom = "100%"
                p.style.marginTop = "0"
                p.style.marginBottom = "4px"
              } else {
                p.style.top = ""
                p.style.bottom = ""
                p.style.marginTop = ""
                p.style.marginBottom = ""
              }
              p.classList.remove("hidden")
              t.setAttribute("aria-expanded", "true")
              t.setAttribute("data-open", "true")
              t.setAttribute("data-state", "open")
            } else {
              p.classList.add("hidden")
              t.setAttribute("aria-expanded", "false")
              t.setAttribute("data-open", "false")
              t.setAttribute("data-state", "closed")
            }
          }

          this._onClick = (event) => {
            if (event.target.closest("[data-polaris-date-picker-trigger]")) {
              this._applyOpen(!this._open)
              return
            }
            // A day click completes a single-mode selection — close after
            // the Calendar's own hook pushes the event (the source demo's
            // setOpen(false) in onSelect). Range mode stays open.
            if (
              this._open &&
              root.dataset.mode === "single" &&
              event.target.closest("[data-polaris-calendar-day]")
            ) {
              this._applyOpen(false)
            }
          }
          root.addEventListener("click", this._onClick)

          this._onKeydown = (event) => {
            if (event.key === "Escape" && this._open) {
              event.preventDefault()
              this._applyOpen(false)
              const t = trigger()
              if (t) {
                t.focus()
              }
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)

          this._onDocumentClick = (event) => {
            if (!root.contains(event.target)) {
              this._applyOpen(false)
            }
          }
          document.addEventListener("click", this._onDocumentClick)
        },

        updated() {
          // The server always renders the popover hidden; after a patch
          // re-assert the open state.
          if (this._open) {
            this._applyOpen(true)
          }
        },

        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onClick)
          document.removeEventListener("keydown", this._onKeydown, true)
          document.removeEventListener("click", this._onDocumentClick)
        }
      }
    </script>
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

  defp validate_value!("single", nil), do: :ok
  defp validate_value!("single", %Date{}), do: :ok

  defp validate_value!("single", other) do
    raise ArgumentError, """
    PolarisUI date_picker: mode="single" expects value to be a Date, \
    got: #{inspect(other)} — for a span use mode="range" with \
    value={%{from: date, to: date}}.
    """
  end

  defp validate_value!("range", nil), do: :ok

  defp validate_value!("range", %{from: %Date{} = from} = value) do
    case Map.get(value, :to) do
      nil ->
        :ok

      %Date{} = to ->
        if Date.compare(to, from) == :lt, do: raise_to_before_from(from, to), else: :ok

      other ->
        raise ArgumentError, "PolarisUI date_picker: range `to` must be a Date or nil, got: #{inspect(other)}."
    end
  end

  defp validate_value!("range", other) do
    raise ArgumentError, """
    PolarisUI date_picker: mode="range" expects value to be \
    %{from: Date, to: Date | nil}, got: #{inspect(other)}.
    """
  end

  defp raise_to_before_from(from, to) do
    raise ArgumentError, """
    PolarisUI date_picker: range `to` (#{Date.to_iso8601(to)}) is before \
    `from` (#{Date.to_iso8601(from)}).
    """
  end

  # The trigger label: "August 23, 2026" for a date, "from – to" for a
  # complete span, or just the from-date while open-ended.
  defp format_value("single", %Date{} = date), do: format_date(date)
  defp format_value("single", _), do: nil

  defp format_value("range", %{from: %Date{} = from} = value) do
    case Map.get(value, :to) do
      %Date{} = to -> "#{format_date(from)} – #{format_date(to)}"
      _ -> format_date(from)
    end
  end

  defp format_value("range", _), do: nil

  defp format_date(date), do: "#{Calendar.strftime(date, "%B")} #{date.day}, #{date.year}"

  # The hidden-input payload (single mode only; range spans submit via the
  # from/to event payloads).
  defp hidden_value("single", %Date{} = date), do: Date.to_iso8601(date)
  defp hidden_value(_mode, _), do: nil
end
