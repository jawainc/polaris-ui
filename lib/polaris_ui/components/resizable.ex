defmodule PolarisUI.Components.Resizable do
  @moduledoc """
  The Polaris resizable: draggable, keyboard-resizable panel groups —
  the port of the Supabase design system Resizable (`packages/ui`,
  built on `react-resizable-panels` v4).

  ## Anatomy

      <.resizable_group id="layout" class="max-w-md rounded-lg border">
        <.resizable_panel default_size="25">
          <div class="flex h-[200px] items-center justify-center p-6">Sidebar</div>
        </.resizable_panel>
        <.resizable_handle />
        <.resizable_panel default_size="75">Content</.resizable_panel>
      </.resizable_group>

      <.resizable_group id="editor" orientation="vertical">
        <.resizable_panel default_size="25">Header</.resizable_panel>
        <.resizable_handle with_handle />
        <.resizable_panel default_size="75" min_size="30" max_size="90" collapsible>
          Body
        </.resizable_panel>
      </.resizable_group>

    * **group** — `flex h-full w-full` (`flex-col` when vertical) with
      `data-orientation` driving the handles' orientation styling; the
      panels and handles must be its direct children.
    * **panel** — the flexible pane: `flex` with `basis-0` so the
      hook-owned `flex-grow` percentage sizes it, wrapping content in a
      `min-w-0 min-h-0 overflow-auto` inner container like the source
      library's.
    * **handle** — the 1px separator line (`bg-surface-border`,
      `data-[separator=active]:bg-surface-border-hover`) with an
      invisible 4px `::after` hit strip widening the pointer target,
      and — with `with_handle` — the hover-revealed grip knob (rotated
      90° in vertical groups, like the source's).

  ## State model

  The layout — a percentage per panel — is **client-side**: the
  colocated runtime hook owns it, seeding from the panels'
  `default_size` (panels without one split the remainder evenly), and
  re-applies `flex-grow` after LiveView patches so drags survive
  re-renders. Sizes are percentages: `"25"`, `"25%"`, and `25` all mean
  25%.

  Panels without an explicit `id` get `"<group id>-panel-<index>"`
  from the hook. Give the group an `auto_save_id` to persist layouts
  across visits (localStorage under the source's
  `react-resizable-panels-v4:` key scheme, best-effort — storage
  failures are swallowed, like the source's `autoSaveId`).

  ## Keyboard

  The handle is a focusable `role="separator"` with
  `aria-orientation` (the inverse of the group), `aria-controls` on the
  primary panel, and `aria-valuenow/min/max` the hook keeps in sync:

    * **ArrowRight**/**ArrowDown** — grow the primary panel by 5
      percentage points (the direction that grows it in the group's
      orientation).
    * **ArrowLeft**/**ArrowUp** — shrink it by 5.
    * **Home** / **End** — the primary panel's smallest / largest
      allowed size (possibly collapsing a neighbor).
    * **Enter** — toggle the primary panel between collapsed and its
      pre-collapse size (`collapsible` panels only).
    * **F6** / **Shift+F6** — cycle focus between the group's handles.

  Pointer drags resize continuously (the `ew-resize`/`ns-resize`
  cursor is applied document-wide while dragging, like the source);
  double-clicking a handle resets the first neighbor with a
  `default_size` back to it. Dragging a `collapsible` panel below its
  `min_size` snaps it to `collapsed_size`; dragging back out restores
  it.

  No form participation or microcopy — layout chrome only.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @hook "#{inspect(__MODULE__)}.Root"

  @orientations ~w(horizontal vertical)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the group root — required because the colocated hook
    that owns the layout anchors on it. Panels without an explicit
    `id` derive theirs from it (`"<id>-panel-<index>"`).
    """
  )

  attr(:orientation, :string,
    values: @orientations,
    default: "horizontal",
    doc: "Which axis the panels stack — handles run the other way."
  )

  attr(:auto_save_id, :string,
    default: nil,
    doc: """
    Persist the layout to localStorage under this key and restore it on
    mount — the source's `autoSaveId` (best-effort; storage failures
    are ignored).
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")

  attr(:rest, :global, doc: "Forwarded to the group: `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "Alternating `resizable_panel`s and `resizable_handle`s."
  )

  def resizable_group(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)

    assigns =
      assign(assigns,
        hook: @hook,
        group_classes:
          cn([
            "group/resizable flex h-full w-full overflow-hidden",
            assigns.orientation == "vertical" && "flex-col",
            assigns.class
          ])
      )

    ~H"""
    <div
      id={@id}
      data-polaris-resizable-group
      data-orientation={@orientation}
      data-auto-save-id={@auto_save_id}
      class={@group_classes}
      phx-hook={@hook}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const group = this.el.querySelector("[data-polaris-resizable-group]")
          this._panels = () =>
            Array.from(group.querySelectorAll(":scope > [data-polaris-resizable-panel]"))
          this._handles = () =>
            Array.from(group.querySelectorAll(":scope > [data-polaris-resizable-handle]"))

          const isVertical = () => (group.dataset.orientation || "horizontal") === "vertical"

          // Panels without an explicit id get a stable derived one —
          // required for layout keys and aria-controls.
          this._panels().forEach((panel, index) => {
            if (!panel.id) panel.id = group.id + "-panel-" + index
          })

          // Size parsing: "25", "25%", and 25 are all percentages of the
          // group (the source's unitless string form).
          const parsePercent = (raw, fallback) => {
            if (raw == null || raw === "") return fallback
            const n = parseFloat(String(raw).replace(/%$/, ""))
            return isNaN(n) ? fallback : n
          }

          const panelConfig = (panel) => ({
            defaultSize: parsePercent(panel.dataset.defaultSize, null),
            minSize: parsePercent(panel.dataset.minSize, 0),
            maxSize: parsePercent(panel.dataset.maxSize, 100),
            collapsible: panel.dataset.collapsible === "true",
            collapsedSize: parsePercent(panel.dataset.collapsedSize, 0)
          })

          // Seed the layout: defaults first, the remainder split evenly
          // among unspecified panels.
          this._seedLayout = () => {
            const panels = this._panels()
            const layout = {}
            let claimed = 0
            let unspecified = 0
            panels.forEach((panel) => {
              const { defaultSize } = panelConfig(panel)
              if (defaultSize != null) {
                layout[panel.id] = defaultSize
                claimed += defaultSize
              } else {
                unspecified += 1
              }
            })
            const share = unspecified > 0 ? Math.max(100 - claimed, 0) / unspecified : 0
            panels.forEach((panel) => {
              if (layout[panel.id] == null) layout[panel.id] = share
            })
            return layout
          }

          // The source persists under react-resizable-panels-v4:<ids>;
          // storage failures are swallowed (SSR, private mode, …).
          this._storageKey = () => {
            const key = group.dataset.autoSaveId
            if (!key) return null
            return "react-resizable-panels-v4:" + [key].concat(this._panels().map((p) => p.id)).join(":")
          }

          this._loadSaved = () => {
            const key = this._storageKey()
            if (!key) return null
            try {
              const raw = localStorage.getItem(key)
              return raw ? JSON.parse(raw) : null
            } catch {
              return null
            }
          }

          this._save = () => {
            const key = this._storageKey()
            if (!key) return
            try {
              localStorage.setItem(key, JSON.stringify(this._layout))
            } catch {
              // Layout persistence is non-critical.
            }
          }

          this._apply = () => {
            this._panels().forEach((panel) => {
              panel.style.flexGrow = String(this._layout[panel.id] ?? 1)
            })
            // Handles carry the primary (preceding) panel's value and the
            // inverse orientation, like the source library.
            this._handles().forEach((handle) => {
              handle.setAttribute("aria-orientation", isVertical() ? "horizontal" : "vertical")
              const primary = this._primaryOf(handle)
              if (!primary) return
              const { minSize, maxSize } = panelConfig(primary)
              const size = this._layout[primary.id] ?? 0
              handle.setAttribute("aria-controls", primary.id)
              handle.setAttribute("aria-valuenow", String(Math.round(size)))
              handle.setAttribute("aria-valuemin", String(Math.round(minSize)))
              handle.setAttribute("aria-valuemax", String(Math.round(maxSize)))
            })
          }

          // The panel the handle resizes: the nearest preceding sibling.
          this._primaryOf = (handle) => {
            const panels = this._panels()
            const siblings = Array.from(group.children)
            const index = siblings.indexOf(handle)
            for (let i = index - 1; i >= 0; i--) {
              const found = panels.find((p) => p === siblings[i])
              if (found) return found
            }
            return panels[0]
          }

          // Move `delta` percentage points into `panel` from the others,
          // proportionally (the source's preserve-relative-size default),
          // honoring every panel's min/max and collapse snapping.
          this._resize = (panel, delta) => {
            const panels = this._panels()
            const config = panelConfig(panel)
            let target = (this._layout[panel.id] ?? 0) + delta

            if (config.collapsible) {
              const collapsed = (this._layout[panel.id] ?? 0) <= config.collapsedSize + 0.5
              if (collapsed && delta > 0 && target > config.minSize / 2 + config.collapsedSize) {
                // Dragging out of collapse restores the pre-collapse size.
                target = this._preCollapse != null ? this._preCollapse : config.minSize
              } else if (!collapsed && target < config.minSize) {
                // Crossing below min snaps toward collapsed.
                target = target < config.minSize / 2 ? config.collapsedSize : config.minSize
              }
            }

            const floor = config.collapsible ? config.collapsedSize : config.minSize
            target = Math.min(Math.max(target, floor), config.maxSize)
            const growth = target - (this._layout[panel.id] ?? 0)
            if (Math.abs(growth) < 0.01) return

            const others = panels.filter((p) => p !== panel)
            if (others.length === 0) return
            const othersTotal = others.reduce((sum, p) => sum + (this._layout[p.id] ?? 0), 0)

            if (growth > 0) {
              // Taking from the others, floor each at its min.
              let toTake = growth
              const next = {}
              others.forEach((p) => {
                const { minSize } = panelConfig(p)
                const current = this._layout[p.id] ?? 0
                const give = Math.min(current - minSize, (current / othersTotal) * toTake)
                next[p.id] = Math.max(current - give, minSize)
                toTake -= current - next[p.id]
              })
              if (toTake > 0.01) return
              others.forEach((p) => (this._layout[p.id] = next[p.id]))
            } else {
              // Giving to the others, ceil each at its max.
              let toGive = -growth
              const next = {}
              others.forEach((p) => {
                const { maxSize } = panelConfig(p)
                const current = this._layout[p.id] ?? 0
                const take = Math.min(maxSize - current, (current / othersTotal) * toGive)
                next[p.id] = Math.min(current + take, maxSize)
                toGive -= next[p.id] - current
              })
              if (toGive > 0.01) return
              others.forEach((p) => (this._layout[p.id] = next[p.id]))
            }
            this._layout[panel.id] = target
            this._apply()
          }

          // Pointer drag — document-level listeners, like the source.
          this._onHandleDown = (event) => {
            const handle = event.target.closest("[data-polaris-resizable-handle]")
            if (!handle || !group.contains(handle)) return
            if (handle.dataset.disabled === "true") return
            event.preventDefault()
            const panel = this._primaryOf(handle)
            if (!panel) return
            handle.dataset.separator = "active"
            const start = isVertical() ? event.clientY : event.clientX
            const groupRect = group.getBoundingClientRect()
            const groupSize = isVertical() ? groupRect.height : groupRect.width
            const startSize = this._layout[panel.id] ?? 0
            document.body.style.cursor = isVertical() ? "ns-resize" : "ew-resize"
            const onMove = (move) => {
              const current = isVertical() ? move.clientY : move.clientX
              const target = startSize + ((current - start) / groupSize) * 100
              this._resize(panel, target - (this._layout[panel.id] ?? 0))
            }
            const onUp = () => {
              handle.dataset.separator = handle.matches(":hover") ? "hover" : "inactive"
              document.body.style.cursor = ""
              document.removeEventListener("pointermove", onMove)
              document.removeEventListener("pointerup", onUp)
              this._save()
            }
            document.addEventListener("pointermove", onMove)
            document.addEventListener("pointerup", onUp)
          }
          group.addEventListener("pointerdown", this._onHandleDown)

          // Hover state rides data-separator, the source's states.
          this._onPointerOver = (event) => {
            const handle = event.target.closest("[data-polaris-resizable-handle]")
            this._handles().forEach((h) => {
              if (h !== handle && h.dataset.separator === "hover") h.dataset.separator = "inactive"
            })
            if (handle && handle.dataset.separator !== "active") {
              handle.dataset.separator = handle.dataset.disabled === "true" ? "disabled" : "hover"
            }
          }
          group.addEventListener("pointerover", this._onPointerOver)

          this._onPointerOut = (event) => {
            const handle = event.target.closest("[data-polaris-resizable-handle]")
            if (handle && handle.dataset.separator === "hover") {
              handle.dataset.separator = "inactive"
            }
          }
          group.addEventListener("pointerout", this._onPointerOut)

          // Keyboard: arrows ±5, Home/End extremes, Enter collapse-toggle,
          // F6 handle cycling — the source contract.
          this._onKeydown = (event) => {
            const handle = event.target.closest("[data-polaris-resizable-handle]")
            if (!handle || !group.contains(handle)) return
            const panel = this._primaryOf(handle)
            if (!panel) return
            const config = panelConfig(panel)
            const current = this._layout[panel.id] ?? 0
            const growKey = isVertical() ? "ArrowDown" : "ArrowRight"
            const shrinkKey = isVertical() ? "ArrowUp" : "ArrowLeft"

            if (event.key === growKey || event.key === shrinkKey) {
              event.preventDefault()
              this._resize(panel, event.key === growKey ? 5 : -5)
              this._save()
            } else if (event.key === "Home") {
              event.preventDefault()
              this._resize(panel, config.minSize - current)
              this._save()
            } else if (event.key === "End") {
              event.preventDefault()
              this._resize(panel, config.maxSize - current)
              this._save()
            } else if (event.key === "Enter") {
              if (!config.collapsible) return
              event.preventDefault()
              if (current <= config.collapsedSize + 0.5) {
                const restore = this._preCollapse != null ? this._preCollapse : config.minSize
                this._resize(panel, restore - current)
              } else {
                this._preCollapse = current
                this._resize(panel, config.collapsedSize - current)
              }
              this._save()
            } else if (event.key === "F6") {
              const handles = this._handles().filter((h) => h.dataset.disabled !== "true")
              if (handles.length < 2) return
              event.preventDefault()
              const index = handles.indexOf(handle)
              const next = event.shiftKey
                ? handles[(index - 1 + handles.length) % handles.length]
                : handles[(index + 1) % handles.length]
              next.focus()
            }
          }
          group.addEventListener("keydown", this._onKeydown)

          // Double-click resets the first neighbor with a default size.
          this._onDblClick = (event) => {
            const handle = event.target.closest("[data-polaris-resizable-handle]")
            if (!handle || !group.contains(handle)) return
            if (handle.dataset.disableDoubleClick === "true") return
            const panel = this._primaryOf(handle)
            if (!panel) return
            const { defaultSize } = panelConfig(panel)
            if (defaultSize == null) return
            this._resize(panel, defaultSize - (this._layout[panel.id] ?? 0))
            this._save()
          }
          group.addEventListener("dblclick", this._onDblClick)

          this._layout = this._loadSaved() || this._seedLayout()
          this._apply()
        },
        updated() {
          // LiveView patches may stomp inline flex-grow; re-apply.
          this._apply()
        },
        destroyed() {
          if (!this.el) {
            return
          }
          const g = this.el.querySelector("[data-polaris-resizable-group]")
          if (g) {
            g.removeEventListener("pointerdown", this._onHandleDown)
            g.removeEventListener("pointerover", this._onPointerOver)
            g.removeEventListener("pointerout", this._onPointerOut)
            g.removeEventListener("keydown", this._onKeydown)
            g.removeEventListener("dblclick", this._onDblClick)
          }
        }
      }
    </script>
    """
  end

  @doc """
  The resizable panel: one flexible pane of the group. Sits directly
  inside `resizable_group`, separated by `resizable_handle`s.
  """
  attr(:id, :string,
    default: nil,
    doc: """
    Stable panel id — required for layout persistence (`auto_save_id`)
    and derived as `"<group id>-panel-<index>"` when omitted.
    """
  )

  attr(:default_size, :any,
    default: nil,
    doc: """
    Initial percentage of the group — `"25"`, `"25%"`, or `25` all mean
    25%. Panels without one split the remainder evenly. Also the size
    double-click resets to.
    """
  )

  attr(:min_size, :any,
    default: "0",
    doc:
      "Smallest percentage the panel may take (dragging past it collapses a `collapsible` panel)."
  )

  attr(:max_size, :any, default: "100", doc: "Largest percentage the panel may take.")

  attr(:collapsible, :boolean,
    default: false,
    doc:
      "Snap to `collapsed_size` when dragged below `min_size`; **Enter** on the handle toggles it."
  )

  attr(:collapsed_size, :any, default: "0", doc: "The percentage a collapsed panel keeps.")

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the panel.")

  attr(:rest, :global, doc: "Forwarded to the panel: `data-*`, `phx-*`, …")

  slot(:inner_block, required: true, doc: "The panel content.")

  def resizable_panel(assigns) do
    assigns = assign(assigns, default_size_attr: to_size_attr(assigns.default_size))

    ~H"""
    <div
      id={@id}
      data-polaris-resizable-panel
      data-default-size={@default_size_attr}
      data-min-size={to_size_attr(@min_size)}
      data-max-size={to_size_attr(@max_size)}
      data-collapsible={to_string(@collapsible)}
      data-collapsed-size={to_size_attr(@collapsed_size)}
      class="flex min-h-0 min-w-0 shrink grow basis-0 overflow-hidden {@class}"
      style={@default_size_attr && "flex-grow: #{@default_size_attr}"}
      {@rest}
    >
      <div class="h-full w-full overflow-auto" data-polaris-resizable-panel-content>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  The resize handle between panels — the source's ResizableHandle: the
  1px line with the invisible 4px hit strip, and — with `with_handle`
  — the grip knob that fades in on hover. Styling keys off the group's
  `data-orientation` (the handle runs the other way), so the same
  handle works in either orientation.
  """
  attr(:id, :string, default: nil, doc: "Unique id for the handle.")

  attr(:with_handle, :boolean,
    default: false,
    doc: "Render the hover-revealed grip knob over the line."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Locks the handle and drops it from the tab order."
  )

  attr(:disable_double_click, :boolean,
    default: false,
    doc: "Suppress the double-click reset to `default_size`."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the handle.")

  attr(:rest, :global, doc: "Forwarded to the handle: `aria-label`, `data-*`, `phx-*`, …")

  def resizable_handle(assigns) do
    assigns =
      assign(assigns,
        handle_classes:
          cn([
            # The line — 1px, defaulting to the vertical line of a
            # horizontal group.
            "group relative flex items-center justify-center bg-surface-border transition-colors",
            "after:absolute after:inset-y-0 after:left-1/2 after:w-1 after:-translate-x-1/2",
            # In a vertical group the handle runs horizontally, keyed
            # off the group's data-orientation (the source's
            # aria-[orientation=horizontal] variants).
            "group-data-[orientation=vertical]/resizable:h-px",
            "group-data-[orientation=vertical]/resizable:w-full",
            "group-data-[orientation=vertical]/resizable:after:left-0",
            "group-data-[orientation=vertical]/resizable:after:h-1",
            "group-data-[orientation=vertical]/resizable:after:w-full",
            "group-data-[orientation=vertical]/resizable:after:-translate-y-1/2",
            "group-data-[orientation=vertical]/resizable:after:translate-x-0",
            "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-brand-emerald focus-visible:ring-offset-1",
            "data-[separator=active]:bg-surface-border-hover",
            "w-px",
            if(assigns.disabled, do: "cursor-not-allowed"),
            assigns.class
          ]),
        grip_classes:
          cn([
            "z-10 flex h-4 w-3 items-center justify-center rounded-xs border border-surface-border",
            "bg-surface-panel opacity-0 transition-opacity duration-200",
            "group-data-[separator=hover]:opacity-100 hover:bg-surface-panel-hover",
            "group-data-[separator=active]:opacity-100 group-data-[separator=active]:bg-surface-panel-hover",
            "group-data-[orientation=vertical]/resizable:rotate-90"
          ])
      )

    ~H"""
    <div
      id={@id}
      data-polaris-resizable-handle
      data-separator={if(@disabled, do: "disabled", else: "inactive")}
      data-disabled={to_string(@disabled)}
      data-disable-double-click={to_string(@disable_double_click)}
      role="separator"
      aria-disabled={to_string(@disabled)}
      tabindex={if(@disabled, do: "-1", else: "0")}
      class={@handle_classes}
      style="cursor: auto;"
      {@rest}
    >
      <div :if={@with_handle} class={@grip_classes} aria-hidden="true">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="currentColor"
          stroke="none"
          class="size-2.5 text-content-secondary"
        >
          <circle cx="9" cy="5" r="1" /><circle cx="9" cy="12" r="1" /><circle cx="9" cy="19" r="1" />
          <circle cx="15" cy="5" r="1" /><circle cx="15" cy="12" r="1" /><circle
            cx="15"
            cy="19"
            r="1"
          />
        </svg>
      </div>
    </div>
    """
  end

  # Sizes are percentages everywhere: "25", "25%", and 25 are one value.
  defp to_size_attr(nil), do: nil
  defp to_size_attr(size) when is_integer(size), do: Integer.to_string(size)
  defp to_size_attr(size) when is_float(size), do: Float.to_string(size)
  defp to_size_attr(size) when is_binary(size), do: String.replace_suffix(size, "%", "")

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
