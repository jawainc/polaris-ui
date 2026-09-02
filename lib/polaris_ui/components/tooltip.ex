defmodule PolarisUI.Components.Tooltip do
  @moduledoc """
  The Polaris tooltip: a short non-interactive tip that appears when
  the pointer rests on — or the keyboard focuses — any trigger markup
  you choose — the port of the Supabase design system Tooltip
  (`packages/ui`, built on the Radix Tooltip primitive).

  Wrap your own trigger with `tooltip` when the control already
  exists (a button, an icon, a truncated cell). When the trigger is
  the design system's own fixed info glyph, use `info_tooltip`
  instead — and for rich, interactive floating content, the
  `hover_card` or `popover`.

  ## Anatomy

      <.tooltip id="row-actions-tip" side="bottom">
        <:trigger>
          <.button variant="ghost" size="tiny" aria-label="Row actions">
            <.icon name="ellipsis" />
          </.button>
        </:trigger>
        <:content>Row actions</:content>
      </.tooltip>

    * **trigger slot** — the anchor the tip hangs from; any markup,
      wrapped in an inline span like the hover card's trigger (the
      source's `TooltipTrigger asChild`).
    * **content slot** — the tip body in the source's compact panel
      (`z-50 overflow-hidden rounded-md border bg-surface-panel px-3
      py-1.5 text-xs shadow-md`), always in the DOM (`hidden` until
      opened), positioned beside the trigger by the hook.

  ## State model

  The hook owns the Radix timing contract:

    * **pointer rest** — the tip opens after `open_delay` (the Radix
      `delayDuration` default, 700ms).
    * **skip window** — closing records a page-wide timestamp; when a
      trigger is entered within `skip_delay` of any close (the Radix
      `skipDuration` default, 300ms — the `TooltipProvider` scope,
      shared by every Polaris tooltip on the page), the tip opens
      instantly. Hopping along a row of icons never re-pays the delay.
    * **keyboard** — focus on the trigger opens immediately, no
      delay; focus-out and **Escape** close.
    * **pointer leave closes at once** — tooltips are non-interactive
      and have *no grace area*: unlike the hover card, there is no
      close delay and no path from trigger into content that keeps
      the tip open. That is the deliberate difference from
      `hover_card`, which exists precisely to hold interactive
      content under a grace period.

  No server round-trip — visibility is entirely client-side, and a
  LiveView patch never snaps an open tip shut.

  ## States

    * **rest** — only the trigger shows; the panel is `hidden`.
    * **hover** — open after the delay (or instantly in the skip
      window); brightening the trigger on hover is the caller's —
      the tip itself carries no hover styling.
    * **focus** — open on trigger focus. The tip itself is
      non-interactive and gets no focus ring — it is never reachable
      by Tab, and **Escape** or moving focus closes it.
    * **disabled** — the caller disables their own trigger; a
      disabled control does not fire pointer/focus events, so the tip
      simply stops opening. Hide tips for controls whose action is
      unavailable.

  ## Positioning and motion

  `side` (`top`/`right`/`bottom`/`left`, default `top` — the Radix
  default, unlike the hover card's `bottom`) picks the edge, `align`
  (`start`/`center`/`end`, default `center`) the cross-axis position,
  and `side_offset` (the source pins Radix's `sideOffset` default,
  4px) the gap; the hook flips the side when the viewport runs out of
  room. The entrance is always the source's `fade-in-50` plus the
  per-side `slide-in-from-*` nudge, played through the Web Animations
  API and skipped under `prefers-reduced-motion`.

  ## Accessibility

    * The panel carries `role="tooltip"` and the derived id
      `<id>-content`; while open, the hook points the trigger's
      `aria-describedby` at it (the Radix behavior), so the tip text
      is announced alongside the trigger's label.
    * Keyboard users get the tip on focus; **Escape** closes.
    * Keep the content plain text — it is reachable by neither Tab
      nor pointer intent.

  ## Microcopy

  Per the Supabase copywriting guidelines: a short noun phrase or
  imperative hint that clarifies ("Row actions", "Opens the logs") —
  never a duplicate of the trigger's visible label, which the user
  can already read. Sentence case, no trailing period.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @sides ~w(top right bottom left)
  @alignments ~w(start center end)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the tooltip root — required because the colocated
    hook that manages open/close state anchors on it. The panel id
    derives as `"<id>-content"`.
    """
  )

  attr(:open_delay, :integer,
    default: 700,
    doc: """
    Milliseconds the pointer must rest on the trigger before opening —
    the Radix `delayDuration` default.
    """
  )

  attr(:skip_delay, :integer,
    default: 300,
    doc: """
    Milliseconds after a close during which entering any tooltip
    trigger opens instantly — the Radix `skipDuration` default. The
    window is shared page-wide by all Polaris tooltips.
    """
  )

  attr(:side, :string,
    values: @sides,
    default: "top",
    doc: """
    Edge of the trigger the tip anchors to — `top`, the Radix default
    (unlike the hover card's `bottom`). The hook flips it when the
    viewport runs out.
    """
  )

  attr(:align, :string,
    values: @alignments,
    default: "center",
    doc: "Cross-axis position of the tip relative to the trigger."
  )

  attr(:side_offset, :integer,
    default: 4,
    doc: "Gap between trigger and tip in pixels — the source pins Radix's `sideOffset` default."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the tip panel (e.g. `max-w-[280px]`)."
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  slot(:trigger,
    required: true,
    doc: "The anchor the tip hangs from — any markup, wrapped like the hover card's trigger."
  )

  slot(:content, required: true, doc: "The tip body — a short clarifier, plain text.")

  def tooltip(assigns) do
    validate_in!(:side, assigns.side, @sides)
    validate_in!(:align, assigns.align, @alignments)

    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Tip",
        content_classes:
          cn([
            "absolute z-50 overflow-hidden rounded-md border border-surface-border",
            "bg-surface-panel px-3 py-1.5 text-xs text-content-primary shadow-md",
            assigns.class
          ])
      )

    ~H"""
    <div
      id={@id}
      class="relative inline-flex max-w-full"
      data-polaris-tooltip
      data-state="closed"
      data-open-delay={to_string(@open_delay)}
      data-skip-delay={to_string(@skip_delay)}
      data-side={@side}
      data-align={@align}
      data-side-offset={to_string(@side_offset)}
      phx-hook={@hook}
      {@rest}
    >
      <span data-polaris-tooltip-trigger class="inline-flex max-w-full">
        {render_slot(@trigger)}
      </span>
      <div
        id={"#{@id}-content"}
        role="tooltip"
        data-polaris-tooltip-content
        hidden
        class={@content_classes}
      >
        {render_slot(@content)}
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Tip" runtime>
      {
        mounted() {
          const root = this.el
          const triggerWrap = () => root.querySelector("[data-polaris-tooltip-trigger]")
          const content = () => root.querySelector("[data-polaris-tooltip-content]")
          this._open = false
          this._openTimer = null

          // The Radix skipDuration scope: the last close timestamp is
          // shared page-wide, so hopping between tooltips never re-pays
          // the open delay (the TooltipProvider contract).
          const lastClosedAt = () => window.__polarisTooltipClosedAt || 0

          this._clearOpenTimer = () => {
            if (this._openTimer) {
              clearTimeout(this._openTimer)
              this._openTimer = null
            }
          }

          this._show = () => {
            if (this._open) return
            const c = content()
            if (!c) return
            this._clearOpenTimer()
            this._open = true
            c.removeAttribute("hidden")
            c.setAttribute("data-state", "open")
            root.dataset.state = "open"
            this._position()
            this._describe(true)
            this._animateIn(c)
          }

          this._hide = () => {
            if (!this._open) return
            this._clearOpenTimer()
            this._open = false
            const c = content()
            if (c) {
              c.setAttribute("hidden", "")
              c.setAttribute("data-state", "closed")
            }
            root.dataset.state = "closed"
            window.__polarisTooltipClosedAt = Date.now()
            this._describe(false)
          }

          // Hover intent: rest on the trigger for openDelay — unless a
          // tooltip closed within skipDelay, then open at once.
          this._scheduleOpen = () => {
            if (this._open || this._openTimer) return
            const skip = parseInt(root.dataset.skipDelay || "300", 10)
            if (Date.now() - lastClosedAt() < skip) {
              this._show()
              return
            }
            const delay = parseInt(root.dataset.openDelay || "700", 10)
            this._openTimer = setTimeout(() => {
              this._openTimer = null
              this._show()
            }, delay)
          }

          // Absolute positioning inside the relative root, measured from
          // the trigger — side/align/offset with a viewport flip, like Radix.
          this._position = () => {
            const c = content()
            const wrap = triggerWrap()
            if (!c || !wrap) {
              return
            }
            const side = root.dataset.side || "top"
            const align = root.dataset.align || "center"
            const offset = parseInt(root.dataset.sideOffset || "4", 10)
            c.style.visibility = "hidden"
            c.style.top = ""
            c.style.bottom = ""
            c.style.left = ""
            c.style.right = ""
            c.style.transform = ""
            const place = (side) => {
              const t = wrap.offsetLeft
              const tt = wrap.offsetTop
              if (side === "bottom") {
                c.style.top = tt + wrap.offsetHeight + offset + "px"
              } else if (side === "top") {
                c.style.bottom = root.offsetHeight - tt + offset + "px"
              } else if (side === "right") {
                c.style.left = t + wrap.offsetWidth + offset + "px"
              } else {
                c.style.right = root.offsetWidth - t + offset + "px"
              }
              if (side === "bottom" || side === "top") {
                if (align === "start") {
                  c.style.left = t + "px"
                } else if (align === "end") {
                  c.style.left = t + wrap.offsetWidth - c.offsetWidth + "px"
                } else {
                  c.style.left = t + wrap.offsetWidth / 2 + "px"
                  c.style.transform = "translateX(-50%)"
                }
              } else {
                if (align === "start") {
                  c.style.top = tt + "px"
                } else if (align === "end") {
                  c.style.top = tt + wrap.offsetHeight - c.offsetHeight + "px"
                } else {
                  c.style.top = tt + wrap.offsetHeight / 2 + "px"
                  c.style.transform = "translateY(-50%)"
                }
              }
            }
            place(side)
            // Flip when the tip spills past the viewport and the opposite
            // side has more room (the Radix collision behavior, simplified).
            const rect = c.getBoundingClientRect()
            const spills = side === "bottom"
              ? rect.bottom > window.innerHeight
              : side === "top"
                ? rect.top < 0
                : side === "right"
                  ? rect.right > window.innerWidth
                  : rect.left < 0
            if (spills) {
              const flipped = { bottom: "top", top: "bottom", right: "left", left: "right" }[side]
              place(flipped)
            }
            c.style.visibility = ""
          }

          // While open, the trigger is described by the tip (the Radix
          // behavior): aria-describedby points the first element inside
          // the trigger wrap at the panel, and comes off on close.
          this._describe = (on) => {
            const wrap = triggerWrap()
            const c = content()
            if (!wrap || !c) return
            const target = wrap.firstElementChild || wrap
            if (on) {
              target.setAttribute("aria-describedby", c.id)
            } else {
              target.removeAttribute("aria-describedby")
            }
          }

          // The source's fade-in-50 + per-side slide-in-from-*: 4px in
          // from the active side while fading from 50%. Played on the
          // `translate` property so the entrance never collides with the
          // center-align `transform`; skipped under reduced motion.
          this._animateIn = (c) => {
            if (typeof c.animate !== "function") return
            if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
            const side = root.dataset.side || "top"
            const slide = {
              top: "0 0.25rem",
              bottom: "0 -0.25rem",
              left: "0.25rem 0",
              right: "-0.25rem 0",
            }[side]
            c.animate(
              [{ opacity: 0.5, translate: slide }, { opacity: 1, translate: "0 0" }],
              { duration: 150, easing: "ease-out" }
            )
          }

          this._onPointerEnter = (event) => {
            const wrap = triggerWrap()
            if (wrap && wrap.contains(event.target)) {
              this._scheduleOpen()
            }
          }
          root.addEventListener("pointerenter", this._onPointerEnter, true)

          // No grace area: leaving the trigger closes at once (the
          // deliberate difference from the hover card).
          this._onPointerLeave = (event) => {
            const wrap = triggerWrap()
            if (!wrap || !wrap.contains(event.target)) return
            const to = event.relatedTarget
            if (!(to && wrap.contains(to))) {
              this._hide()
            }
          }
          root.addEventListener("pointerleave", this._onPointerLeave, true)

          // Keyboard: focus opens immediately (the Radix open-on-focus);
          // focus-out and Escape close.
          this._onFocusIn = (event) => {
            const wrap = triggerWrap()
            if (wrap && wrap.contains(event.target)) {
              this._show()
            }
          }
          root.addEventListener("focusin", this._onFocusIn)

          this._onFocusOut = (event) => {
            const wrap = triggerWrap()
            const to = event.relatedTarget
            if (!(wrap && to && wrap.contains(to))) {
              this._hide()
            }
          }
          root.addEventListener("focusout", this._onFocusOut)

          this._onKeydown = (event) => {
            if (event.key === "Escape" && this._open) {
              event.preventDefault()
              this._hide()
            }
          }
          document.addEventListener("keydown", this._onKeydown, true)

          // A LiveView patch never snaps an open tip shut.
          this._afterUpdate = () => {
            if (this._open) {
              const c = content()
              if (c) {
                c.removeAttribute("hidden")
                c.setAttribute("data-state", "open")
              }
              root.dataset.state = "open"
              this._position()
              this._describe(true)
            }
          }
        },
        updated() {
          this._afterUpdate()
        },
        destroyed() {
          this._clearOpenTimer()
          if (!this.el) {
            return
          }
          this._describe(false)
          this.el.removeEventListener("pointerenter", this._onPointerEnter, true)
          this.el.removeEventListener("pointerleave", this._onPointerLeave, true)
          this.el.removeEventListener("focusin", this._onFocusIn)
          this.el.removeEventListener("focusout", this._onFocusOut)
          document.removeEventListener("keydown", this._onKeydown, true)
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
end
