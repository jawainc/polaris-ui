defmodule PolarisUI.Components.Toc do
  @moduledoc """
  The Polaris table of contents: a sticky sidebar listing a page's headings
  as in-page anchor links, with a scrollspy that highlights the section the
  reader is currently viewing and a moving thumb spanning the active items.

  Port of the Supabase design system fragment `ui-patterns/Toc`. The
  fragment composes loose React exports (`Toc`, `TOCScrollArea`,
  `TOCItems`, `TOCItem`, `TocThumb`, plus the `AnchorProvider` context);
  LiveView has no build-time context to wire them, so everything collapses
  into one data-driven component — React extracts headings from MDX at
  build time, here you build the item list yourself and pass it in.

  ## Anatomy

      <.toc
        id="docs-toc"
        show_track
        items={[
          %{title: "REST API", url: "#rest-api", depth: 2},
          %{title: "Using the `supabase-js` client", url: "#client", depth: 3},
          %{title: "Error codes", url: "#error-codes", depth: 4}
        ]}
      >
        <:header>On this page</:header>
        <:footer><a href="#top">Back to top</a></:footer>
      </.toc>

    * **root** — a `<nav aria-label="Table of contents">` landmark (an
      improvement: the fragment's container is a plain `<div>`), sticky at
      `top-24` and hidden below `md`. `top-24` is the assumed
      sticky-header offset (the fragment reads `--header-height`);
      override it via `class`.
    * **inner column** — the fixed `w-56` width (the port of the
      fragment's `--toc-width`), stacked with `gap-3` and `pe-4`.
    * **viewport** (`data-polaris-toc-viewport`) — the scroll container
      the hook scrolls items within.
    * **thumb** (`data-polaris-toc-thumb`) — the moving highlight, sized
      by the hook through the `--toc-top` / `--toc-height` CSS vars.
    * **items** (`data-polaris-toc-item`) — one real `<a href="#...">` per
      heading, indented by depth, with backtick inline-code rendered as
      `<code>`.

  ## Data shapes

  `items` is a list of maps shaped like the fragment's `TOCItemType`:

      %{title: "Using the `supabase-js` client", url: "#client", depth: 3}

    * `title` — heading text; backtick-delimited spans render as inline
      `<code class="font-mono text-content-primary">`, like the
      fragment's `formatTOCHeader`.
    * `url` — either a plain anchor (`"#rest-api"`) or a
      docusaurus-style `heading#anchor`; the href uses the slug after
      the first `#` (the fragment's `formatSlug`, which supports headers
      declared like `## REST API {#rest-api-overview}`).
    * `depth` — the heading level; `<= 2` indents `ps-3`, `3` → `ps-6`,
      `>= 4` → `ps-8`.

  ## The scrollspy hook

  The colocated *runtime* hook `.Toc` replaces the fragment's whole
  client machinery — `AnchorProvider` + `useAnchorObserver`, `TocThumb`,
  and the per-item `scroll-into-view-if-needed`. It derives heading ids
  from the anchors' hrefs (`href` minus the leading `#`), watches the
  matching heading elements with an `IntersectionObserver`
  (`rootMargin: 0px 0px -70% 0px`, so a heading stops being active once
  well past the top of the page), and on every change:

    * marks **every** visible item `data-active="true"` (multi-highlight,
      the docs' default-demo semantics, so the thumb can span a range);
    * recomputes the thumb from the active anchors — top edge of the
      first (`offsetTop` + padding-top) to bottom edge of the last
      (`offsetTop` + `clientHeight` - padding-bottom), the port of
      `calc/2` from `toc-thumb.tsx` — and writes `--toc-top` /
      `--toc-height` in pixels on the thumb, which the inline style
      consumes;
    * when the *last* active item changes, centers it inside the
      viewport with `container.scrollTo` — never bare
      `element.scrollIntoView`, which would scroll the page.

  A `ResizeObserver` on the items container recalculates the thumb (the
  port of `toc-thumb.tsx`). `updated/0` re-runs the observers only when
  the item set changed (a fingerprint of anchor hrefs stored on the
  hook); otherwise it just re-binds the anchor nodes and re-applies the
  current state after the patch. `destroyed/0` disconnects both
  observers.

  ## States

    * **idle** — no heading visible: items stay `text-content-muted` and
      the thumb collapses to zero height.
    * **active** — items with `data-active="true"` turn
      `text-content-primary` while the thumb spans them. `data-active`
      is client-owned: it is never server-rendered.
    * hover — `hover:text-brand-emerald` with `transition-colors`.

  ## Accessibility

    * The root is a `<nav aria-label="Table of contents">` landmark.
    * Items are real in-page links (`<a href="#id">`) — keyboard
      focusable, standard anchor navigation, no JS click handling.
    * The thumb is purely decorative (`aria-hidden="true"`).

  ## Deviations from the fragment

    * The `ScrollArea` primitive becomes a plain `overflow-y-auto`
      container — no custom scrollbar styling and no `ScrollProvider`
      context (the hook scrolls the viewport directly).
    * The `single` highlight mode is omitted: highlight is always
      multi, like the docs' default demo.
    * `onActiveChange` has no LiveView equivalent here and is omitted.
    * Titles with docusaurus `{#anchor}` suffixes are not stripped (the
      fragment's `removeAnchor`) — pass clean titles; the url side of
      that convention is handled by the slug formatting.
    * `top-24` stands in for `top-(--header-height)` and `w-56` for
      `w-(--toc-width)`; override both via `class`.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the root — required because the colocated scrollspy
    hook anchors on it.
    """
  )

  attr(:items, :list,
    required: true,
    doc: """
    TOC entries shaped like the fragment's `TOCItemType`, all keys
    required: `%{title: "REST API", url: "#rest-api", depth: 2}`. An
    empty list renders only the nav shell — with the `header`/`footer`
    slots — but no viewport, items, or thumb.
    """
  )

  attr(:show_track, :boolean,
    default: false,
    doc: """
    Draws the `border-s` track on the items container (the fragment's
    `showTrack`). The `pl-[calc(0.75rem+5px)]` inset the thumb sits in is
    applied either way.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the root — later utilities win via
    `cn/1` (e.g. `class="top-8"` re-pins the sticky offset).
    """
  )

  attr(:rest, :global, doc: "Forwarded to the root `<nav>`: `data-*`, `phx-*`, …")

  slot(:header, doc: "Custom content before the scroll area (the fragment's `header` prop).")

  slot(:footer, doc: "Custom content after the scroll area (the fragment's `footer` prop).")

  def toc(assigns) do
    assigns =
      assign(
        assigns,
        hook: "#{inspect(__MODULE__)}.Toc",
        items_classes:
          cn([
            "list-none flex flex-col pl-[calc(0.75rem+5px)] border-surface-border",
            if(assigns.show_track, do: "border-s")
          ])
      )

    ~H"""
    <nav
      id={@id}
      data-polaris-toc
      class={cn(["sticky top-24 h-fit max-md:hidden", @class])}
      aria-label="Table of contents"
      phx-hook={@hook}
      {@rest}
    >
      <div class="flex w-56 max-w-full flex-col gap-3 pe-4">
        {render_slot(@header)}
        <div
          :if={@items != []}
          data-polaris-toc-viewport
          class="relative min-h-0 overflow-y-auto text-sm"
        >
          <div
            data-polaris-toc-thumb
            class="absolute start-0 w-px bg-content-primary transition-all"
            style="top: var(--toc-top, 0px); height: var(--toc-height, 0px)"
            aria-hidden="true"
          >
          </div>
          <div data-polaris-toc-items class={@items_classes}>
            <a
              :for={item <- @items}
              href={item_href(item)}
              data-polaris-toc-item
              class={item_class(item)}
            >
              <%= for segment <- format_toc_header(item[:title]) do %>
                <%= if segment.type == :code do %>
                  <code class="font-mono text-content-primary">{segment.value}</code>
                <% else %>
                  {segment.value}
                <% end %>
              <% end %>
            </a>
          </div>
        </div>
        {render_slot(@footer)}
      </div>
    </nav>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Toc" runtime>
      {
        mounted() {
          this._setup()
        },
        updated() {
          if (this._fingerprint() === this._fingerprintValue) {
            // Same item set: a patch only replaced the anchor nodes —
            // re-bind them and re-apply the current state (data-active
            // is client-owned).
            this._bind()
            this._refresh()
          } else {
            this._teardown()
            this._setup()
          }
        },
        destroyed() {
          this._teardown()
        },
        // Replaces the fragment's AnchorProvider + useAnchorObserver +
        // TocThumb: observe the headings the anchors point at, keep every
        // visible anchor active, and size the thumb to span them.
        _setup() {
          this._bind()
          this._fingerprintValue = this._fingerprint()
          this._visible = new Set()
          this._activeIds = []
          this._lastActiveId = null
          if (this._anchors.length === 0) {
            return
          }
          // Heading ids derive from the anchors' hrefs (AnchorProvider
          // did the same with url.split("#")[1]).
          const headings = this._anchors
            .map((anchor) => (anchor.getAttribute("href") || "").replace(/^#/, ""))
            .map((id) => document.getElementById(id))
            .filter((heading) => heading !== null)
          // A heading stays active while it sits within the top 30% of
          // the page; once well past, it stops intersecting.
          this._observer = new IntersectionObserver(
            (entries) => {
              for (const entry of entries) {
                if (entry.isIntersecting) {
                  this._visible.add(entry.target.id)
                } else {
                  this._visible.delete(entry.target.id)
                }
              }
              this._refresh()
            },
            { rootMargin: "0px 0px -70% 0px", threshold: 0 }
          )
          for (const heading of headings) {
            this._observer.observe(heading)
          }
          this._resizeObserver = new ResizeObserver(() => this._updateThumb(this._activeIds))
          this._resizeObserver.observe(this._itemsContainer)
          this._refresh()
        },
        _bind() {
          const root = this.el
          this._itemsContainer = root.querySelector("[data-polaris-toc-items]")
          this._anchors = this._itemsContainer
            ? Array.from(this._itemsContainer.querySelectorAll("[data-polaris-toc-item]"))
            : []
          this._viewport = root.querySelector("[data-polaris-toc-viewport]")
          this._thumb = root.querySelector("[data-polaris-toc-thumb]")
        },
        _teardown() {
          if (this._observer) {
            this._observer.disconnect()
            this._observer = null
          }
          if (this._resizeObserver) {
            this._resizeObserver.disconnect()
            this._resizeObserver = null
          }
        },
        _fingerprint() {
          const container = this.el.querySelector("[data-polaris-toc-items]")
          if (!container) {
            return ""
          }
          return Array.from(container.querySelectorAll("[data-polaris-toc-item]"))
            .map((anchor) => anchor.getAttribute("href") || "")
            .join("|")
        },
        _refresh() {
          const activeAnchors = []
          this._activeIds = []
          for (const anchor of this._anchors) {
            const id = (anchor.getAttribute("href") || "").replace(/^#/, "")
            if (this._visible.has(id)) {
              this._activeIds.push(id)
              activeAnchors.push(anchor)
              anchor.setAttribute("data-active", "true")
            } else {
              anchor.removeAttribute("data-active")
            }
          }
          this._updateThumb(this._activeIds)
          // Center the last active item inside the viewport container
          // only — scrolling the page itself must never happen.
          const lastId = this._activeIds[this._activeIds.length - 1]
          if (lastId !== undefined && lastId !== this._lastActiveId) {
            this._lastActiveId = lastId
            const item = activeAnchors[activeAnchors.length - 1]
            if (item && this._viewport) {
              this._viewport.scrollTo({
                top: item.offsetTop - this._viewport.clientHeight / 2 + item.clientHeight / 2,
                behavior: "smooth"
              })
            }
          }
        },
        // Port of calc/2 from toc-thumb.tsx: the thumb spans from the top
        // edge of the first active anchor to the bottom edge of the last.
        _updateThumb(activeIds) {
          if (!this._itemsContainer || !this._thumb) {
            return
          }
          const collapsed = activeIds.length === 0 || this._itemsContainer.clientHeight === 0
          let upper = Number.MAX_VALUE
          let lower = 0
          if (!collapsed) {
            for (const id of activeIds) {
              const element = this._itemsContainer.querySelector('a[href="#' + id + '"]')
              if (!element) {
                continue
              }
              const styles = getComputedStyle(element)
              upper = Math.min(upper, element.offsetTop + parseFloat(styles.paddingTop))
              lower = Math.max(
                lower,
                element.offsetTop + element.clientHeight - parseFloat(styles.paddingBottom)
              )
            }
          }
          const top = collapsed ? 0 : upper
          const height = collapsed ? 0 : lower - upper
          this._thumb.style.setProperty("--toc-top", top + "px")
          this._thumb.style.setProperty("--toc-height", height + "px")
        }
      }
    </script>
    """
  end

  # The fragment's formatSlug: urls may arrive as docusaurus-style
  # "heading#anchor" — the href uses the slug after the FIRST "#"
  # (slug.split("#")[1]).
  defp item_href(item), do: "##{format_slug(item[:url] || "")}"

  defp format_slug(slug) do
    if String.contains?(slug, "#") do
      slug |> String.split("#") |> Enum.at(1)
    else
      slug
    end
  end

  defp item_class(item) do
    cn([
      "text-content-muted hover:text-brand-emerald transition-colors py-1 break-words",
      "first:pt-0 last:pb-0 data-[active=true]:text-content-primary",
      depth_indent(item[:depth])
    ])
  end

  # Depth indents, ported exactly from TOCItem.
  defp depth_indent(depth) when depth <= 2, do: "ps-3"
  defp depth_indent(3), do: "ps-6"
  defp depth_indent(_depth), do: "ps-8"

  # The fragment's formatTOCHeader: split a heading into text and
  # backtick-delimited inline-code segments, merging consecutive
  # characters into runs.
  defp format_toc_header(content) when is_binary(content) do
    {_inside_code, segments} =
      content
      |> String.graphemes()
      |> Enum.reduce({false, []}, fn
        "`", {false, segments} ->
          {true, [%{type: :code, value: ""} | segments]}

        "`", {true, segments} ->
          {false, segments}

        char, {true, segments} ->
          [last | rest] = segments
          {true, [%{last | value: last.value <> char} | rest]}

        char, {false, segments} ->
          case segments do
            [%{type: :text, value: value} | rest] ->
              {false, [%{type: :text, value: value <> char} | rest]}

            _other ->
              {false, [%{type: :text, value: char} | segments]}
          end
      end)

    Enum.reverse(segments)
  end

  defp format_toc_header(nil), do: []
end
