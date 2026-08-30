defmodule PolarisUI.Components.ScrollArea do
  @moduledoc """
  The Polaris scroll area: native scrolling with Supabase-styled
  overlay scrollbars — the port of the Supabase design system ScrollArea
  (`packages/ui`, built on the Radix ScrollArea primitive).

  ## Anatomy

      <.scroll_area class="h-72 w-48 rounded-md border">
        <div class="p-4">
          <h4 class="mb-4 text-sm font-medium leading-none">Tags</h4>
          <p :for={tag <- @tags} class="py-2 text-sm">{tag}</p>
        </div>
      </.scroll_area>

      <.scroll_area orientation="horizontal" class="w-96 whitespace-nowrap rounded-md border">
        <div class="flex w-max gap-4 p-4">…fixed-width figures…</div>
      </.scroll_area>

    * **root** — `relative overflow-hidden`; callers add the demo chrome
      (`h-72 w-48 rounded-md border`) or any sized wrapper.
    * **viewport** — `h-full w-full` native scrolling with the native
      scrollbars hidden; the content keeps its natural width (the
      Radix `min-width: 100%` sizing).
    * **scrollbars** — absolutely-positioned overlay tracks (`w-2.5`,
      `p-px`, `touch-none select-none`) with `rounded-full
      bg-surface-border` pill thumbs, taking up no layout space — the
      Radix overlay model.

  ## Orientation

  `orientation` picks the overlay scrollbars: `vertical` (the source
  default — its `ScrollArea` renders exactly one vertical scrollbar),
  `horizontal` (the source's explicit `<ScrollBar orientation=
  "horizontal" />` child), or `both` (vertical + horizontal; the
  transparent tracks make the corner a no-op, so none is rendered).

  ## Visibility

  Like Radix, scrollbars come in behavior flavors via `type`:

    * `hover` (the default — the source passes no `type`) — visible
      while the pointer is over the area, hidden again 600ms after it
      leaves.
    * `scroll` — visible only while scrolling, hidden 600ms after it
      stops (pointer over a scrollbar holds it).
    * `always` — permanently visible.
    * `auto` — behaves like `hover`.

  Bars sit at `data-state="visible" | "hidden"` and fade with the
  source's `transition-colors`; thumbs only render when there is
  something to scroll (no phantom thumbs on short content).

  ## Interaction

  The colocated hook hides the native scrollbars, measures the
  viewport, and drives the overlay thumbs: scrolling moves them,
  dragging a thumb scrolls (pointer + touch), and a `ResizeObserver`
  re-measures when content or the area itself resizes. Keyboard and
  wheel scrolling stay native — the component only augments the
  chrome, like the source.

  No form participation or microcopy — the area is silent chrome.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @orientations ~w(vertical horizontal both)
  @types ~w(hover scroll always auto)

  @hook "#{inspect(__MODULE__)}.Root"

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the scroll area root — required because the colocated
    hook that drives the overlay scrollbars anchors on it.
    """
  )

  attr(:orientation, :string,
    values: @orientations,
    default: "vertical",
    doc: "Which overlay scrollbars to render: `vertical`, `horizontal`, or `both`."
  )

  attr(:type, :string,
    values: @types,
    default: "hover",
    doc: """
    When the scrollbars are visible — the Radix `type` prop. `hover`
    (the default) shows them while the pointer is over the area,
    `scroll` only while scrolling, `always` permanently.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the root — e.g. `h-72 w-48 rounded-md border`."
  )

  attr(:rest, :global, doc: "Forwarded to the root: `aria-label`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The scrollable content.")

  def scroll_area(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)
    validate_in!(:type, assigns.type, @types)

    assigns =
      assign(assigns,
        hook: @hook,
        root_classes: cn(["relative overflow-hidden", assigns.class]),
        viewport_classes:
          "h-full w-full overflow-auto rounded-[inherit] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
        show_vertical?: assigns.orientation in ~w(vertical both),
        show_horizontal?: assigns.orientation in ~w(horizontal both),
        vertical_bar_classes: vertical_bar_classes(),
        horizontal_bar_classes: horizontal_bar_classes()
      )

    ~H"""
    <div
      id={@id}
      data-polaris-scroll-area
      data-type={@type}
      class={@root_classes}
      phx-hook={@hook}
      {@rest}
    >
      <div data-polaris-scroll-viewport tabindex="0" class={@viewport_classes}>
        <div class="min-w-full">{render_slot(@inner_block)}</div>
      </div>
      <div
        :if={@show_vertical?}
        data-polaris-scroll-bar
        data-orientation="vertical"
        data-state="hidden"
        data-overflow="false"
        class={@vertical_bar_classes}
      >
        <div data-polaris-scroll-thumb class="relative flex-1 rounded-full bg-surface-border" />
      </div>
      <div
        :if={@show_horizontal?}
        data-polaris-scroll-bar
        data-orientation="horizontal"
        data-state="hidden"
        data-overflow="false"
        class={@horizontal_bar_classes}
      >
        <div data-polaris-scroll-thumb class="relative flex-1 rounded-full bg-surface-border" />
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          const viewport = () => root.querySelector("[data-polaris-scroll-viewport]")
          const bars = () => Array.from(root.querySelectorAll("[data-polaris-scroll-bar]"))
          const bar = (orientation) =>
            bars().find((el) => el.dataset.orientation === orientation)
          const thumb = (orientation) => {
            const b = bar(orientation)
            return b ? b.querySelector("[data-polaris-scroll-thumb]") : null
          }

          // Radix hides the scrollbars 600ms after the pointer leaves
          // (scrollHideDelay default).
          const HIDE_DELAY = 600
          this._hideTimer = null
          this._dragging = null

          const visible = (el, state) => {
            if (el) el.dataset.state = state
          }

          // Thumb geometry: size = viewport/scroll ratio of the track,
          // offset = scroll ratio of the track — the Radix model.
          this._syncBars = () => {
            const v = viewport()
            if (!v) return
            const vertical = bar("vertical")
            if (vertical) {
              const track = vertical.clientHeight
              const ratio = v.clientHeight / v.scrollHeight
              const overflow = v.scrollHeight - v.clientHeight > 1
              vertical.dataset.overflow = String(overflow)
              const t = thumb("vertical")
              if (t) {
                t.style.height = Math.max(ratio * track, 16) + "px"
                const scrollable = v.scrollHeight - v.clientHeight
                const y = scrollable > 0 ? (v.scrollTop / scrollable) * (track - t.offsetHeight) : 0
                t.style.transform = "translateY(" + y + "px)"
              }
            }
            const horizontal = bar("horizontal")
            if (horizontal) {
              const track = horizontal.clientWidth
              const ratio = v.clientWidth / v.scrollWidth
              const overflow = v.scrollWidth - v.clientWidth > 1
              horizontal.dataset.overflow = String(overflow)
              const t = thumb("horizontal")
              if (t) {
                t.style.width = Math.max(ratio * track, 16) + "px"
                const scrollable = v.scrollWidth - v.clientWidth
                const x = scrollable > 0 ? (v.scrollLeft / scrollable) * (track - t.offsetWidth) : 0
                t.style.transform = "translateX(" + x + "px)"
              }
            }
          }

          this._cancelHide = () => {
            if (this._hideTimer) {
              clearTimeout(this._hideTimer)
              this._hideTimer = null
            }
          }

          this._show = () => {
            this._cancelHide()
            bars().forEach((el) => visible(el, "visible"))
          }

          this._hideSoon = () => {
            this._cancelHide()
            this._hideTimer = setTimeout(() => {
              if (this._dragging) return
              bars().forEach((el) => visible(el, "hidden"))
            }, HIDE_DELAY)
          }

          const type = root.dataset.type || "hover"

          // type=always stays visible; everything else starts hidden.
          if (type === "always") {
            this._show()
          }

          this._onEnter = () => {
            if (type === "scroll") return
            this._show()
          }
          root.addEventListener("pointerenter", this._onEnter)

          this._onLeave = (event) => {
            if (type === "always" || type === "scroll") return
            // The pointer leaving the root area starts the hide clock.
            if (!root.contains(event.relatedTarget)) this._hideSoon()
          }
          root.addEventListener("pointerleave", this._onLeave)

          // Scrolling moves thumbs; type=scroll also reveals them for
          // the duration (interacting with a scrollbar holds it).
          this._onScroll = () => {
            this._syncBars()
            if (type === "scroll") {
              this._show()
              this._hideSoon()
            }
          }
          const v = viewport()
          if (v) v.addEventListener("scroll", this._onScroll, { passive: true })

          // Drag a thumb to scroll — pointer and touch alike.
          this._onThumbDown = (event) => {
            const t = event.target.closest("[data-polaris-scroll-thumb]")
            const b = t ? t.closest("[data-polaris-scroll-bar]") : null
            const vp = viewport()
            if (!t || !b || !vp) return
            event.preventDefault()
            this._dragging = b
            b.dataset.state = "visible"
            const horizontal = b.dataset.orientation === "horizontal"
            const start = horizontal ? event.clientX : event.clientY
            const scrollStart = horizontal ? vp.scrollLeft : vp.scrollTop
            const scale = horizontal
              ? vp.scrollWidth / Math.max(b.clientWidth - t.offsetWidth, 1)
              : vp.scrollHeight / Math.max(b.clientHeight - t.offsetHeight, 1)
            const onMove = (move) => {
              const current = horizontal ? move.clientX : move.clientY
              const delta = (current - start) * scale
              if (horizontal) {
                vp.scrollLeft = scrollStart + delta
              } else {
                vp.scrollTop = scrollStart + delta
              }
            }
            const onUp = () => {
              this._dragging = null
              document.removeEventListener("pointermove", onMove)
              document.removeEventListener("pointerup", onUp)
              if (type !== "always") this._hideSoon()
            }
            document.addEventListener("pointermove", onMove)
            document.addEventListener("pointerup", onUp)
          }
          root.addEventListener("pointerdown", this._onThumbDown)

          // Re-measure on content/area resizes — the Radix ResizeObserver.
          this._observer = new ResizeObserver(() => this._syncBars())
          if (v) this._observer.observe(v)
          if (v && v.firstElementChild) this._observer.observe(v.firstElementChild)
          this._syncBars()
        },
        updated() {
          // LiveView patches may stomp thumb styles; re-measure.
          this._syncBars()
        },
        destroyed() {
          if (this._observer) this._observer.disconnect()
          if (this._hideTimer) clearTimeout(this._hideTimer)
          if (!this.el) {
            return
          }
          this.el.removeEventListener("pointerenter", this._onEnter)
          this.el.removeEventListener("pointerleave", this._onLeave)
          this.el.removeEventListener("pointerdown", this._onThumbDown)
          const v = this.el.querySelector("[data-polaris-scroll-viewport]")
          if (v) v.removeEventListener("scroll", this._onScroll)
        }
      }
    </script>
    """
  end

  # The source's ScrollBar classes: the 10px overlay track with a 1px
  # transparent border + p-px keeping the 8px pill thumb centered.
  defp vertical_bar_classes do
    "absolute right-0 top-0 z-10 h-full w-2.5 border-l border-l-transparent p-px " <>
      "flex touch-none select-none transition-opacity opacity-0 " <>
      "data-[overflow=false]:hidden data-[state=visible]:opacity-100"
  end

  defp horizontal_bar_classes do
    "absolute bottom-0 left-0 z-10 h-2.5 w-full border-t border-t-transparent p-px " <>
      "flex touch-none select-none transition-opacity opacity-0 " <>
      "data-[overflow=false]:hidden data-[state=visible]:opacity-100"
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
