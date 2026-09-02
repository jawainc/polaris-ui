defmodule PolarisUI.Components.Tabs do
  @moduledoc """
  The Polaris tabs: a set of layered content sections — tab panels —
  shown one at a time; the port of the Supabase design system Tabs
  (`packages/ui/src/components/shadcn/ui/tabs.tsx`, a shadcn wrapper
  over the Radix Tabs): the `border-b` list with underline triggers
  that promote their label and grow the 2px content-color bar while
  active.

  ## Anatomy

      <.tabs id="settings" value={@tab} on_change="set-tab">
        <.tabs_list>
          <.tabs_trigger value="account" active={@tab == "account"}>Account</.tabs_trigger>
          <.tabs_trigger value="password" active={@tab == "password"}>Password</.tabs_trigger>
        </.tabs_list>
        <.tabs_content value="account" active={@tab == "account"}>
          Account settings…
        </.tabs_content>
        <.tabs_content value="password" active={@tab == "password"}>
          Password settings…
        </.tabs_content>
      </.tabs>

    * **root** — the `<.tabs>` wrapper the colocated hook anchors on:
      it carries the `value` seed, the `on_change` mirror, and the
      `orientation` the keyboard contract follows.
    * **list** — `<.tabs_list>`: the `role="tablist"` row with the
      shared bottom border (the source's `flex items-center border-b`).
    * **triggers** — `<.tabs_trigger>`: real `role="tab"` buttons.
      Active triggers carry `aria-selected` / `data-state="active"` and
      the 2px `border-b-2` underline in the content color, exactly the
      source's `data-[state=active]:border-foreground` treatment.
    * **panels** — `<.tabs_content>`: `role="tabpanel"` regions, each
      `hidden` unless its value is active, spaced `mt-4` below the
      list like the source.

  ## State model

    Selection is **client-side**, like Radix: the colocated runtime
    hook owns the active value — seeded from the root's `value` (or
    the first trigger painted `active` at SSR), then authoritative,
    re-applying `data-state`, `aria-selected`, the roving tab stop,
    and each panel's `hidden` after every LiveView patch. Each change
    optionally mirrors to the server via `on_change`
    (`%{"value" => value}`).

    For a paint-correct first render, pass `active={@tab == value}` on
    each trigger and panel (the `nav_menu_item` `is_active` pattern);
    with only the root's `value` set, the hook corrects the DOM at
    mount. Activation is **automatic** (the Radix default — arrows
    select as they move), and there is **no loading state** — gate a
    trigger with `disabled` while its consequence is in flight.

  ## Keyboard

    One roving tab stop (the active trigger, else the first enabled):
    **Tab** enters the list there and moves on; the **arrow keys along
    the orientation** (ArrowLeft/Right horizontal, ArrowDown/Up
    vertical) wrap through the enabled triggers, selecting as they go;
    **Home**/**End** jump to the first/last. **Enter**/**Space**
    activate the focused trigger (native button behavior). Panels are
    focusable (`tabindex="0"`, like Radix) so keyboard users can reach
    their content.

  ## Accessibility

    * The list is a `role="tablist"` landmark — name it with
      `aria-label` through the list's global attributes ("Settings");
      triggers are `role="tab"` buttons carrying `aria-selected`.
    * The hook derives element ids from the root (`"<id>-trigger-<value>"`
      / `"<id>-content-<value>"`) and wires `aria-controls` on every
      trigger to its panel and `aria-labelledby` back — the Radix
      id contract without caller bookkeeping.
    * Inactive panels carry the `hidden` attribute, keeping them out
      of the tab order and assistive tech, exactly like the source.

  ## Microcopy

    Trigger labels are short nouns naming the panel's content
    ("Account", "Password", "Logs") — never verbs ("View logs"),
    consistent within one list.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @orientations ~w(horizontal vertical)

  # The source's TabsList: the shared underline row the triggers sit
  # on (the trigger's own border-b-2 rides on top of it).
  defp list_classes,
    do: ["flex items-center border-b border-surface-border"]

  # The source's TabsTrigger, expanded: the muted label promoting on
  # hover and on active, the 2px transparent underline growing into
  # the content color while active, and the focus-ring utility
  # expanded to the shared emerald ring.
  defp trigger_classes,
    do: [
      "group inline-flex cursor-pointer items-center justify-center whitespace-nowrap",
      "border-b-2 border-transparent py-1.5 text-sm transition-colors",
      "text-content-secondary hover:text-content-primary",
      "data-[state=active]:text-content-primary data-[state=active]:border-content-primary",
      "data-[state=active]:shadow-xs",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
      "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
      "disabled:pointer-events-none disabled:opacity-50"
    ]

  # The source's TabsContent: the panel spacing below the list with
  # the same expanded focus-ring (the panel is focusable, like Radix).
  defp content_classes,
    do: [
      "mt-4 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
      "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    ]

  @doc """
  Renders the tabs root — the wrapper the hook anchors on.
  """
  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the tabs root — required because the colocated hook
    that owns selection anchors on it. Trigger and panel element ids
    derive from it (`"<id>-trigger-<value>"` / `"<id>-content-<value>"`).
    """
  )

  attr(:value, :string,
    default: nil,
    doc: """
    The active tab's value — seeds the hook (which owns selection from
    mount on). Mirror it back through `on_change` to keep the server
    in sync.
    """
  )

  attr(:on_change, :string,
    default: nil,
    doc: """
    Optional LiveView event pushed on every activation with
    `%{"value" => value}`.
    """
  )

  attr(:orientation, :string,
    values: @orientations,
    default: "horizontal",
    doc: """
    Which axis the triggers stack along — `horizontal` (the default)
    or `vertical`. Drives the arrow-key pair and the list's
    `aria-orientation`.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the root.")

  attr(:rest, :global, doc: "Forwarded to the root: `data-*`, `phx-*`, …")

  slot(:inner_block,
    required: true,
    doc: "The tabs parts: one `<.tabs_list>` then the `<.tabs_content>` panels."
  )

  def tabs(assigns) do
    validate_in!(:orientation, assigns.orientation, @orientations)

    assigns =
      assign(assigns, hook: "#{inspect(__MODULE__)}.Root")

    ~H"""
    <div
      id={@id}
      data-polaris-tabs
      data-value={@value}
      data-orientation={@orientation}
      data-change-event={@on_change}
      class={@class}
      phx-hook={@hook}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          this._triggers = () => Array.from(root.querySelectorAll("[data-polaris-tabs-trigger]"))
          this._contents = () => Array.from(root.querySelectorAll("[data-polaris-tabs-content]"))
          this._enabled = () => this._triggers().filter((el) => el.dataset.disabled !== "true")
          this._vertical = () => root.dataset.orientation === "vertical"

          // The root's value wins; else keep whichever trigger the SSR
          // painted active (the per-trigger `active` attr).
          const painted = this._triggers().find((el) => el.dataset.state === "active")
          this._value = root.dataset.value || (painted ? painted.dataset.value : null)

          this._apply = () => {
            const enabled = this._enabled()
            const activeTrigger = this._triggers().find((el) => el.dataset.value === this._value)
            // One roving tab stop: the active trigger, else the first enabled.
            const tabstop = (activeTrigger && enabled.indexOf(activeTrigger) !== -1 && activeTrigger) || enabled[0] || null
            for (const el of this._triggers()) {
              const active = el.dataset.value === this._value
              el.dataset.state = active ? "active" : "inactive"
              el.setAttribute("aria-selected", String(active))
              el.tabIndex = el === tabstop ? 0 : -1
            }
            for (const el of this._contents()) {
              const active = el.dataset.value === this._value
              el.dataset.state = active ? "active" : "inactive"
              el.hidden = !active
            }
            const list = root.querySelector("[data-polaris-tabs-list]")
            if (list) {
              list.setAttribute("aria-orientation", this._vertical() ? "vertical" : "horizontal")
            }
          }

          // The Radix id contract: derive ids from the root and wire
          // aria-controls / aria-labelledby between value-matched pairs.
          this._wireIds = () => {
            for (const trigger of this._triggers()) {
              if (!trigger.id) trigger.id = root.id + "-trigger-" + trigger.dataset.value
              const panel = this._contents().find((el) => el.dataset.value === trigger.dataset.value)
              if (panel) {
                if (!panel.id) panel.id = root.id + "-content-" + panel.dataset.value
                trigger.setAttribute("aria-controls", panel.id)
                panel.setAttribute("aria-labelledby", trigger.id)
              }
            }
          }

          this._select = (value) => {
            this._value = value
            this._apply()
            const name = root.dataset.changeEvent
            if (name && typeof this.pushEvent === "function") {
              this.pushEvent(name, { value: value })
            }
          }

          // Delegated on the root, so LiveView morphs never orphan it.
          this._onClick = (event) => {
            const trigger = event.target.closest("[data-polaris-tabs-trigger]")
            if (trigger && root.contains(trigger) && trigger.dataset.disabled !== "true") {
              this._select(trigger.dataset.value)
            }
          }
          root.addEventListener("click", this._onClick)

          this._onKeydown = (event) => {
            const trigger = event.target.closest("[data-polaris-tabs-trigger]")
            if (!trigger || !root.contains(trigger) || trigger.dataset.disabled === "true") return
            const enabled = this._enabled()
            if (!enabled.length) return
            const index = enabled.indexOf(trigger)
            // Automatic activation, the Radix default: arrows select
            // and focus in one move, wrapping; Home/End jump.
            const move = (i) => {
              event.preventDefault()
              const next = enabled[i]
              this._select(next.dataset.value)
              next.focus()
            }
            if (event.key === (this._vertical() ? "ArrowDown" : "ArrowRight")) {
              move((index + 1) % enabled.length)
            } else if (event.key === (this._vertical() ? "ArrowUp" : "ArrowLeft")) {
              move((index - 1 + enabled.length) % enabled.length)
            } else if (event.key === "Home") {
              move(0)
            } else if (event.key === "End") {
              move(enabled.length - 1)
            }
          }
          root.addEventListener("keydown", this._onKeydown)

          this._wireIds()
          this._apply()
        },
        updated() {
          // LiveView patches stomp data-state/aria/hidden; reconcile the
          // DOM from the hook-owned value, never from the server HTML.
          this._wireIds()
          this._apply()
        },
        destroyed() {
          if (!this.el) {
            return
          }
          this.el.removeEventListener("click", this._onClick)
          this.el.removeEventListener("keydown", this._onKeydown)
        }
      }
    </script>
    """
  end

  @doc """
  Renders the tab list — the `role="tablist"` row with the shared
  bottom border (the source's `TabsList`).
  """
  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the list (e.g. `grid w-full
    grid-cols-2` to stretch triggers, like the source's demo).
    """
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the list: `aria-label` (name the landmark —
    \"Settings\"), `data-*`, `phx-*`, …
    """
  )

  slot(:inner_block, required: true, doc: "The `<.tabs_trigger>` buttons.")

  def tabs_list(assigns) do
    ~H"""
    <div
      role="tablist"
      data-polaris-tabs-list
      class={cn([list_classes(), @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders one tab trigger — a real `role="tab"` button with the
  source's underline treatment. Pair it with a `<.tabs_content>` of
  the same `value`.
  """
  attr(:value, :string,
    required: true,
    doc: "The tab's value — pairs with the `<.tabs_content>` of the same value."
  )

  attr(:active, :boolean,
    default: false,
    doc: """
    First-paint selection state (compute from the server's tab, like
    `nav_menu_item`'s `is_active`). The hook owns selection from mount
    on; the root's `value` seed also works with only a mount-time
    correction.
    """
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Locks the trigger, dims it, and drops it from the tab order."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the trigger.")

  attr(:rest, :global,
    doc: """
    Forwarded to the trigger button: `id` (the hook derives one from
    the root otherwise), `aria-label`, `data-*`, `phx-*`, …
    """
  )

  slot(:inner_block,
    required: true,
    doc: "The trigger's label — a short noun naming the panel (\"Account\")."
  )

  def tabs_trigger(assigns) do
    assigns =
      assign(assigns,
        state: if(assigns.active, do: "active", else: "inactive"),
        aria_selected: to_string(assigns.active)
      )

    ~H"""
    <button
      type="button"
      role="tab"
      aria-selected={@aria_selected}
      data-polaris-tabs-trigger
      data-value={@value}
      data-state={@state}
      data-disabled={@disabled && "true"}
      disabled={@disabled}
      tabindex={if(@active, do: "0", else: "-1")}
      class={cn([trigger_classes(), @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders one tab panel — the `role="tabpanel"` region shown while its
  value is active, `hidden` otherwise (the source's `TabsContent`).
  """
  attr(:value, :string,
    required: true,
    doc: "The tab's value — pairs with the `<.tabs_trigger>` of the same value."
  )

  attr(:active, :boolean,
    default: false,
    doc: "First-paint visibility (compute from the server's tab); the hook owns it from mount on."
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the panel.")

  attr(:rest, :global,
    doc: """
    Forwarded to the panel: `id` (the hook derives one from the root
    otherwise), `data-*`, `phx-*`, …
    """
  )

  slot(:inner_block, required: true, doc: "The panel's content.")

  def tabs_content(assigns) do
    assigns =
      assign(assigns, state: if(assigns.active, do: "active", else: "inactive"))

    ~H"""
    <div
      role="tabpanel"
      tabindex="0"
      data-polaris-tabs-content
      data-value={@value}
      data-state={@state}
      hidden={!@active}
      class={cn([content_classes(), @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
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
