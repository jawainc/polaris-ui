defmodule PolarisUI.Components.HoverCard do
  @moduledoc """
  The Polaris hover card: a floating preview panel that appears when
  the pointer rests on a trigger — the port of the Supabase design
  system Hover Card (`packages/ui`, built on the Radix HoverCard
  primitive).

  For rich, complementary preview content behind a link — the user
  card behind an @mention, the project card behind a name. For a
  one-sentence clarifier, use the Info Tooltip instead; for
  interactive content, the Popover.

  ## Anatomy

      <.hover_card id="nextjs-card">
        <:trigger>
          <a href="https://nextjs.org" class="underline text-brand-emerald">@nextjs</a>
        </:trigger>
        <:content>
          <div class="flex justify-between space-x-4">
            <.avatar src="https://github.com/vercel.png" fallback="VC" />
            <div class="space-y-1">
              <h4 class="text-sm font-semibold">@nextjs</h4>
              <p class="text-sm">The React Framework – created and maintained by @vercel.</p>
            </div>
          </div>
        </:content>
      </.hover_card>

    * **trigger slot** — the anchor the preview hangs from; any markup
      (the source's `HoverCardTrigger asChild`).
    * **content** — the panel (`z-50 w-64 rounded-md border
      bg-surface-panel p-4 shadow-md`), always in the DOM (`hidden`
      until opened), positioned beside the trigger by the hook.

  ## Hover intent

  The hook owns the Radix timing contract: the card opens after the
  pointer rests on the trigger for `open_delay` (the Radix default
  700ms) and closes `close_delay` after the pointer leaves (300ms) —
  and moving the pointer from the trigger into the content keeps it
  open (the grace-area behavior: entering the content cancels the
  close timer). Focus on the trigger opens the card for keyboard users
  immediately; **Escape** and focus-out close it. No server round-trip
  — like the Info Tooltip, visibility is entirely client-side, and a
  LiveView patch never snaps an open card shut.

  ## Positioning and motion

  `side` (`top`/`right`/`bottom`/`left`, default `bottom`) picks the
  edge, `align` (`start`/`center`/`end`, default `center`) the
  cross-axis position, and `side_offset` (the source sets Radix's 4px
  default) the gap; the hook flips the side when the viewport runs out
  of room. `animate` picks the entrance: `zoom-in` (the default — the
  source's near-imperceptible 99% scale) or `slide-in` (fade plus a
  directional nudge keyed off the side).

  ## Microcopy

  Per the Supabase copywriting guidelines: the card is a preview —
  keep it scannable (a name, one or two sentences), and let the
  trigger carry the action.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @sides ~w(top right bottom left)
  @alignments ~w(start center end)
  @animations ~w(zoom-in slide-in)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the hover card root — required because the colocated
    hook that manages hover intent and positioning anchors on it.
    """
  )

  attr(:open_delay, :integer,
    default: 700,
    doc: "Milliseconds the pointer must rest on the trigger before opening — the Radix default."
  )

  attr(:close_delay, :integer,
    default: 300,
    doc: """
    Milliseconds the pointer may stray (off trigger and content) before
    closing — the Radix default grace period.
    """
  )

  attr(:side, :string,
    values: @sides,
    default: "bottom",
    doc: "Edge of the trigger the card anchors to. The hook flips it when the viewport runs out."
  )

  attr(:align, :string,
    values: @alignments,
    default: "center",
    doc: "Cross-axis position of the card relative to the trigger (the source pins `center`)."
  )

  attr(:side_offset, :integer,
    default: 4,
    doc: "Gap between trigger and card in pixels — the source pins Radix's `sideOffset` default."
  )

  attr(:animate, :string,
    values: @animations,
    default: "zoom-in",
    doc: """
    Entrance motion: `zoom-in` (the source default — a subtle 99% scale)
    or `slide-in` (fade plus a directional nudge).
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the content panel (e.g. `w-80`)."
  )

  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, `phx-*`, …")

  slot(:trigger,
    required: true,
    doc: "The anchor the preview hangs from — any markup."
  )

  slot(:content, required: true, doc: "The floating preview panel's body.")

  def hover_card(assigns) do
    validate_in!(:side, assigns.side, @sides)
    validate_in!(:align, assigns.align, @alignments)
    validate_in!(:animate, assigns.animate, @animations)

    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        content_classes:
          cn([
            "absolute z-50 w-64 rounded-md border border-surface-border",
            "bg-surface-panel p-4 text-content-primary shadow-md outline-none",
            assigns.class
          ])
      )

    ~H"""
    <div
      id={@id}
      class="relative inline-flex max-w-full"
      data-polaris-hover-card
      data-state="closed"
      data-open-delay={to_string(@open_delay)}
      data-close-delay={to_string(@close_delay)}
      data-side={@side}
      data-align={@align}
      data-side-offset={to_string(@side_offset)}
      data-animate={@animate}
      phx-hook={@hook}
      {@rest}
    >
      <span data-polaris-hover-card-trigger class="inline-flex max-w-full">
        {render_slot(@trigger)}
      </span>
      <div data-polaris-hover-card-content hidden class={@content_classes}>
        {render_slot(@content)}
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          const triggerWrap = () => root.querySelector("[data-polaris-hover-card-trigger]")
          const content = () => root.querySelector("[data-polaris-hover-card-content]")
          this._open = false
          this._openTimer = null
          this._closeTimer = null

          this._clearTimers = () => {
            if (this._openTimer) {
              clearTimeout(this._openTimer)
              this._openTimer = null
            }
            if (this._closeTimer) {
              clearTimeout(this._closeTimer)
              this._closeTimer = null
            }
          }

          this._show = () => {
            if (this._open) return
            const c = content()
            if (!c) return
            this._clearTimers()
            this._open = true
            c.removeAttribute("hidden")
            c.setAttribute("data-state", "open")
            root.dataset.state = "open"
            this._position()
            this._animateIn(c)
          }

          this._hide = () => {
            if (!this._open) return
            this._clearTimers()
            this._open = false
            const c = content()
            if (c) {
              c.setAttribute("hidden", "")
              c.setAttribute("data-state", "closed")
            }
            root.dataset.state = "closed"
          }

          // The grace-area contract: leaving the trigger schedules the
          // close after closeDelay; entering either the trigger or the
          // content cancels it.
          this._scheduleOpen = () => {
            if (this._closeTimer) {
              clearTimeout(this._closeTimer)
              this._closeTimer = null
            }
            if (this._open || this._openTimer) return
            const delay = parseInt(root.dataset.openDelay || "700", 10)
            this._openTimer = setTimeout(() => {
              this._openTimer = null
              this._show()
            }, delay)
          }

          this._scheduleClose = () => {
            if (this._openTimer) {
              clearTimeout(this._openTimer)
              this._openTimer = null
            }
            if (!this._open || this._closeTimer) return
            const delay = parseInt(root.dataset.closeDelay || "300", 10)
            this._closeTimer = setTimeout(() => {
              this._closeTimer = null
              this._hide()
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
            const side = root.dataset.side || "bottom"
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
            // Flip when the panel spills past the viewport and the opposite
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

          // The source's two entrances: `zoom-in` scales in from 99% (a
          // nearly imperceptible settle); `slide-in` fades from 50% with a
          // directional nudge keyed off the side.
          this._animateIn = (c) => {
            if (typeof c.animate !== "function") return
            const mode = root.dataset.animate || "zoom-in"
            const side = root.dataset.side || "bottom"
            const keyframes =
              mode === "slide-in"
                ? (() => {
                    const slide = {
                      bottom: "translateY(-0.25rem)",
                      top: "translateY(0.25rem)",
                      right: "translateX(-0.25rem)",
                      left: "translateX(0.25rem)",
                    }[side]
                    return [
                      { opacity: 0.5, transform: slide },
                      { opacity: 1, transform: "none" },
                    ]
                  })()
                : [
                    { opacity: 0, transform: "scale(0.99)" },
                    { opacity: 1, transform: "scale(1)" },
                  ]
            const entrance = c.animate(keyframes, { duration: 150, easing: "ease-out" })
            entrance.finished
              .then(() => {
                c.style.transform = ""
              })
              .catch(() => {})
          }

          this._onPointerEnter = (event) => {
            const wrap = triggerWrap()
            const c = content()
            if ((wrap && wrap.contains(event.target)) || (c && c.contains(event.target))) {
              this._scheduleOpen()
            }
          }
          root.addEventListener("pointerenter", this._onPointerEnter, true)

          this._onPointerLeave = (event) => {
            const wrap = triggerWrap()
            const c = content()
            const inside =
              (wrap && wrap.contains(event.target)) || (c && c.contains(event.target))
            const to = event.relatedTarget
            const staying = to && ((wrap && wrap.contains(to)) || (c && c.contains(to)))
            if (inside && !staying) {
              this._scheduleClose()
            }
          }
          root.addEventListener("pointerleave", this._onPointerLeave, true)

          // Keyboard: focus on the trigger opens immediately (the Radix
          // open-on-focus); Escape and blur close.
          this._onFocusIn = (event) => {
            const wrap = triggerWrap()
            if (wrap && wrap.contains(event.target)) {
              this._show()
            }
          }
          root.addEventListener("focusin", this._onFocusIn)

          this._onFocusOut = (event) => {
            const wrap = triggerWrap()
            const c = content()
            const to = event.relatedTarget
            const staying = to && ((wrap && wrap.contains(to)) || (c && c.contains(to)))
            if (!staying) {
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

          // A LiveView patch never snaps an open card shut.
          this._afterUpdate = () => {
            if (this._open) {
              const c = content()
              if (c) {
                c.removeAttribute("hidden")
                c.setAttribute("data-state", "open")
              }
              root.dataset.state = "open"
              this._position()
            }
          }
        },
        updated() {
          this._afterUpdate()
        },
        destroyed() {
          this._clearTimers()
          if (!this.el) {
            return
          }
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
