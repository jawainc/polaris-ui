defmodule PolarisUI.Components.Calendar do
  @moduledoc """
  The Polaris calendar: a month grid for picking a date or a date range —
  the port of the Supabase design system Calendar (`packages/ui`, a thin
  wrapper over react-day-picker v9).

  ## Anatomy

      <.calendar
        id="dob"
        month={~D[2026-08-01]}
        selected={@date}
        on_select="pick-date"
      />

      <.calendar id="range" mode="range" selected={%{from: @from, to: @to}} />

    * **root** — the bordered `p-3` surface carrying the whole config as
      data attributes for the hook.
    * **caption** — the centered `August 2026` label between the two
      absolutely-positioned chevron nav buttons (28px, half-opacity until
      hover, `aria-disabled` at the min/max bounds).
    * **grid** — a `role="grid"` month table: a flex weekday header row
      (`w-9` cells, narrow labels with full-name `aria-label`s) and flex
      week rows of 36px day buttons (`h-9 w-9`).

  ## Interaction model

  Like react-day-picker, the calendar is **client-side**: the colocated
  runtime hook owns the displayed month and the selection, seeded from
  `month`/`selected` on first render. The hook:

    * navigates months via the chevrons (clamped by `min_date`/`max_date`,
      mirrored onto the buttons as `aria-disabled`), regenerating the grid
      with the same markup the server rendered;
    * selects days — `single` toggles (clicking the selected day clears
      it, like RDP without `required`); `range` builds from → to, an
      earlier click restarting the range;
    * pushes `on_select` to the server — `%{"date" => iso}` in single
      mode, `%{"from" => iso | nil, "to" => iso | nil}` in range mode —
      and re-applies its own state after LiveView patches.

  Selected days fill with the signature emerald (`bg-brand-emerald` +
  near-black text for WCAG-safe contrast on the bright fill); a complete
  range tints its middle with the muted brand fill, rounding only the
  end caps. Today carries a quiet `bg-surface-panel-hover` chip that the
  selection overrides. Outside days render dimmed (`opacity-50`), and
  days beyond `min_date`/`max_date` are `aria-disabled` — still
  focusable so arrow navigation can traverse them, but inert.

  ## Keyboard

  One tab stop for the whole grid (the selected day, else today, else
  the first day), then: arrows move a day / a week, `Home`/`End` bound
  the week, `PageUp`/`PageDown` flip months (`Shift` for years) — the
  react-day-picker keyboard standard. `Enter`/`Space` pick the focused
  day.

  The day-cell class constants are mirrored between this module
  (`@day_td_classes`, `@day_button_base`, …) and the hook's string
  properties (`TD_CLASSES`, `DAY_BASE`, …) because the hook re-renders
  months client-side — keep the two in sync.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @modes ~w(single range)

  # {narrow, full} starting Sunday — rotated by week_starts_on.
  @weekdays [
    {"Su", "Sunday"},
    {"Mo", "Monday"},
    {"Tu", "Tuesday"},
    {"We", "Wednesday"},
    {"Th", "Thursday"},
    {"Fr", "Friday"},
    {"Sa", "Saturday"}
  ]

  # Mirrored verbatim in the hook's TD_CLASSES — the grid-cell layout.
  @day_td_classes [
    "text-center text-sm p-0 relative w-9 box-border",
    "first:[&:has([aria-selected])]:rounded-l-md last:[&:has([aria-selected])]:rounded-r-md",
    "focus-within:relative focus-within:z-20"
  ]

  # Mirrored verbatim in the hook's DAY_BASE / DAY_HOVER / DAY_DISABLED —
  # the ghost day button (base + ghost buttonVariants from the source,
  # minus the selected-day hover bleed via the aria-selected suppressions).
  @day_button_base [
    "inline-flex h-9 w-9 items-center justify-center rounded-md p-0 font-normal text-sm",
    "transition-colors",
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
    "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
    "aria-selected:opacity-100 aria-selected:hover:bg-transparent aria-selected:hover:text-inherit"
  ]

  @day_button_hover "hover:bg-surface-panel-hover hover:text-content-primary"

  @day_button_disabled "cursor-not-allowed text-content-muted opacity-50"

  # The emerald selection treatment (single day, partial-range start, and
  # the full-range end caps) — near-black text keeps the bright fill WCAG-safe.
  @selected_classes "bg-brand-emerald text-surface-ground rounded-md"
  @range_start_classes "bg-brand-emerald text-surface-ground rounded-l-md"
  @range_end_classes "bg-brand-emerald text-surface-ground rounded-r-md"
  @range_middle_classes "bg-brand-fill text-content-primary rounded-none"
  @today_classes "bg-surface-panel-hover text-content-primary rounded-md"
  @outside_classes "text-content-muted opacity-50"

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the calendar root — required because the colocated hook
    that owns the month and selection anchors on it. The caption label
    derives `"<id>-caption"`.
    """
  )

  attr(:month, Date,
    default: nil,
    doc: "Any day of the month to display first (defaults to the current UTC month)."
  )

  attr(:mode, :string,
    values: @modes,
    default: "single",
    doc: """
    `"single"` picks one date; `"range"` picks a from/to span (pass
    `selected` as `%{from: Date, to: Date | nil}`).
    """
  )

  attr(:selected, :any,
    default: nil,
    doc: """
    Initial selection — a `Date` in single mode, `%{from: Date,
    to: Date | nil}` in range mode. The hook owns selection from then on.
    """
  )

  attr(:min_date, Date,
    default: nil,
    doc: "Days before this date are disabled and month navigation stops at its month."
  )

  attr(:max_date, Date,
    default: nil,
    doc: "Days after this date are disabled and month navigation stops at its month."
  )

  attr(:show_outside_days, :boolean,
    default: true,
    doc: "Render adjacent-month days in the leading/trailing cells (dimmed)."
  )

  attr(:week_starts_on, :integer,
    values: Enum.to_list(0..6//1),
    default: 0,
    doc: "First day of the week: 0 Sunday (default) through 6 Saturday."
  )

  attr(:on_select, :string,
    default: nil,
    doc: """
    Optional LiveView event pushed on selection — `%{"date" => iso}` in
    single mode, `%{"from" => iso | nil, "to" => iso | nil}` in range mode.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root.")

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  def calendar(assigns) do
    validate_in!(:mode, assigns.mode, @modes)
    validate_selected!(assigns.mode, assigns.selected)

    month = assigns[:month] || Date.utc_today()
    first = Date.beginning_of_month(month)

    assigns =
      assigns
      |> assign(
        month: month,
        first: first,
        today: Date.utc_today(),
        day_td_classes: Enum.join(@day_td_classes, " "),
        weeks: month_grid(first, assigns.week_starts_on, assigns.show_outside_days),
        weekdays: rotate_weekdays(assigns.week_starts_on),
        month_label: Calendar.strftime(first, "%B %Y"),
        caption_id: "#{assigns.id}-caption",
        prev_disabled: prev_disabled?(assigns.min_date, first),
        next_disabled: next_disabled?(assigns.max_date, first),
        hook: "#{inspect(__MODULE__)}.Root"
      )

    ~H"""
    <div
      id={@id}
      class={cn(["rounded-md border border-surface-border bg-surface-base p-3", @class])}
      data-polaris-calendar
      data-mode={@mode}
      data-month={Date.to_iso8601(@first)}
      data-week-start={@week_starts_on}
      data-outside={to_string(@show_outside_days)}
      data-min={@min_date && Date.to_iso8601(@min_date)}
      data-max={@max_date && Date.to_iso8601(@max_date)}
      data-selected={@mode == "single" && selection_iso(:single, @selected)}
      data-from={@mode == "range" && selection_iso(:from, @selected)}
      data-to={@mode == "range" && selection_iso(:to, @selected)}
      data-select-event={@on_select}
      phx-hook={@hook}
      {@rest}
    >
      <div class="relative flex flex-col space-y-4">
        <div class="space-y-4">
          <div class="flex items-center justify-center pt-1 relative">
            <button
              type="button"
              data-polaris-calendar-nav
              data-polaris-calendar-prev
              aria-label="Previous month"
              aria-disabled={to_string(@prev_disabled)}
              class={
                cn([
                  "inline-flex items-center justify-center rounded-md border border-surface-border bg-transparent",
                  "text-sm font-medium transition-colors hover:bg-surface-panel-hover hover:text-content-primary",
                  "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
                  "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
                  "h-7 w-7 cursor-pointer p-0 opacity-50 hover:opacity-100 z-5",
                  "aria-disabled:opacity-25 aria-disabled:hover:opacity-25 aria-disabled:cursor-not-allowed",
                  "absolute left-0 top-0"
                ])
              }
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
                class="h-4 w-4 pointer-events-none"
              >
                <path d="m15 18-6-6 6-6" />
              </svg>
            </button>
            <button
              type="button"
              data-polaris-calendar-nav
              data-polaris-calendar-next
              aria-label="Next month"
              aria-disabled={to_string(@next_disabled)}
              class={
                cn([
                  "inline-flex items-center justify-center rounded-md border border-surface-border bg-transparent",
                  "text-sm font-medium transition-colors hover:bg-surface-panel-hover hover:text-content-primary",
                  "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
                  "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
                  "h-7 w-7 cursor-pointer p-0 opacity-50 hover:opacity-100 z-5",
                  "aria-disabled:opacity-25 aria-disabled:hover:opacity-25 aria-disabled:cursor-not-allowed",
                  "absolute right-0 top-0"
                ])
              }
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
                class="h-4 w-4 pointer-events-none"
              >
                <path d="m9 18 6-6-6-6" />
              </svg>
            </button>
            <span
              id={@caption_id}
              class="text-sm font-medium"
              aria-live="polite"
              data-polaris-calendar-caption
            >
              {@month_label}
            </span>
          </div>
          <table
            class="w-full border-collapse space-y-1"
            role="grid"
            aria-labelledby={@caption_id}
            data-polaris-calendar-grid
          >
            <thead>
              <tr class="flex">
                <th
                  :for={{narrow, full} <- @weekdays}
                  scope="col"
                  aria-label={full}
                  class="text-center text-content-muted rounded-md w-9 font-normal text-[0.8rem]"
                >
                  {narrow}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :for={week <- @weeks} class="flex w-full mt-2">
                <td :for={cell <- week} class={@day_td_classes}>
                  <button
                    :if={cell}
                    type="button"
                    data-polaris-calendar-day
                    data-date={Date.to_iso8601(cell.date)}
                    aria-selected={to_string(day_selected?(@mode, @selected, cell.date))}
                    aria-disabled={to_string(day_disabled?(@min_date, @max_date, cell.date))}
                    aria-label={day_label(cell.date)}
                    tabindex="-1"
                    class={
                      day_button_classes(
                        @mode,
                        @selected,
                        @min_date,
                        @max_date,
                        @today,
                        cell
                      )
                    }
                  >
                    {cell.date.day}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const ds = this.el.dataset
          this._mode = ds.mode || "single"
          this._weekStart = parseInt(ds.weekStart || "0", 10)
          this._min = ds.min || null
          this._max = ds.max || null
          this._outside = ds.outside !== "false"
          this._selectEvent = ds.selectEvent
          if (this._mode === "single") {
            this._selected = ds.selected || null
          } else {
            this._from = ds.from || null
            this._to = ds.to || null
          }
          this._today = this._todayIso()
          const month = (ds.month || "").split("-")
          this._y = parseInt(month[0] || "1970", 10)
          this._m = parseInt(month[1] || "1", 10) - 1
          this._onClick = (event) => {
            const day = event.target.closest("[data-polaris-calendar-day]")
            if (day && this.el.contains(day)) {
              if (day.getAttribute("aria-disabled") === "true") return
              this._select(day.dataset.date)
              return
            }
            const prev = event.target.closest("[data-polaris-calendar-prev]")
            if (prev && this.el.contains(prev)) {
              if (prev.getAttribute("aria-disabled") === "true") return
              this._goMonth(-1)
              return
            }
            const next = event.target.closest("[data-polaris-calendar-next]")
            if (next && this.el.contains(next)) {
              if (next.getAttribute("aria-disabled") === "true") return
              this._goMonth(1)
            }
          }
          this._onKeydown = (event) => this._keydown(event)
          this.el.addEventListener("click", this._onClick)
          this.el.addEventListener("keydown", this._onKeydown)
          this._updateNav()
          this._rove()
        },
        updated() {
          // The hook is authoritative: re-render its month after patches,
          // restoring focus if a day had it.
          const focus = this._focusedIso()
          this._render(this._y, this._m)
          if (focus) this._focusDate(focus)
        },
        destroyed() {
          this.el.removeEventListener("click", this._onClick)
          this.el.removeEventListener("keydown", this._onKeydown)
        },
        // Month rendering — mirrors the server markup and class constants.
        _render(y, m) {
          this._y = y
          this._m = m
          const grid = this.el.querySelector("[data-polaris-calendar-grid]")
          const caption = this.el.querySelector("[data-polaris-calendar-caption]")
          if (caption) {
            caption.textContent = new Date(y, m, 1).toLocaleString("en-US", {
              month: "long",
              year: "numeric",
            })
          }
          if (grid) grid.innerHTML = this._tableHtml(y, m)
          this.el.dataset.month = this._iso(y, m, 1)
          this._updateNav()
          this._rove()
        },
        _tableHtml(y, m) {
          const order = []
          for (let i = 0; i < 7; i++) order.push((i + this._weekStart) % 7)
          const head =
            '<thead><tr class="flex">' +
            order
              .map(
                (i) =>
                  '<th scope="col" aria-label="' +
                  this.FULL_WEEKDAYS[i] +
                  '" class="text-center text-content-muted rounded-md w-9 font-normal text-[0.8rem]">' +
                  this.NARROW_WEEKDAYS[i] +
                  "</th>"
              )
              .join("") +
            "</tr></thead>"
          const lead = (new Date(y, m, 1).getDay() - this._weekStart + 7) % 7
          const last = new Date(y, m + 1, 0).getDate()
          const cells = []
          for (let i = 0; i < lead; i++) {
            cells.push(this._outside ? this._cellHtml(new Date(y, m, i - lead + 1)) : null)
          }
          for (let d = 1; d <= last; d++) cells.push(this._cellHtml(new Date(y, m, d)))
          let trail = 0
          while (cells.length % 7 !== 0) {
            trail++
            cells.push(this._outside ? this._cellHtml(new Date(y, m, last + trail)) : null)
          }
          const rows = []
          for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7))
          const body =
            "<tbody>" +
            rows
              .map(
                (row) =>
                  '<tr class="flex w-full mt-2">' +
                  row.map((c) => c || '<td class="' + this.TD_CLASSES + '"></td>').join("") +
                  "</tr>"
              )
              .join("") +
            "</tbody>"
          return head + body
        },
        _cellHtml(date) {
          const iso = this._isoFromDate(date)
          const outside = date.getMonth() !== this._m
          const disabled = this._isDisabled(iso)
          return (
            '<td class="' +
            this.TD_CLASSES +
            '">' +
            '<button type="button" data-polaris-calendar-day data-date="' +
            iso +
            '" class="' +
            this._dayClasses(iso, outside) +
            '" aria-selected="' +
            (this._isSelected(iso) ? "true" : "false") +
            '"' +
            (disabled ? ' aria-disabled="true"' : "") +
            ' aria-label="' +
            this._dayLabel(iso) +
            '" tabindex="-1">' +
            parseInt(iso.slice(8), 10) +
            "</button></td>"
          )
        },
        _dayClasses(iso, outside) {
          if (this._isDisabled(iso)) return [this.DAY_BASE, this.DAY_DISABLED].join(" ")
          const classes = [this.DAY_BASE, this.DAY_HOVER]
          if (this._mode === "single") {
            if (this._selected === iso) classes.push(this.SELECTED_CLASSES)
            else if (iso === this._today) classes.push(this.TODAY_CLASSES)
          } else {
            const full = this._from && this._to
            if (this._from === iso) classes.push(full ? this.RANGE_START_CLASSES : this.SELECTED_CLASSES)
            else if (full && iso === this._to) classes.push(this.RANGE_END_CLASSES)
            else if (full && iso > this._from && iso < this._to) classes.push(this.RANGE_MIDDLE_CLASSES)
            else if (iso === this._today) classes.push(this.TODAY_CLASSES)
          }
          if (outside) {
            classes.push(this._isSelected(iso) ? "opacity-100" : this.OUTSIDE_CLASSES)
          }
          return classes.join(" ")
        },
        _isSelected(iso) {
          if (this._mode === "single") return this._selected === iso
          if (!this._from) return false
          if (!this._to) return this._from === iso
          return iso >= this._from && iso <= this._to
        },
        _isDisabled(iso) {
          return (!!this._min && iso < this._min) || (!!this._max && iso > this._max)
        },
        _apply() {
          const monthKey = this._y + "-" + String(this._m + 1).padStart(2, "0")
          this.el.querySelectorAll("[data-polaris-calendar-day]").forEach((btn) => {
            const iso = btn.dataset.date
            btn.className = this._dayClasses(iso, !iso.startsWith(monthKey))
            btn.setAttribute("aria-selected", String(this._isSelected(iso)))
          })
          this._rove()
        },
        _select(iso) {
          if (this._mode === "single") {
            // Clicking the selected day clears it (RDP without `required`).
            this._selected = this._selected === iso ? null : iso
            this._apply()
            if (this._selectEvent && typeof this.pushEvent === "function") {
              this.pushEvent(this._selectEvent, { date: this._selected })
            }
          } else {
            if (!this._from || this._to) {
              this._from = iso
              this._to = null
            } else if (iso < this._from) {
              this._from = iso
            } else {
              this._to = iso
            }
            this._apply()
            if (this._selectEvent && typeof this.pushEvent === "function") {
              this.pushEvent(this._selectEvent, { from: this._from, to: this._to })
            }
          }
        },
        _goMonth(delta) {
          const target = new Date(this._y, this._m + delta, 1)
          let y = target.getFullYear()
          let m = target.getMonth()
          if (this._min) {
            const k = this._monthKey(this._min)
            if (y * 12 + m < k) {
              y = Math.floor(k / 12)
              m = k % 12
            }
          }
          if (this._max) {
            const k = this._monthKey(this._max)
            if (y * 12 + m > k) {
              y = Math.floor(k / 12)
              m = k % 12
            }
          }
          this._render(y, m)
        },
        _monthKey(iso) {
          return parseInt(iso.slice(0, 4), 10) * 12 + (parseInt(iso.slice(5, 7), 10) - 1)
        },
        _updateNav() {
          const key = this._y * 12 + this._m
          const prev = this.el.querySelector("[data-polaris-calendar-prev]")
          const next = this.el.querySelector("[data-polaris-calendar-next]")
          if (prev) {
            prev.setAttribute(
              "aria-disabled",
              String(!!this._min && key <= this._monthKey(this._min))
            )
          }
          if (next) {
            next.setAttribute(
              "aria-disabled",
              String(!!this._max && key >= this._monthKey(this._max))
            )
          }
        },
        _keydown(event) {
          const day = event.target.closest("[data-polaris-calendar-day]")
          if (!day || !this.el.contains(day)) return
          const iso = day.dataset.date
          let target = null
          let nav = 0
          switch (event.key) {
            case "ArrowLeft":
              target = this._addDays(iso, -1)
              break
            case "ArrowRight":
              target = this._addDays(iso, 1)
              break
            case "ArrowUp":
              target = this._addDays(iso, -7)
              break
            case "ArrowDown":
              target = this._addDays(iso, 7)
              break
            case "Home":
              target = this._weekBound(iso, true)
              break
            case "End":
              target = this._weekBound(iso, false)
              break
            case "PageUp":
              nav = event.shiftKey ? -12 : -1
              break
            case "PageDown":
              nav = event.shiftKey ? 12 : 1
              break
            default:
              return
          }
          event.preventDefault()
          if (nav) this._goMonth(nav)
          else this._focusDate(target)
        },
        _focusDate(iso) {
          let btn = this._dayButton(iso)
          if (!btn) {
            // The date lives in another month — render it, clamping to the
            // month's last day when the date does not exist.
            const y = parseInt(iso.slice(0, 4), 10)
            const m = parseInt(iso.slice(5, 7), 10) - 1
            this._render(y, m)
            btn = this._dayButton(iso) || this._dayButton(this._isoFromDate(new Date(y, m + 1, 0)))
          }
          if (btn) {
            btn.focus()
            this._rove()
          }
        },
        _dayButton(iso) {
          return this.el.querySelector('[data-date="' + iso + '"]')
        },
        _rove() {
          // One tab stop for the grid: the focused day, else the selected
          // day, else today, else the first day of the month.
          const days = Array.from(this.el.querySelectorAll("[data-polaris-calendar-day]"))
          if (days.length === 0) return
          const monthKey = this._y + "-" + String(this._m + 1).padStart(2, "0")
          const inMonth = (d) => d.dataset.date.startsWith(monthKey)
          const active =
            (days.includes(document.activeElement) && document.activeElement) ||
            days.find((d) => d.getAttribute("aria-selected") === "true" && inMonth(d)) ||
            days.find((d) => d.dataset.date === this._today && inMonth(d)) ||
            days.find(inMonth) ||
            days[0]
          for (const d of days) d.tabIndex = d === active ? 0 : -1
        },
        _focusedIso() {
          const el = document.activeElement
          if (el && this.el.contains(el) && el.dataset && el.dataset.date) return el.dataset.date
          return null
        },
        _addDays(iso, n) {
          const d = new Date(iso + "T00:00:00")
          d.setDate(d.getDate() + n)
          return this._isoFromDate(d)
        },
        _weekBound(iso, start) {
          const d = new Date(iso + "T00:00:00")
          const offset = (d.getDay() - this._weekStart + 7) % 7
          return this._addDays(iso, start ? -offset : 6 - offset)
        },
        _iso(y, m, d) {
          return y + "-" + String(m + 1).padStart(2, "0") + "-" + String(d).padStart(2, "0")
        },
        _isoFromDate(d) {
          return this._iso(d.getFullYear(), d.getMonth(), d.getDate())
        },
        _todayIso() {
          return this._isoFromDate(new Date())
        },
        _dayLabel(iso) {
          return new Date(iso + "T00:00:00").toLocaleDateString("en-US", {
            month: "long",
            day: "numeric",
            year: "numeric",
          })
        },
        // Class constants — mirrored from the Elixir module attributes.
        NARROW_WEEKDAYS: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"],
        FULL_WEEKDAYS: [
          "Sunday",
          "Monday",
          "Tuesday",
          "Wednesday",
          "Thursday",
          "Friday",
          "Saturday",
        ],
        TD_CLASSES:
          "text-center text-sm p-0 relative w-9 box-border first:[&:has([aria-selected])]:rounded-l-md last:[&:has([aria-selected])]:rounded-r-md focus-within:relative focus-within:z-20",
        DAY_BASE:
          "inline-flex h-9 w-9 items-center justify-center rounded-md p-0 font-normal text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground aria-selected:opacity-100 aria-selected:hover:bg-transparent aria-selected:hover:text-inherit",
        DAY_HOVER: "hover:bg-surface-panel-hover hover:text-content-primary",
        DAY_DISABLED: "cursor-not-allowed text-content-muted opacity-50",
        SELECTED_CLASSES: "bg-brand-emerald text-surface-ground rounded-md",
        RANGE_START_CLASSES: "bg-brand-emerald text-surface-ground rounded-l-md",
        RANGE_END_CLASSES: "bg-brand-emerald text-surface-ground rounded-r-md",
        RANGE_MIDDLE_CLASSES: "bg-brand-fill text-content-primary rounded-none",
        TODAY_CLASSES: "bg-surface-panel-hover text-content-primary rounded-md",
        OUTSIDE_CLASSES: "text-content-muted opacity-50"
      }
    </script>
    """
  end

  ## Grid construction

  # Cells for one month: leading outside days (or blanks), the month
  # itself, and trailing padding — chunked into 7-day weeks. A blank cell
  # (show_outside_days: false) renders as nil.
  defp month_grid(first, week_start, show_outside) do
    dow = Date.day_of_week(first)
    lead = rem(dow - week_start + 7, 7)
    last = Date.end_of_month(first)

    lead_cells =
      if show_outside,
        do: Enum.map(0..(lead - 1)//1, &cell(Date.add(first, &1 - lead), first)),
        else: List.duplicate(nil, lead)

    month_cells = Enum.map(Date.range(first, last), &cell(&1, first))

    days_count = last.day
    trail_count = rem(7 - rem(lead + days_count, 7), 7)

    trail_cells =
      if show_outside,
        do: Enum.map(1..trail_count//1, &cell(Date.add(last, &1), first)),
        else: List.duplicate(nil, trail_count)

    (lead_cells ++ month_cells ++ trail_cells) |> Enum.chunk_every(7)
  end

  defp cell(date, month_first), do: %{date: date, outside: date.month != month_first.month}

  defp rotate_weekdays(week_start) do
    @weekdays |> Enum.drop(week_start) |> Enum.concat(Enum.take(@weekdays, week_start))
  end

  ## Day classification

  defp day_button_classes(mode, selected, min_date, max_date, today, cell) do
    if day_disabled?(min_date, max_date, cell.date) do
      cn([@day_button_base, @day_button_disabled])
    else
      cn([
        @day_button_base,
        @day_button_hover,
        state_classes(mode, selected, today, cell),
        outside_classes(mode, selected, cell)
      ])
    end
  end

  defp state_classes("single", selected, today, cell) do
    cond do
      day_selected?("single", selected, cell.date) -> @selected_classes
      Date.compare(cell.date, today) == :eq -> @today_classes
      true -> []
    end
  end

  defp state_classes("range", selected, today, cell) do
    case selected do
      %{from: from} ->
        case Map.get(selected, :to) do
          nil ->
            if Date.compare(from, cell.date) == :eq,
              do: @selected_classes,
              else: today_or_nil(today, cell)

          %Date{} = to ->
            cond do
              Date.compare(from, cell.date) == :eq -> @range_start_classes
              Date.compare(to, cell.date) == :eq -> @range_end_classes
              in_range?(cell.date, from, to) -> @range_middle_classes
              true -> today_or_nil(today, cell)
            end
        end

      _ ->
        today_or_nil(today, cell)
    end
  end

  defp today_or_nil(today, cell) do
    if Date.compare(cell.date, today) == :eq, do: @today_classes, else: []
  end

  defp outside_classes(mode, selected, cell) do
    if cell.outside do
      if day_selected?(mode, selected, cell.date), do: "opacity-100", else: @outside_classes
    else
      []
    end
  end

  defp day_selected?("single", %Date{} = selected, date),
    do: Date.compare(selected, date) == :eq

  defp day_selected?("single", _selected, _date), do: false

  defp day_selected?("range", %{from: from} = selected, date) do
    case Map.get(selected, :to) do
      %Date{} = to -> Date.compare(date, from) != :lt and Date.compare(date, to) != :gt
      _ -> Date.compare(from, date) == :eq
    end
  end

  defp day_selected?("range", _selected, _date), do: false

  defp in_range?(date, from, to) do
    Date.compare(date, from) == :gt and Date.compare(date, to) == :lt
  end

  defp day_disabled?(min_date, max_date, date) do
    (min_date && Date.compare(date, min_date) == :lt) ||
      (max_date && Date.compare(date, max_date) == :gt) || false
  end

  defp day_label(date) do
    "#{Calendar.strftime(date, "%B")} #{date.day}, #{date.year}"
  end

  # ISO strings for the hook-seeding data attributes.
  defp selection_iso(:single, %Date{} = date), do: Date.to_iso8601(date)
  defp selection_iso(:single, _), do: nil

  defp selection_iso(:from, %{from: %Date{} = from}), do: Date.to_iso8601(from)
  defp selection_iso(:from, _), do: nil

  defp selection_iso(:to, %{to: %Date{} = to}), do: Date.to_iso8601(to)
  defp selection_iso(:to, _), do: nil

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end

  # Navigation stops at the month containing the min/max bound.
  defp prev_disabled?(nil, _first), do: false

  defp prev_disabled?(min_date, first),
    do: Date.compare(first, Date.beginning_of_month(min_date)) != :gt

  defp next_disabled?(nil, _first), do: false

  defp next_disabled?(max_date, first),
    do: Date.compare(first, Date.beginning_of_month(max_date)) != :lt

  defp validate_selected!("single", nil), do: :ok
  defp validate_selected!("single", %Date{}), do: :ok

  defp validate_selected!("single", other) do
    raise ArgumentError, """
    PolarisUI calendar: mode="single" expects selected to be a Date, \
    got: #{inspect(other)} — for a span use mode="range" with \
    selected={%{from: date, to: date}}.
    """
  end

  defp validate_selected!("range", nil), do: :ok

  defp validate_selected!("range", %{from: %Date{} = from} = selected) do
    case Map.get(selected, :to) do
      nil ->
        :ok

      %Date{} = to ->
        if Date.compare(to, from) == :lt, do: raise_to_before_from(from, to), else: :ok

      other ->
        raise ArgumentError, """
        PolarisUI calendar: range `to` must be a Date or nil, got: #{inspect(other)}.
        """
    end
  end

  defp validate_selected!("range", other) do
    raise ArgumentError, """
    PolarisUI calendar: mode="range" expects selected to be \
    %{from: Date, to: Date | nil}, got: #{inspect(other)}.
    """
  end

  defp raise_to_before_from(from, to) do
    raise ArgumentError, """
    PolarisUI calendar: range `to` (#{Date.to_iso8601(to)}) is before \
    `from` (#{Date.to_iso8601(from)}).
    """
  end
end
