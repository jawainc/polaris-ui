defmodule PolarisUI.Components.CarouselTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Carousel` — the port of
  the shadcn/ui Carousel documented by the Supabase design system: the
  region/root + snapped viewport + flex track (`-ml-4`/`pl-4` spacing
  model), full-basis slides, the circular prev/next buttons outside the
  viewport edges, and the colocated runtime scroll-snap engine.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Carousel

  @hook "PolarisUI.Components.Carousel.Root"

  defp render_carousel(assigns) do
    assigns =
      Map.merge(
        %{
          id: "features",
          orientation: "horizontal",
          on_change: nil,
          class: nil,
          content_class: nil,
          item_class: nil,
          item2_class: nil,
          prev_class: nil,
          next_class: nil,
          rest: %{},
          custom_icon: false
        },
        assigns
      )

    rendered_to_string(~H"""
    <.carousel
      id={@id}
      orientation={@orientation}
      on_change={@on_change}
      class={@class}
      {assigns[:rest]}
    >
      <.carousel_content orientation={@orientation} class={@content_class}>
        <.carousel_item orientation={@orientation} class={@item_class}>First</.carousel_item>
        <.carousel_item orientation={@orientation} class={@item2_class}>Second</.carousel_item>
      </.carousel_content>
      <.carousel_previous orientation={@orientation} class={@prev_class} />
      <.carousel_next orientation={@orientation} class={@next_class}>
        <:icon :if={@custom_icon}><span data-icon>→</span></:icon>
      </.carousel_next>
    </.carousel>
    """)
  end

  describe "anatomy" do
    test "renders the carousel region anchored by the hook" do
      html = render_carousel(%{})

      assert html =~ ~s{id="features"}
      assert html =~ ~s{data-polaris-carousel }
      assert html =~ ~s{data-orientation="horizontal"}
      assert html =~ ~s{role="region"}
      assert html =~ ~s{aria-roledescription="carousel"}
      assert html =~ ~s{phx-hook="#{@hook}"}
      assert class_before(html, ~s{data-polaris-carousel }) =~ "relative"
    end

    test "renders the snapped viewport wrapping the flex track" do
      html = render_carousel(%{})

      viewport = class_before(html, "data-polaris-carousel-viewport")
      assert viewport =~ "overflow-x-auto snap-x snap-mandatory"
      assert viewport =~ "overscroll-contain"
      assert viewport =~ "cursor-grab [&:active]:cursor-grabbing"
      assert viewport =~ "[scrollbar-width:none] [&::-webkit-scrollbar]:hidden"

      track = class_before(html, "data-polaris-carousel-track")
      assert track =~ "flex -ml-4"
    end

    test "renders slides with the source basis and snap alignment" do
      html = render_carousel(%{})

      assert count(html, "data-polaris-carousel-item") >= 2
      item = class_of(html, "data-polaris-carousel-item")
      assert item =~ "min-w-0 shrink-0 grow-0 basis-full"
      assert item =~ "snap-start pl-4"
      assert html =~ ~s{role="group" aria-roledescription="slide"}
      assert html =~ "First"
      assert html =~ "Second"
    end

    test "renders the circular nav buttons outside the viewport edges" do
      html = render_carousel(%{})

      prev = class_of(html, "data-polaris-carousel-previous")
      assert prev =~ "absolute z-10 inline-flex size-8"
      assert prev =~ "rounded-full"
      assert prev =~ "top-1/2 -left-12 -translate-y-1/2"

      next = class_of(html, "data-polaris-carousel-next")
      assert next =~ "top-1/2 -right-12 -translate-y-1/2"

      assert html =~ ~s{<span class="sr-only">Previous slide</span>}
      assert html =~ ~s{<span class="sr-only">Next slide</span>}
    end

    test "the nav buttons carry the arrow icons" do
      html = render_carousel(%{})

      assert html =~ ~s{<path d="m12 19-7-7 7-7">}
      assert html =~ ~s{<path d="M19 12H5">}
      assert html =~ ~s{<path d="M5 12h14">}
      assert html =~ ~s{<path d="m12 5 7 7-7 7">}
    end

    test "custom icon content replaces the default arrow" do
      html = render_carousel(%{custom_icon: true})

      assert html =~ "→"
      # the default right arrow is gone; the previous button keeps its left arrow
      assert count(html, ~s{<path d="M5 12h14">}) == 0
      assert count(html, ~s{<path d="M19 12H5">}) == 1
    end
  end

  describe "orientation" do
    test "vertical flips the viewport, track, items, and button positions" do
      html = render_carousel(%{orientation: "vertical"})

      assert html =~ ~s{data-orientation="vertical"}
      assert class_before(html, "data-polaris-carousel-viewport") =~ "overflow-y-auto snap-y"
      assert class_before(html, "data-polaris-carousel-track") =~ "-mt-4 flex-col"
      refute class_before(html, "data-polaris-carousel-track") =~ "-ml-4"
      assert class_of(html, "data-polaris-carousel-item") =~ "pt-4"

      prev = class_of(html, "data-polaris-carousel-previous")
      assert prev =~ "-top-12 left-1/2 -translate-x-1/2 rotate-90"

      next = class_of(html, "data-polaris-carousel-next")
      assert next =~ "-bottom-12 left-1/2 -translate-x-1/2 rotate-90"
    end

    test "rejects an unknown orientation" do
      assert_raise ArgumentError, ~r/:orientation/, fn ->
        render_carousel(%{orientation: "diagonal"})
      end
    end
  end

  describe "states" do
    test "the nav buttons carry the outline treatment" do
      html = render_carousel(%{})

      class = class_of(html, "data-polaris-carousel-previous")
      assert class =~ "border border-surface-border bg-surface-panel text-content-primary"
      assert class =~ "hover:border-surface-border-hover hover:bg-surface-panel-hover"
    end

    test "the nav buttons carry the focus-ring treatment" do
      html = render_carousel(%{})

      class = class_of(html, "data-polaris-carousel-previous")
      assert class =~ "focus-visible:outline-none"
      assert class =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    end

    test "disabled nav buttons dim and lock" do
      html = render_carousel(%{})

      class = class_of(html, "data-polaris-carousel-previous")
      assert class =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_carousel(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "computes snap points from the items' offsets" do
      html = render_carousel(%{})

      assert html =~ "_snaps()"
      assert html =~ "item.offsetTop : item.offsetLeft"
      assert html =~ "_current()"
    end

    test "scrolls prev/next one snap with smooth motion" do
      html = render_carousel(%{})

      assert html =~ "scrollPrev()"
      assert html =~ "scrollNext()"
      assert html =~ "this._scrollToIndex(this._current() - 1)"
      assert html =~ ~s{behavior: smooth === false ? "auto" : "smooth"}
    end

    test "buttons disable at the track bounds" do
      html = render_carousel(%{})

      assert html =~ "this._prev.disabled = pos <= 1"
      assert html =~ "this._next.disabled = pos >= max - 1"
    end

    test "pushes the on_change event when a snap settles" do
      html = render_carousel(%{on_change: "slide-changed"})

      assert html =~ ~s{data-change-event="slide-changed"}

      assert html =~
               ~s[pushEvent(name, { selected: this._current(), count: this._snaps().length })]
    end

    test "no data-change-event attribute without on_change" do
      html = render_carousel(%{})

      refute html =~ "data-change-event"
    end

    test "arrows navigate from anywhere inside the region" do
      html = render_carousel(%{})

      assert html =~ ~s{"ArrowLeft"}
      assert html =~ ~s{"ArrowRight"}
      assert html =~ "event.preventDefault()"
    end

    test "vertical carousels navigate with the vertical arrows" do
      html = render_carousel(%{orientation: "vertical"})

      assert html =~ ~s{"ArrowUp" : "ArrowLeft"}
      assert html =~ ~s{"ArrowDown" : "ArrowRight"}
    end

    test "pointer drag scrolls directly and suppresses the trailing click" do
      html = render_carousel(%{})

      assert html =~ "_dragStart(event)"
      assert html =~ "this._viewport.scrollTo({ [axis]: this._dragStartScroll - delta"
      assert html =~ "this._dragging = false"
      assert html =~ "event.stopPropagation()"
    end

    test "re-syncs after LiveView patches" do
      html = render_carousel(%{})

      assert html =~ "updated()"
      assert html =~ "LiveView patches may swap the viewport/track"
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_carousel(%{rest: %{"aria-label" => "Featured projects"}})

      assert html =~ ~s{aria-label="Featured projects"}
    end

    test "classes merge onto the root, track, items, and buttons" do
      html =
        render_carousel(%{
          class: "w-full max-w-xs",
          content_class: "gap-4",
          item_class: "basis-1/3",
          item2_class: "md:basis-1/2",
          prev_class: "border-danger"
        })

      assert class_before(html, ~s{data-polaris-carousel }) =~ "w-full max-w-xs"
      assert class_before(html, "data-polaris-carousel-track") =~ "gap-4"
      assert class_of(html, "data-polaris-carousel-previous") =~ "border-danger"
    end

    test "a caller item basis wins conflicts via cn/1" do
      html = render_carousel(%{item_class: "basis-1/3"})

      item = class_of(html, "data-polaris-carousel-item")
      assert item =~ "basis-1/3"
      refute item =~ "basis-full"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_carousel(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  # The root, viewport, and track render their class *before* the
  # data-polaris marker; items and buttons render it after.
  defp class_of(html, marker) do
    [_, rest | _] = String.split(html, marker, parts: 2)

    rest
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp class_before(html, marker) do
    [before_marker | _] = String.split(html, marker, parts: 2)

    before_marker
    |> String.split(~s{class="})
    |> List.last()
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
