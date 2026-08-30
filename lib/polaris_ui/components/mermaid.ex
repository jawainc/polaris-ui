defmodule PolarisUI.Components.Mermaid do
  @moduledoc """
  The Polaris mermaid: renders diagrams from Mermaid-syntax text — the
  port of the Supabase design system Mermaid (`packages/ui-patterns`,
  `Mermaid.tsx`, built on the `mermaid` npm library).

  Supports flowcharts, sequence diagrams, ER diagrams, and every other
  Mermaid syntax; the chart source is passed as the `chart` attribute
  and rendered client-side into an SVG.

  ## How it renders

  A colocated runtime hook drives the whole pipeline (the source's
  `useEffect`): load Mermaid 11 from the jsDelivr CDN (once per page),
  initialize with `theme: "base"` and the source's diagram config
  (`sequence.actorMargin: 150`, `useMaxWidth: false` everywhere), render
  with a unique id per render, sanitize Mermaid's non-XML `<br>` tags,
  and inject the SVG into the figure. Re-renders when `chart` changes
  or when the theme flips (the hook re-runs on every patch and
  hashes the source).

  The canvas lives in a `phx-update="ignore"` subtree so LiveView
  patches never fight the injected SVG; the chart source rides a
  hidden div *outside* it, so server-side chart changes still reach the
  hook.

  ## Theming

  Mermaid's parser cannot read CSS variables (the reason the source
  hardcodes two palettes), so the hook reads the Polaris design tokens
  from computed style at render time — `--color-surface-panel`,
  `--color-brand-emerald`, `--color-content-primary`, `--font-mono`, …
  — and falls back to the source's dark hexes. Diagrams therefore
  follow the app's palette automatically, including the
  `polaris-light` flip (with the source's dark `14px` / light `13px`
  font-size switch). The purple accents (`#9333ea` / `#a855f7`) stay
  literal — the palette has no purple token.

  ## States

    * **loading** — the source's pulse placeholder (`h-64` panel block)
      renders server-side and again while Mermaid loads.
    * **error** — invalid syntax swaps in the danger box: "Mermaid
      Error: <message>" plus the raw chart source, scrollable.
    * **done** — the centered figure: bordered, padded, SVG scaled to
      the container (`[&_svg]:h-auto [&_svg]:max-w-full`).

  ## Anatomy

      <.mermaid id="auth-flow" chart={~s\"\"\"
        flowchart LR
          A[User Request] --> B{Authenticated?}
          B -->|Yes| C[Process Request]
          B -->|No| D[Return 401]
      \"\"\"} />

  Requires network access to cdn.jsdelivr.net at runtime; apps that
  need self-hosting can override `mermaid_src` with their own build of
  Mermaid 11.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @default_mermaid_src "https://cdn.jsdelivr.net/npm/mermaid@11.12.1/dist/mermaid.min.js"

  @doc """
  Renders the Mermaid diagram from text.
  """
  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the diagram root — required because the colocated
    hook that loads Mermaid and injects the SVG anchors on it.
    """
  )

  attr(:chart, :string,
    required: true,
    doc: """
    The Mermaid diagram definition (e.g. `flowchart LR …`,
    `sequenceDiagram …`, `erDiagram …`). Rendered client-side; invalid
    syntax shows the error box with the source.
    """
  )

  attr(:mermaid_src, :string,
    default: @default_mermaid_src,
    doc: "URL of the Mermaid 11 UMD build to load — override to self-host."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the diagram root.")

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  def mermaid(assigns) do
    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        mermaid_src: assigns.mermaid_src || @default_mermaid_src
      )

    ~H"""
    <div
      id={@id}
      data-polaris-mermaid
      data-mermaid-src={@mermaid_src}
      class={cn(["w-full", @class])}
      phx-hook={@hook}
      {@rest}
    >
      <div data-polaris-mermaid-source hidden class="hidden">{@chart}</div>
      <div id={"#{@id}-canvas"} phx-update="ignore" data-polaris-mermaid-canvas>
        <div class="my-6 h-64 animate-pulse rounded-lg bg-surface-panel p-6"></div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          this._hash = null
          this._render()
        },
        updated() {
          this._render()
        },
        destroyed() {
          this._hash = null
        },
        _render() {
          const root = this.el
          const canvas = root.querySelector("[data-polaris-mermaid-canvas]")
          const source = root.querySelector("[data-polaris-mermaid-source]")
          if (!canvas || !source) return
          const chart = source.textContent
          const light = !!root.closest(".polaris-light")
          const key = (light ? "light\u0000" : "dark\u0000") + chart
          if (key === this._hash) return
          this._hash = key
          canvas.innerHTML = ""
          const pulse = document.createElement("div")
          pulse.className = "my-6 h-64 animate-pulse rounded-lg bg-surface-panel p-6"
          canvas.appendChild(pulse)
          this._mermaid(root)
            .then((mermaid) => {
              mermaid.initialize({
                startOnLoad: false,
                theme: "base",
                themeVariables: this._vars(root, light),
                sequence: { useMaxWidth: false, actorMargin: 150, messageMargin: 60, noteMargin: 20 },
                flowchart: { useMaxWidth: false },
                er: { useMaxWidth: false },
              })
              // Mermaid requires a unique ID per render to avoid DOM conflicts.
              const id = "mermaid-" + Math.random().toString(36).substring(2, 11)
              return mermaid.render(id, chart.trim())
            })
            .then((result) => {
              if (this._hash !== key) return
              canvas.innerHTML = ""
              const figure = document.createElement("figure")
              figure.className =
                "my-6 flex w-full justify-center rounded-lg border border-surface-border bg-surface-base p-6 [&_svg]:h-auto [&_svg]:max-w-full"
              // Mermaid outputs <br> which isn't valid XML — fix for
              // browser compatibility (the source's replace).
              figure.innerHTML = result.svg.replace(/<br\s*>/gi, "<br/>")
              canvas.appendChild(figure)
            })
            .catch((err) => {
              if (this._hash !== key) return
              const message = err && err.message ? err.message : "Failed to render diagram"
              canvas.innerHTML = ""
              const box = document.createElement("div")
              box.className = "my-4 rounded-md border border-danger-border bg-danger-muted p-4"
              const p = document.createElement("p")
              p.className = "font-mono text-sm text-danger"
              p.textContent = "Mermaid Error: " + message
              const pre = document.createElement("pre")
              pre.className = "mt-2 overflow-auto text-xs text-content-secondary"
              pre.textContent = chart
              box.appendChild(p)
              box.appendChild(pre)
              canvas.appendChild(box)
            })
        },
        // Loads the Mermaid 11 UMD build once per page, from the root's
        // data-mermaid-src (CDN by default).
        _mermaid(root) {
          if (window.mermaid) return Promise.resolve(window.mermaid)
          if (window.__polarisMermaidLoader) return window.__polarisMermaidLoader
          window.__polarisMermaidLoader = new Promise((resolve, reject) => {
            const script = document.createElement("script")
            script.src = root.dataset.mermaidSrc
            script.onload = () => resolve(window.mermaid)
            script.onerror = () => {
              window.__polarisMermaidLoader = null
              reject(new Error("Failed to load Mermaid from " + root.dataset.mermaidSrc))
            }
            document.head.appendChild(script)
          })
          return window.__polarisMermaidLoader
        },
        // The source's themeVariables, but read from the Polaris design
        // tokens at render time (Mermaid's parser cannot read CSS
        // variables, and this way diagrams follow palette overrides and
        // the polaris-light flip). Fallbacks are the source's dark hexes;
        // the purple accents stay literal — the palette has no purple.
        _vars(root, light) {
          const style = getComputedStyle(root)
          const v = (name, fallback) => {
            const value = style.getPropertyValue(name).trim()
            return value || fallback
          }
          return {
            background: "transparent",
            mainBkg: v("--color-surface-panel", "#1c1c1c"),
            primaryTextColor: v("--color-content-primary", "#ededed"),
            secondaryTextColor: v("--color-content-secondary", "#a0a0a0"),
            tertiaryTextColor: v("--color-content-primary", "#ededed"),
            textColor: v("--color-content-primary", "#ededed"),
            primaryColor: v("--color-brand-emerald", "#3ecf8e"),
            primaryBorderColor: v("--color-brand-emerald", "#3ecf8e"),
            secondaryColor: "#9333ea",
            secondaryBorderColor: "#a855f7",
            tertiaryColor: v("--color-surface-panel", "#1c1c1c"),
            tertiaryBorderColor: v("--color-surface-border-hover", "#404040"),
            lineColor: v("--color-surface-border-hover", "#404040"),
            border1: v("--color-surface-border-hover", "#404040"),
            border2: v("--color-surface-border-hover", "#404040"),
            noteBkgColor: v("--color-brand-emerald-muted", "#1a3a2a"),
            noteTextColor: v("--color-content-primary", "#ededed"),
            noteBorderColor: v("--color-brand-emerald", "#3ecf8e"),
            actorBkg: v("--color-surface-panel", "#1c1c1c"),
            actorBorder: v("--color-surface-border-hover", "#404040"),
            actorTextColor: v("--color-content-primary", "#ededed"),
            actorLineColor: v("--color-surface-border-hover", "#404040"),
            activationBkgColor: "#9333ea",
            activationBorderColor: "#a855f7",
            signalColor: v("--color-content-primary", "#ededed"),
            signalTextColor: v("--color-content-primary", "#ededed"),
            sequenceNumberColor: v("--color-surface-base", "#121212"),
            nodeBkg: v("--color-surface-panel", "#1c1c1c"),
            nodeBorder: v("--color-surface-border-hover", "#404040"),
            clusterBkg: v("--color-surface-base", "#121212"),
            clusterBorder: v("--color-surface-border-hover", "#404040"),
            defaultLinkColor: v("--color-brand-emerald", "#3ecf8e"),
            edgeLabelBackground: v("--color-surface-panel", "#1c1c1c"),
            attributeBackgroundColorOdd: v("--color-surface-panel", "#1c1c1c"),
            attributeBackgroundColorEven: v("--color-surface-panel", "#1c1c1c"),
            rowOdd: v("--color-surface-panel", "#1c1c1c"),
            rowEven: v("--color-surface-base", "#121212"),
            fontFamily: v("--font-mono", "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"),
            fontSize: light ? "13px" : "14px",
          }
        }
      }
    </script>
    """
  end
end
