defmodule PolarisUI.Components.Sonner do
  @moduledoc """
  The Polaris toaster: stacked, self-expiring notifications — the port
  of the Supabase design system Sonner (`packages/ui`, the shadcn
  wrapper over the [sonner](https://sonner.emilkowalski.dev) library).

  Toasts are for **short-lived, non-blocking feedback** — "Row copied",
  "Invite sent". Not for field validation, visible-form errors, or
  anything the user must act on; those belong to the Alert family.

  ## Anatomy

  Mount the toaster once, in the root layout:

      <.toaster id="toaster" />

  then fire toasts from any LiveView (or LiveComponent) with
  `push_event/3` and this module's payload builder:

      alias PolarisUI.Components.Sonner

      def handle_event("copy-row", _params, socket) do
        {:noreply,
         socket
         |> copy_row()
         |> push_event("sonner", Sonner.toast("Row copied"))}
      end

      def handle_event("delete-project", _params, socket) do
        {:noreply,
         socket
         |> delete_project()
         |> push_event(
           "sonner",
           Sonner.toast("Project deleted",
             type: "success",
             description: "The project and its data were removed.",
             action: %{label: "Undo", event: "undo-delete"}
           )
         )}
      end

    * **stack** — the fixed `<ol>` pinned to the position edge
      (`bottom-right` by default, the sonner default the Supabase docs
      keep). New toasts land at the front and the stack collapses
      behind the front toast — scaled, dimmed, clipped to its height —
      then expands on hover/focus to each toast's full height, exactly
      the sonner collapse.
    * **toast** — one rounded panel per event: the type icon, the
      message, an optional muted `description` (hidden on collapsed
      non-front toasts like the source), and right-aligned action /
      cancel buttons. The default look is the source's unstyled-mode
      panel (`bg-surface-panel` over a border and shadow); `warning`
      and `error` toasts tint (`bg-warning-muted`/`bg-danger-muted`
      with matching borders) like the source's per-type classNames.
    * **icons** — the source's set: a plain emerald check for
      `success`, the StatusIcon badge for `info`/`warning`/`error`,
      and a spinner for `loading`.
    * **close** — a ✕ that appears on hover (on by default, the
      source's `closeButton: true`).

  ## Behavior

  The colocated hook owns everything client-side, mirroring sonner:
  toasts slide in from the position edge (400ms), expire after
  `duration` (4000ms default; `:infinity` sticks, `loading` never
  auto-closes), the timer pauses while hovered/expanded, swipe (or
  fling) dismisses past 45px, action buttons push their LiveView event
  and dismiss, cancel buttons push theirs, and Escape collapses an
  expanded stack. Only `visible` toasts render (3 by default) — the
  rest stay in the queue.

  ## Microcopy

  Per the Supabase copywriting guidelines: state what happened with a
  direct verb ("Row copied", "Invite sent"), keep error copy specific
  with the next step ("Project deleted — undo within 30 seconds"),
  and give actions concrete verbs ("Undo", "View log"), never "OK".

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @positions ~w(top-left top-center top-right bottom-left bottom-center bottom-right)
  @types ~w(default success error warning info loading)

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the toaster root — required because the colocated
    hook that owns the stack anchors on it. Mount one per layout.
    """
  )

  attr(:position, :string,
    values: @positions,
    default: "bottom-right",
    doc: "The viewport corner the stack pins to — `bottom-right`, the sonner default."
  )

  attr(:duration, :integer,
    default: 4000,
    doc: """
    Default lifetime in ms (the source's `SONNER_DEFAULT_DURATION`).
    Per-toast `duration:` overrides it; `:infinity` sticks.
    """
  )

  attr(:visible, :integer,
    default: 3,
    doc: "How many toasts render in the stack — the sonner `visibleToasts` default."
  )

  attr(:gap, :integer,
    default: 14,
    doc: "Pixels between stacked toasts — the sonner default."
  )

  attr(:offset, :integer,
    default: 24,
    doc: "Pixels between the stack and the viewport edges."
  )

  attr(:expand, :boolean,
    default: false,
    doc: "Keep the stack expanded instead of collapsed-until-hover — the sonner `expand` prop."
  )

  attr(:close_button, :boolean,
    default: true,
    doc: "Show the ✕ on toasts (the source defaults it on, unlike stock sonner)."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the stack list.")
  attr(:rest, :global, doc: "Forwarded to the root wrapper: `data-*`, …")

  def toaster(assigns) do
    validate_in!(:position, assigns.position, @positions)

    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Toaster",
        list_style: [
          position_style(assigns.position, assigns.offset),
          "width: min(356px, calc(100vw - 32px));",
          "z-index: 999999999;"
        ]
        |> Enum.join(" ")
      )

    ~H"""
    <div
      id={@id}
      class="contents"
      data-polaris-sonner
      data-position={@position}
      data-duration={@duration}
      data-visible={@visible}
      data-gap={@gap}
      data-expand={to_string(@expand)}
      data-close-button={to_string(@close_button)}
      phx-hook={@hook}
      {@rest}
    >
      <section aria-label="Notifications" aria-live="polite">
        <ol
          data-polaris-sonner-list
          class={cn(["fixed pointer-events-none", @class])}
          style={@list_style}
        >
        </ol>
      </section>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Toaster" runtime>
      {
        mounted() {
          this._toasts = []
          this._expanded = this.el.dataset.expand === "true"
          this._counter = 0
          this._listen("sonner", (payload) => this._add(payload))
          this._listen("sonner-dismiss", (payload) => this._dismissId(payload && payload.id))
          this._onHover = () => { this._setExpanded(true) }
          this._onLeave = () => { this._setExpanded(this.el.dataset.expand === "true") }
          const list = this._list()
          list.addEventListener("pointerenter", this._onHover)
          list.addEventListener("pointerleave", this._onLeave)
          this._onEscape = (event) => {
            if (event.key === "Escape") this._setExpanded(false)
          }
          document.addEventListener("keydown", this._onEscape)
        },
        destroyed() {
          const list = this._list()
          list && list.removeEventListener("pointerenter", this._onHover)
          list && list.removeEventListener("pointerleave", this._onLeave)
          document.removeEventListener("keydown", this._onEscape)
          this._toasts.forEach((toast) => this._clearTimer(toast))
        },
        _listen(name, handler) {
          if (typeof this.handleEvent === "function") {
            this.handleEvent(name, handler)
          }
        },
        _list() {
          return this.el.querySelector("[data-polaris-sonner-list]")
        },
        _config() {
          const data = this.el.dataset
          return {
            position: data.position || "bottom-right",
            duration: parseInt(data.duration, 10) || 4000,
            visible: parseInt(data.visible, 10) || 3,
            gap: parseInt(data.gap, 10) || 14,
            closeButton: data.closeButton !== "false"
          }
        },
        // The lift direction: stacks grow away from the pinned edge.
        _lift() {
          return this._config().position.startsWith("top") ? -1 : 1
        },
        _add(payload) {
          if (!payload || !payload.message) return
          const config = this._config()
          const id = payload.id !== undefined ? payload.id : `sonner-${++this._counter}`
          const existing = this._toasts.find((toast) => toast.id === id)
          if (existing) {
            this._update(existing, payload)
            return
          }
          const toast = {
            id: id,
            type: payload.type || "default",
            message: payload.message,
            description: payload.description || null,
            duration: payload.duration === ":infinity" || payload.duration === Infinity
              ? Infinity
              : payload.duration || config.duration,
            action: payload.action || null,
            cancel: payload.cancel || null,
            closeButton:
              payload.close_button !== undefined
                ? payload.close_button !== false
                : config.closeButton,
            element: null,
            timer: null,
            remaining: null,
            startedAt: null
          }
          this._toasts.unshift(toast)
          this._render(toast)
          this._layout()
          this._startTimer(toast)
        },
        _update(toast, payload) {
          toast.message = payload.message
          toast.description = payload.description || toast.description
          toast.type = payload.type || toast.type
          if (payload.duration !== undefined) {
            this._clearTimer(toast)
            toast.duration =
              payload.duration === ":infinity" || payload.duration === Infinity
                ? Infinity
                : payload.duration
            this._startTimer(toast)
          }
          this._paint(toast)
          this._layout()
        },
        _render(toast) {
          const list = this._list()
          const item = document.createElement("li")
          item.dataset.polarisSonnerToast = ""
          item.setAttribute("role", "status")
          item.tabIndex = 0
          item.style.position = "absolute"
          item.style.left = "0"
          item.style.right = "0"
          item.style.transition =
            "transform 400ms ease, opacity 400ms ease, height 400ms ease"
          toast.element = item
          this._paint(toast)
          this._wire(toast)
          // Enter: slide in from the position edge, like sonner's
          // translateY(100%) mount.
          const enter = this._enterTransform()
          item.style.opacity = "0"
          item.style.transform = enter
          list.appendChild(item)
          requestAnimationFrame(() => {
            requestAnimationFrame(() => this._layout())
          })
        },
        _paint(toast) {
          const item = toast.element
          if (!item) return
          item.dataset.type = toast.type === "default" ? "default" : toast.type
          if (toast.type === "loading") item.dataset.loading = "true"
          item.className = [
            "group pointer-events-auto flex w-full items-start gap-2 rounded-md border px-5 py-3 text-sm font-normal shadow-lg",
            this._surfaceClasses(toast.type)
          ].join(" ")
          const parts = []
          parts.push(this._closeButton(toast))
          parts.push(`<div data-icon class="mt-0.5">${this._icon(toast.type)}</div>`)
          parts.push(
            `<div data-content class="grow"><div data-title class="font-normal">${this._escape(
              toast.message
            )}</div>${
              toast.description
                ? `<div data-description class="text-xs text-content-muted transition-opacity">${this._escape(
                    toast.description
                  )}</div>`
                : ""
            }</div>`
          )
          if (toast.cancel) {
            parts.push(
              `<button type="button" data-button data-cancel class="${this._cancelClasses()}">${this._escape(
                toast.cancel.label
              )}</button>`
            )
          }
          if (toast.action) {
            parts.push(
              `<button type="button" data-button data-action class="${this._actionClasses()}">${this._escape(
                toast.action.label
              )}</button>`
            )
          }
          item.innerHTML = parts.join("")
        },
        _surfaceClasses(type) {
          if (type === "warning") return "bg-warning-muted border-warning"
          if (type === "error") return "bg-danger-muted border-danger"
          return "bg-surface-panel border-surface-border text-content-primary"
        },
        _actionClasses() {
          return [
            "block h-[26px] px-2.5 py-1 text-xs cursor-pointer rounded-xs",
            "border border-brand-border bg-brand-fill text-content-primary",
            "hover:bg-brand-fill-hover hover:border-brand-border-hover",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
          ].join(" ")
        },
        _cancelClasses() {
          return [
            "block h-[26px] px-2.5 py-1 text-xs cursor-pointer rounded-xs",
            "border border-surface-border bg-surface-panel text-content-primary",
            "hover:bg-surface-panel-hover hover:border-surface-border-hover",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
          ].join(" ")
        },
        _closeButton(toast) {
          if (!toast.closeButton || toast.type === "loading") return ""
          return `<button type="button" data-close-button aria-label="Dismiss notification" class="absolute right-2 top-2 flex size-6 items-center justify-center rounded-md text-content-muted opacity-0 transition-opacity hover:bg-surface-panel-hover hover:text-content-primary focus-visible:opacity-100 group-hover:opacity-100">${this._closeIcon()}</button>`
        },
        _icon(type) {
          if (type === "success") return this._successIcon()
          if (type === "warning") return this._badgeIcon("bg-warning", this._warningPath())
          if (type === "error") return this._badgeIcon("bg-danger", this._errorPath())
          if (type === "loading") {
            return '<span class="inline-block size-4 animate-spin rounded-full border-2 border-content-muted border-t-content-primary" aria-hidden="true"></span>'
          }
          return this._badgeIcon("bg-content-primary", this._infoPath())
        },
        _successIcon() {
          return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="mt-0.5 size-4 text-brand-emerald" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>'
        },
        // The StatusIcon badge: a colored square carrying the glyph.
        _badgeIcon(surface, path) {
          return `<span class="flex size-4 shrink-0 items-center justify-center rounded-xs p-0.5 ${surface} text-surface-ground"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="size-3" aria-hidden="true"><path d="${path}"/></svg></span>`
        },
        _infoPath() {
          return "M15 8A7 7 0 1 1 1 8a7 7 0 0 1 14 0ZM9 5a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM6.75 8a.75.75 0 0 0 0 1.5h.75v1.75a.75.75 0 0 0 1.5 0v-2.5A.75.75 0 0 0 8.25 8h-1.5Z"
        },
        _warningPath() {
          return "M8 15A7 7 0 1 0 8 1a7 7 0 0 0 0 14ZM8 4a.75.75 0 0 1 .75.75v3a.75.75 0 0 1-1.5 0v-3A.75.75 0 0 1 8 4Zm0 8a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"
        },
        _errorPath() {
          return "M6.701 2.25c.577-1 2.02-1 2.598 0l5.196 9a1.5 1.5 0 0 1-1.299 2.25H2.804a1.5 1.5 0 0 1-1.3-2.25l5.197-9ZM8 4a.75.75 0 0 1 .75.75v3a.75.75 0 1 1-1.5 0v-3A.75.75 0 0 1 8 4Zm0 8a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"
        },
        _closeIcon() {
          return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" class="size-3" aria-hidden="true"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>'
        },
        _escape(text) {
          const div = document.createElement("div")
          div.textContent = String(text)
          return div.innerHTML
        },
        _wire(toast) {
          const item = toast.element
          item.addEventListener("click", (event) => {
            const closer = event.target.closest("[data-close-button]")
            if (closer) {
              this._dismiss(toast)
              return
            }
            const action = event.target.closest("[data-action]")
            if (action && toast.action) {
              this._push(toast.action.event)
              this._dismiss(toast)
              return
            }
            const cancel = event.target.closest("[data-cancel]")
            if (cancel && toast.cancel) {
              this._push(toast.cancel.event)
              this._dismiss(toast)
            }
          })
          this._wireSwipe(toast)
        },
        // Swipe (or fling) dismisses past 45px — sonner's threshold
        // and 0.11 px/ms velocity.
        _wireSwipe(toast) {
          const item = toast.element
          item.addEventListener("pointerdown", (event) => {
            if (event.button !== 0) return
            if (event.target.closest("button")) return
            if (toast.type === "loading") return
            const startX = event.clientX
            const startY = event.clientY
            let lastAt = performance.now()
            let lastPos = startX
            let velocity = 0
            let travel = 0
            const onMove = (moveEvent) => {
              const dx = moveEvent.clientX - startX
              const dy = moveEvent.clientY - startY
              const along = Math.abs(dx) > Math.abs(dy) ? dx : dy
              travel = Math.max(travel, Math.abs(along))
              item.style.transition = "none"
              item.style.opacity = String(Math.max(0.4, 1 - Math.abs(along) / 160))
              item.style.transform = `translate(${dx}px, ${dy}px)`
              const now = performance.now()
              if (now > lastAt) {
                velocity = Math.abs((moveEvent.clientX - lastPos) / (now - lastAt))
                lastAt = now
                lastPos = moveEvent.clientX
              }
            }
            const onUp = () => {
              document.removeEventListener("pointermove", onMove)
              document.removeEventListener("pointerup", onUp)
              document.removeEventListener("pointercancel", onUp)
              item.style.transition = ""
              if (travel >= 45 || velocity > 0.11) {
                this._dismiss(toast)
              } else {
                item.style.opacity = ""
                this._layout()
              }
            }
            document.addEventListener("pointermove", onMove)
            document.addEventListener("pointerup", onUp)
            document.addEventListener("pointercancel", onUp)
          })
        },
        _push(name) {
          if (name && typeof this.pushEvent === "function") {
            this.pushEvent(name)
          }
        },
        _startTimer(toast) {
          this._clearTimer(toast)
          if (toast.type === "loading" || toast.duration === Infinity) return
          toast.remaining = toast.duration
          toast.startedAt = performance.now()
          toast.timer = setTimeout(() => this._dismiss(toast), toast.duration)
        },
        _clearTimer(toast) {
          if (toast.timer) {
            clearTimeout(toast.timer)
            toast.timer = null
          }
        },
        // The timer pauses while the stack is hovered/expanded.
        _pauseTimers() {
          this._toasts.forEach((toast) => {
            if (!toast.timer) return
            this._clearTimer(toast)
            toast.remaining = Math.max(
              0,
              toast.remaining - (performance.now() - toast.startedAt)
            )
          })
        },
        _resumeTimers() {
          this._toasts.forEach((toast) => {
            if (toast.timer || toast.type === "loading" || toast.duration === Infinity) return
            if (toast.remaining === null) return
            toast.startedAt = performance.now()
            toast.timer = setTimeout(() => this._dismiss(toast), toast.remaining)
          })
        },
        _setExpanded(expanded) {
          if (this._expanded === expanded) return
          this._expanded = expanded
          if (expanded) {
            this._pauseTimers()
          } else {
            this._resumeTimers()
          }
          this._layout()
        },
        _enterTransform() {
          const position = this._config().position
          if (position.startsWith("top")) return "translateY(-100%)"
          if (position.endsWith("left")) return "translateX(-100%)"
          if (position.endsWith("right")) return "translateX(100%)"
          return "translateY(100%)"
        },
        // Sonner's stack math: the front toast at full height; behind
        // it, translated by index*gap and scaled 5% per depth while
        // collapsed; expanded, stacked by measured heights.
        _layout() {
          const config = this._config()
          const lift = this._lift()
          const front = this._toasts.find((toast) => toast.element)
          if (!front) return
          const frontHeight = front.element.getBoundingClientRect().height
          let offset = 0
          this._toasts.forEach((toast, index) => {
            const item = toast.element
            if (!item) return
            const visible = index < config.visible
            item.dataset.index = String(index)
            item.dataset.front = index === 0 ? "true" : "false"
            item.dataset.expanded = this._expanded ? "true" : "false"
            item.dataset.visible = visible ? "true" : "false"
            item.style.pointerEvents = visible ? "auto" : "none"
            const description = item.querySelector("[data-description]")
            if (description) {
              description.style.opacity =
                this._expanded || index === 0 ? "1" : "0"
            }
            const natural = item.scrollHeight
            if (index === 0) {
              item.style.height = ""
              item.style.transform = "translateY(0)"
              item.style.opacity = visible ? "1" : "0"
            } else if (this._expanded) {
              offset += this._toasts[index - 1].element
                ? this._toasts[index - 1].element.getBoundingClientRect().height
                : 0
              item.style.height = ""
              item.style.transform = `translateY(${lift * (offset + index * config.gap)}px) scale(1)`
              item.style.opacity = visible ? "1" : "0"
            } else {
              item.style.height = `${frontHeight}px`
              item.style.transform = `translateY(${lift * index * config.gap}px) scale(${1 - index * 0.05})`
              item.style.opacity = "0"
            }
            // Keep the description measurable after clipping.
            if (description && index > 0 && !this._expanded) {
              item.style.overflow = "hidden"
            } else {
              item.style.overflow = ""
            }
          })
        },
        _dismissId(id) {
          if (id === undefined) {
            this._toasts.slice().forEach((toast) => this._dismiss(toast))
            return
          }
          const toast = this._toasts.find((candidate) => String(candidate.id) === String(id))
          if (toast) this._dismiss(toast)
        },
        _dismiss(toast) {
          if (!toast.element) return
          this._clearTimer(toast)
          const item = toast.element
          item.style.transition = "transform 200ms ease-out, opacity 200ms ease-out"
          item.style.opacity = "0"
          item.style.transform = this._enterTransform()
          const removed = toast
          setTimeout(() => {
            item.remove()
            this._toasts = this._toasts.filter((candidate) => candidate !== removed)
            this._layout()
          }, 200)
        }
      }
    </script>
    """
  end

  @doc """
  Builds a toast payload for `push_event(socket, "sonner", ...)` — the
  LiveView stand-in for sonner's `toast()` family.

      Sonner.toast("Row copied")
      Sonner.toast("Project deleted", type: "success", description: "Its data was removed.",
                                        action: %{label: "Undo", event: "undo-delete"})
      Sonner.toast("Uploading…", type: "loading", duration: :infinity)

  Options:

    * `:type` — `"default"`, `"success"`, `"error"`, `"warning"`,
      `"info"`, or `"loading"` (spinner, never auto-closes).
    * `:description` — the muted second line (only shown on the front
      toast or when expanded).
    * `:duration` — lifetime in ms; `:infinity` sticks.
    * `:action` / `:cancel` — `%{label: ..., event: ...}` buttons;
      the hook pushes `event` to the LiveView and dismisses.
    * `:id` — pass the same id again to update a toast in place
      (the loading → success transition).
    * `:close_button` — per-toast ✕ override.

  Messages use direct verbs ("Row copied", "Invite sent") and error
  copy stays specific with the next step.
  """
  @spec toast(String.t(), keyword()) :: map()
  def toast(message, opts \\ []) when is_binary(message) do
    type = Keyword.get(opts, :type, "default")

    unless type in @types do
      raise ArgumentError,
            "invalid value for :type: #{inspect(type)} — expected one of #{inspect(@types)}"
    end

    %{
      message: message,
      type: type,
      description: Keyword.get(opts, :description),
      duration: encode_duration(Keyword.get(opts, :duration)),
      action: Keyword.get(opts, :action),
      cancel: Keyword.get(opts, :cancel),
      id: Keyword.get(opts, :id),
      close_button: Keyword.get(opts, :close_button)
    }
    |> compact()
  end

  defp encode_duration(:infinity), do: ":infinity"
  defp encode_duration(nil), do: nil
  defp encode_duration(duration) when is_integer(duration), do: duration

  defp encode_duration(duration) do
    raise ArgumentError, "invalid :duration: #{inspect(duration)} — expected ms or :infinity"
  end

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  # The stack's inset per position — sonner's data-x/y-position edges.
  defp position_style("top-" <> edge, offset), do: edge_style("top", edge, offset)
  defp position_style("bottom-" <> edge, offset), do: edge_style("bottom", edge, offset)

  defp edge_style(y_edge, x_edge, offset) do
    x_style =
      case x_edge do
        "left" -> "left: #{offset}px;"
        "right" -> "right: #{offset}px;"
        "center" -> "left: 50%; transform: translateX(-50%);"
      end

    "#{y_edge}: #{offset}px; #{x_style}"
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
