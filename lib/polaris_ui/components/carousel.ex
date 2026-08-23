defmodule PolarisUI.Components.Carousel do
  @moduledoc """
  The Polaris carousel: a horizontal (or vertical) slideshow with motion
  and swipe — the port of the shadcn/ui Carousel that the Supabase design
  system documents (`apps/design-system/content/docs/components/carousel.mdx`,
  an embla-carousel wrapper; Supabase ships no source of its own).

  Where embla drives the track with transforms, the Polaris engine is a
  colocated runtime hook over **CSS scroll-snap**: the viewport is a
  snapped scroll container, so touch swipes, trackpads, and
  shift-scroll all work natively; the hook adds prev/next scrolling,
  mouse drag, arrow-key navigation, and button enablement.

  ## Anatomy

      <.carousel id="features">
        <.carousel_content>
          <.carousel_item>…</.carousel_item>
          <.carousel_item class="md:basis-1/2">…</.carousel_item>
        </.carousel_content>
        <.carousel_previous />
        <.carousel_next />
      </.carousel>

    * **root** — the `role="region"` `aria-roledescription="carousel"`
      wrapper that carries `orientation` for the hook.
    * **content** — the snapped viewport plus the flex track (the
      `-ml-4`/`pl-4` negative-margin spacing model from the source).
    * **item** — one slide: `min-w-0 shrink-0 grow-0 basis-full` +
      `snap-start`, a `role="group"` `aria-roledescription="slide"`.
      Multi-per-view slides set `class="basis-1/3"` (responsive:
      `md:basis-1/2 lg:basis-1/3`).
    * **previous / next** — the 32px circular outline buttons, floated
      outside the viewport edges, disabled at the track bounds, with
      sr-only labels.

  ## Orientation

  Subcomponents are separate function components, so each takes the same
  `orientation` as the root (like the shadcn context, made explicit) —
  thread it through when going vertical:

      <.carousel id="picker" orientation="vertical" class="max-w-sm">
        <.carousel_content orientation="vertical">
          <.carousel_item orientation="vertical">…</.carousel_item>
        </.carousel_content>
        <.carousel_previous orientation="vertical" />
        <.carousel_next orientation="vertical" />
      </.carousel>

  ## Interaction model

  The hook computes snap points from the items' offsets: prev/next
  scroll one snap with smooth motion, the buttons disable at the ends
  (embla's `canScrollPrev`/`canScrollNext`, tracked on scroll), arrows
  navigate from anywhere inside the region, and pointer drag scrolls
  directly (clicks after a drag are suppressed). On each snap settle it
  pushes `on_change` with `%{"selected" => index, "count" => slides}`
  (0-based) — build "Slide 1 of 5" counters from it.

  ## States

    * **rest / hover** — the nav buttons carry the outline treatment:
      panel fill and border brightening on hover.
    * **focus-ring** — high-visibility emerald ring on the nav buttons,
      `:focus-visible` only.
    * **disabled** — nav buttons natively `disabled` at the track
      bounds: `cursor-not-allowed` at 50% opacity.
    * **motion** — smooth scrolling follows the browser's own motion
      settings; drag and swipe are pointer-native.

  ## Accessibility

    * The root is a labelled region — give it an `aria-label` through
      the global attributes when it stands alone.
    * Slides are `role="group"` / `aria-roledescription="slide"`;
      navigation buttons carry sr-only "Previous slide" / "Next slide".
    * Keyboard: arrows move between snaps from anywhere inside the
      region (the key is consumed so the page never scrolls alongside).

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @orientations ~w(horizontal vertical)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the carousel root — required because the colocated hook
    that drives scrolling anchors on it.
    """
  )

  attr(:orientation, :string,
    values: @orientations,
    default: "horizontal",
    doc: """
    Scroll axis — `"horizontal"` (default) or `"vertical"`. Pass the same
    value to the content, item, and nav subcomponents.
    """
  )

  attr(:on_change, :string,
    default: nil,
    doc: """
    Optional LiveView event pushed when a snap settles, with
    `%{"selected" => index, "count" => slides}` (0-based).
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root.")

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `aria-label`, `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "Content, then the previous/next buttons.")

  def carousel(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)

    assigns = assign(assigns, hook: "#{inspect(__MODULE__)}.Root")

    ~H"""
    <div
      id={@id}
      class={cn(["relative", @class])}
      role="region"
      aria-roledescription="carousel"
      data-polaris-carousel
      data-orientation={@orientation}
      data-change-event={@on_change}
      phx-hook={@hook}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          this._viewport = this.el.querySelector("[data-polaris-carousel-viewport]")
          this._track = this.el.querySelector("[data-polaris-carousel-track]")
          this._prev = this.el.querySelector("[data-polaris-carousel-previous]")
          this._next = this.el.querySelector("[data-polaris-carousel-next]")
          this._vertical = this.el.dataset.orientation === "vertical"
          this._dragging = false
          this._onScroll = () => {
            this._updateButtons()
            this._scheduleChange()
          }
          this._onKeydown = (event) => {
            const prev = this._vertical ? "ArrowUp" : "ArrowLeft"
            const next = this._vertical ? "ArrowDown" : "ArrowRight"
            if (event.key === prev) {
              event.preventDefault()
              this.scrollPrev()
            } else if (event.key === next) {
              event.preventDefault()
              this.scrollNext()
            }
          }
          this._onPointerDown = (event) => this._dragStart(event)
          this._onPointerMove = (event) => this._dragMove(event)
          this._onPointerUp = () => this._dragEnd()
          this._onClickCapture = (event) => {
            // Suppress the click that follows a drag so slide links don't fire.
            if (this._dragging) {
              event.preventDefault()
              event.stopPropagation()
              this._dragging = false
            }
          }
          if (this._viewport) {
            this._viewport.addEventListener("scroll", this._onScroll, { passive: true })
            this._viewport.addEventListener("pointerdown", this._onPointerDown)
          }
          this.el.addEventListener("keydown", this._onKeydown)
          this.el.addEventListener("click", this._onClickCapture, true)
          window.addEventListener("pointermove", this._onPointerMove)
          window.addEventListener("pointerup", this._onPointerUp)
          this._updateButtons()
        },
        updated() {
          // LiveView patches may swap the viewport/track; re-sync buttons.
          this._viewport = this.el.querySelector("[data-polaris-carousel-viewport]")
          this._track = this.el.querySelector("[data-polaris-carousel-track]")
          this._prev = this.el.querySelector("[data-polaris-carousel-previous]")
          this._next = this.el.querySelector("[data-polaris-carousel-next]")
          this._updateButtons()
        },
        destroyed() {
          if (this._viewport) {
            this._viewport.removeEventListener("scroll", this._onScroll)
            this._viewport.removeEventListener("pointerdown", this._onPointerDown)
          }
          this.el.removeEventListener("keydown", this._onKeydown)
          this.el.removeEventListener("click", this._onClickCapture, true)
          window.removeEventListener("pointermove", this._onPointerMove)
          window.removeEventListener("pointerup", this._onPointerUp)
        },
        // The scroll-snap engine — embla's scrollPrev/scrollNext/canScroll*
        // over a snapped viewport.
        _items() {
          if (!this._track) return []
          return Array.from(this._track.querySelectorAll("[data-polaris-carousel-item]"))
        },
        _snaps() {
          return this._items().map((item) => (this._vertical ? item.offsetTop : item.offsetLeft))
        },
        _pos() {
          if (!this._viewport) return 0
          return this._vertical ? this._viewport.scrollTop : this._viewport.scrollLeft
        },
        _current() {
          const snaps = this._snaps()
          if (snaps.length === 0) return 0
          const pos = this._pos()
          let best = 0
          for (let i = 1; i < snaps.length; i++) {
            if (Math.abs(snaps[i] - pos) < Math.abs(snaps[best] - pos)) best = i
          }
          return best
        },
        _scrollToIndex(index, smooth) {
          if (!this._viewport) return
          const snaps = this._snaps()
          if (snaps.length === 0) return
          const target = Math.max(0, Math.min(snaps.length - 1, index))
          this._viewport.scrollTo({
            [this._vertical ? "top" : "left"]: snaps[target],
            behavior: smooth === false ? "auto" : "smooth",
          })
        },
        scrollPrev() {
          this._scrollToIndex(this._current() - 1)
        },
        scrollNext() {
          this._scrollToIndex(this._current() + 1)
        },
        _updateButtons() {
          if (!this._viewport) return
          const pos = this._pos()
          const max =
            (this._vertical ? this._viewport.scrollHeight : this._viewport.scrollWidth) -
            (this._vertical ? this._viewport.clientHeight : this._viewport.clientWidth)
          if (this._prev) this._prev.disabled = pos <= 1
          if (this._next) this._next.disabled = pos >= max - 1
        },
        _scheduleChange() {
          window.clearTimeout(this._changeTimer)
          this._changeTimer = window.setTimeout(() => {
            const name = this.el.dataset.changeEvent
            if (name && typeof this.pushEvent === "function") {
              this.pushEvent(name, { selected: this._current(), count: this._snaps().length })
            }
          }, 150)
        },
        // Pointer drag — direct scrolling while held, snap-realignment on release.
        _dragStart(event) {
          if (event.button !== 0 || !this._viewport) return
          this._dragStartPos = this._vertical ? event.clientY : event.clientX
          this._dragStartScroll = this._pos()
          this._dragMoved = 0
        },
        _dragMove(event) {
          if (this._dragStartPos === undefined || !this._viewport) return
          const current = this._vertical ? event.clientY : event.clientX
          const delta = current - this._dragStartPos
          if (Math.abs(delta) > 5) this._dragging = true
          this._dragMoved = delta
          const axis = this._vertical ? "top" : "left"
          this._viewport.scrollTo({ [axis]: this._dragStartScroll - delta, behavior: "auto" })
        },
        _dragEnd() {
          if (this._dragStartPos === undefined) return
          const moved = this._dragMoved
          this._dragStartPos = undefined
          this._dragStartScroll = undefined
          if (this._viewport && Math.abs(moved) > 5) {
            this._scrollToIndex(this._current())
          }
        }
      }
    </script>
    """
  end

  attr(:orientation, :string,
    values: @orientations,
    default: "horizontal",
    doc: "Must match the root's orientation."
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the track — adjust the gap by pairing
    `-ml-2 md:-ml-4` here with `pl-2 md:pl-4` on the items.
    """
  )

  attr(:rest, :global, doc: "Forwarded to the track `<div>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "One or more `<.carousel_item>`s.")

  def carousel_content(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)
    vertical? = assigns.orientation == "vertical"

    assigns =
      assign(assigns,
        viewport_classes:
          cn([
            "overscroll-contain cursor-grab [&:active]:cursor-grabbing",
            "[scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
            if(vertical?,
              do: "overflow-y-auto snap-y snap-mandatory",
              else: "overflow-x-auto snap-x snap-mandatory overflow-y-hidden"
            )
          ]),
        track_classes:
          cn(["flex", if(vertical?, do: "-mt-4 flex-col", else: "-ml-4"), assigns.class])
      )

    ~H"""
    <div class={@viewport_classes} data-polaris-carousel-viewport>
      <div class={@track_classes} data-polaris-carousel-track {@rest}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr(:orientation, :string,
    values: @orientations,
    default: "horizontal",
    doc: "Must match the root's orientation."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the item (e.g. `basis-1/3 md:basis-1/2`)."
  )

  attr(:rest, :global, doc: "Forwarded to the item `<div>`: `data-*`, `aria-*`, …")

  slot(:inner_block, required: true, doc: "Slide content.")

  def carousel_item(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)

    assigns =
      assign(assigns, pad: if(assigns.orientation == "vertical", do: "pt-4", else: "pl-4"))

    ~H"""
    <div
      role="group"
      aria-roledescription="slide"
      data-polaris-carousel-item
      class={
        cn([
          "min-w-0 shrink-0 grow-0 basis-full snap-start",
          @pad,
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:orientation, :string,
    values: @orientations,
    default: "horizontal",
    doc: "Must match the root's orientation (positions and rotates the button)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the button.")

  attr(:rest, :global, doc: "Forwarded to the `<button>`: `aria-label`, `phx-*`, …")

  slot(:icon, doc: "Custom icon content; defaults to the left arrow.")

  def carousel_previous(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)

    assigns =
      assign(
        assigns,
        classes: nav_classes(assigns.orientation == "vertical", "prev", assigns.class)
      )

    ~H"""
    <button
      type="button"
      data-polaris-carousel-nav
      data-polaris-carousel-previous
      class={@classes}
      {@rest}
    >
      <%= if slot_content?(@icon, assigns) do %>
        {render_slot(@icon)}
      <% else %>
        <.arrow direction="prev" />
      <% end %>
      <span class="sr-only">Previous slide</span>
    </button>
    """
  end

  attr(:orientation, :string,
    values: @orientations,
    default: "horizontal",
    doc: "Must match the root's orientation (positions and rotates the button)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the button.")

  attr(:rest, :global, doc: "Forwarded to the `<button>`: `aria-label`, `phx-*`, …")

  slot(:icon, doc: "Custom icon content; defaults to the right arrow.")

  def carousel_next(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)

    assigns =
      assign(
        assigns,
        classes: nav_classes(assigns.orientation == "vertical", "next", assigns.class)
      )

    ~H"""
    <button
      type="button"
      data-polaris-carousel-nav
      data-polaris-carousel-next
      class={@classes}
      {@rest}
    >
      <%= if slot_content?(@icon, assigns) do %>
        {render_slot(@icon)}
      <% else %>
        <.arrow direction="next" />
      <% end %>
      <span class="sr-only">Next slide</span>
    </button>
    """
  end

  defp nav_classes(vertical?, direction, extra) do
    cn([
      "absolute z-10 inline-flex size-8 cursor-pointer items-center justify-center rounded-full",
      "border border-surface-border bg-surface-panel text-content-primary transition-colors",
      "hover:border-surface-border-hover hover:bg-surface-panel-hover",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
      "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
      "disabled:cursor-not-allowed disabled:opacity-50",
      case {vertical?, direction} do
        {false, "prev"} -> "top-1/2 -left-12 -translate-y-1/2"
        {false, "next"} -> "top-1/2 -right-12 -translate-y-1/2"
        {true, "prev"} -> "-top-12 left-1/2 -translate-x-1/2 rotate-90"
        {true, "next"} -> "-bottom-12 left-1/2 -translate-x-1/2 rotate-90"
      end,
      extra
    ])
  end

  defp arrow(%{direction: "prev"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      class="h-4 w-4"
    >
      <path d="m12 19-7-7 7-7" />
      <path d="M19 12H5" />
    </svg>
    """
  end

  defp arrow(%{direction: "next"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      class="h-4 w-4"
    >
      <path d="M5 12h14" />
      <path d="m12 5 7 7-7 7" />
    </svg>
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
