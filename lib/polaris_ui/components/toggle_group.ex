defmodule PolarisUI.Components.ToggleGroup do
  @moduledoc """
  The Polaris toggle group: a set of two-state triggers acting as one
  control — the port of the Supabase design system ToggleGroup family
  (`packages/ui`, a shadcn wrapper over the Radix ToggleGroup): toolbar
  styles such as text alignment or filtering, in `single` (one active
  value, deactivatable) or `multiple` (a free set) mode.

  ## Anatomy

      <.toggle_group id="alignment" type="single" value="left" on_change="set-alignment">
        <.toggle_group_item value="left">Left</.toggle_group_item>
        <.toggle_group_item value="center">Center</.toggle_group_item>
        <.toggle_group_item value="right">Right</.toggle_group_item>
      </.toggle_group>

    * **group** — the `role="group"` container (`flex items-center
      justify-center gap-1`) the colocated hook anchors on; give it a
      name via `aria-label` through the global attributes.
    * **items** — real `aria-pressed` buttons with the `toggle`'s class
      vocabulary: the ghost treatment at rest, muted wash when on, on
      the shared size scale.

  ## State model

    Like Radix, selection is **client-side**: the colocated runtime
    hook owns the state machine — click or arrow keys toggle an item,
    and unlike radios, **clicking the active item deactivates it**
    (Radix toggle semantics). `single` keeps at most one active value
    (`on_change` pushes `%{"value" => value}`, `nil` when cleared);
    `multiple` toggles a free set (`%{"value" => [values]}`). Seed the
    initial selection either from the root's `value` (a string, or a
    list for `multiple`) or per-item `checked` (which also paints the
    server-rendered HTML); from mount on, the hook is authoritative
    and re-applies after LiveView patches.

    The Radix ToggleGroup has **no form participation by design** —
    there is no hidden input. It is an instant control; mirror its
    state through `on_change` (or use `radio_group` when the choice
    belongs in a form). There is also **no loading state** — a toggle
    group is instant; gate items with `disabled` while work is in
    flight.

  ## Variants & sizes

    `variant` (`default` ghost | `outline` frame) and `size` (`tiny` |
    `default` | `sm` | `lg`) are declared on the group and shared with
    every item, like the source's React context; per-item `variant` /
    `size` attrs override the group's for that item alone. Items carry
    their treatment on `data-variant` / `data-size` attributes: the
    server-rendered markup uses the item's own attrs (defaulting to
    the base look), and the colocated hook applies the group's
    `variant` / `size` to items that did not lock their own — the
    context semantics without any class-string surgery.

  ## Keyboard

    **ArrowDown**/**ArrowRight** activate the next enabled item,
    **ArrowUp**/**ArrowLeft** the previous (wrapping),
    **Home**/**End** the first/last — automatic activation, like the
    source (focus and press move together). **Tab** enters the group
    at the single roving tab stop (the first active item, else the
    first enabled) and moves on. Items are real buttons, so
    **Enter**/**Space** toggle the focused item natively.

  ## Accessibility

    * The root is a `role="group"` landmark — name it with `aria-label`
      (\"Text alignment\"); items are `aria-pressed` buttons whose
      content gives them their accessible names.
    * One roving tab stop keeps keyboard users inside the group with
      arrow keys, exactly like the source; disabled items are dropped
      from the tab order and skipped by arrows (the Safari
      `tabindex="-1"` fix).
    * The on/off paint mirrors under `aria-[pressed=true]` too, so the
      styling follows the attribute alone.

  ## Microcopy

    Items are concise option words (\"Left\", \"Bold\", \"Active\"),
    consistent within a group — never mixed sentences and adjectives.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @types ~w(single multiple)
  @variants ~w(default outline)
  @sizes ~w(tiny default sm lg)

  # The group root shares one hook, one selection contract, and the
  # toggle item vocabulary; only the container differs from `toggle`.
  @hook "#{inspect(__MODULE__)}.Root"

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the group root — required because the colocated hook
    that owns selection anchors on it.
    """
  )

  attr(:type, :string,
    values: @types,
    default: "single",
    doc: """
    `single` keeps at most one active value (deactivatable, unlike
    radios); `multiple` toggles a free set of values.
    """
  )

  attr(:value, :any,
    default: nil,
    doc: """
    Initial selection — the item(s) whose `value` matches. A string for
    `single`, a list of strings for `multiple`. The hook owns selection
    from mount on.
    """
  )

  attr(:variant, :string,
    values: @variants,
    default: "default",
    doc: "Shared with every item (the source's React context); per-item `variant` overrides."
  )

  attr(:size, :string,
    values: @sizes,
    default: "default",
    doc: "Shared with every item (the source's React context); per-item `size` overrides."
  )

  attr(:on_change, :string,
    default: nil,
    doc: """
    Optional LiveView event pushed on every activation —
    `%{"value" => value}` for `single` (`nil` when cleared),
    `%{"value" => [values]}` for `multiple`.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the group.")

  attr(:rest, :global,
    doc: """
    Forwarded to the group: `aria-label`, `data-*`, `phx-*`, …
    """
  )

  slot(:inner_block, required: true, doc: "The `toggle_group_item`s.")

  def toggle_group(assigns) do
    validate_in!(:type, assigns.type, @types)
    validate_in!(:variant, assigns.variant, @variants)
    validate_in!(:size, assigns.size, @sizes)

    seed_values =
      case assigns.value do
        nil -> []
        values when is_list(values) -> Enum.map(values, &to_string/1)
        value -> [to_string(value)]
      end

    assigns =
      assign(assigns,
        hook: @hook,
        data_value: if(seed_values == [], do: nil, else: Enum.join(seed_values, ","))
      )

    ~H"""
    <div
      id={@id}
      role="group"
      data-polaris-toggle-group
      data-type={@type}
      data-value={@data_value}
      data-variant={@variant}
      data-size={@size}
      data-change-event={@on_change}
      class={cn(["flex items-center justify-center gap-1", @class])}
      phx-hook={@hook}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el
          this._items = () => Array.from(root.querySelectorAll("[data-polaris-toggle-group-item]"))
          this._enabled = () => this._items().filter((el) => el.dataset.disabled !== "true")
          this._multiple = () => root.dataset.type === "multiple"

          // Per-item data-checked wins (it also paints the SSR markup);
          // fall back to the root's comma-joined value seed. Single keeps one.
          const checked = this._items().filter((el) => el.dataset.checked === "true").map((el) => el.dataset.value)
          const seeded = checked.length ? checked : (root.dataset.value || "").split(",").filter(Boolean)
          this._values = this._multiple() ? seeded : seeded.slice(0, 1)

          // Toggle semantics, not radios: items activate AND deactivate;
          // roving tabindex keeps one tab stop (first on, else first enabled).
          this._apply = () => {
            const enabled = this._enabled()
            const tabstop = enabled.find((el) => this._values.indexOf(el.dataset.value) !== -1) || enabled[0]
            this._items().forEach((el) => {
              const on = this._values.indexOf(el.dataset.value) !== -1
              el.dataset.state = on ? "on" : "off"
              el.setAttribute("aria-pressed", on ? "true" : "false")
              el.tabIndex = el === tabstop ? 0 : -1
              // Share the group's variant/size with items that don't lock their own.
              if (!el.dataset.variantLocked) el.dataset.variant = root.dataset.variant || "default"
              if (!el.dataset.sizeLocked) el.dataset.size = root.dataset.size || "default"
            })
          }

          this._activate = (item) => {
            if (!item || item.dataset.disabled === "true") return
            const value = item.dataset.value
            const on = this._values.indexOf(value) !== -1
            if (this._multiple()) {
              this._values = on ? this._values.filter((v) => v !== value) : this._values.concat([value])
            } else {
              // Like Radix toggles, clicking the active item deactivates it.
              this._values = on ? [] : [value]
            }
            this._apply()
            const name = root.dataset.changeEvent
            if (name && typeof this.pushEvent === "function") {
              this.pushEvent(name, this._multiple() ? { value: this._values } : { value: this._values[0] || null })
            }
          }

          // Delegated on the root, so LiveView morphs never orphan it;
          // buttons fire click for pointer, Enter, and Space alike.
          this._onClick = (event) => {
            const item = event.target.closest("[data-polaris-toggle-group-item]")
            if (item && root.contains(item)) this._activate(item)
          }
          root.addEventListener("click", this._onClick)

          this._onKeydown = (event) => {
            const item = event.target.closest("[data-polaris-toggle-group-item]")
            if (!item || !root.contains(item)) return
            const enabled = this._enabled()
            if (!enabled.length) return
            const index = enabled.indexOf(item)
            const move = (i) => {
              event.preventDefault()
              const next = enabled[i]
              this._activate(next)
              next.focus()
            }
            if (event.key === "ArrowDown" || event.key === "ArrowRight") {
              move((index + 1) % enabled.length)
            } else if (event.key === "ArrowUp" || event.key === "ArrowLeft") {
              move((index - 1 + enabled.length) % enabled.length)
            } else if (event.key === "Home") {
              move(0)
            } else if (event.key === "End") {
              move(enabled.length - 1)
            }
          }
          root.addEventListener("keydown", this._onKeydown)

          this._apply()
        },
        updated() {
          // LiveView patches may stomp data-state/aria/tabindex; re-apply.
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
  One toggle of the group — the source's ToggleGroupItem: a real
  `aria-pressed` button with the `toggle`'s class vocabulary. The
  group's `variant`/`size` apply unless this item's own override them.
  """
  attr(:value, :string,
    required: true,
    doc: "The value this item toggles (unique in the group) — the `on_change` payload key."
  )

  attr(:checked, :boolean,
    default: false,
    doc: "Initial on paint (the hook seeds from it and owns selection from mount on)."
  )

  attr(:variant, :string,
    default: nil,
    doc: "Per-item override of the group's `variant` (\"default\" | \"outline\")."
  )

  attr(:size, :string,
    default: nil,
    doc: "Per-item override of the group's `size` (\"tiny\" | \"default\" | \"sm\" | \"lg\")."
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Locks the item, dims it, and drops it from the tab order."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the item (e.g. `font-mono`)."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the item button: `aria-label`, `aria-describedby`,
    `data-*`, `phx-*`, …
    """
  )

  slot(:inner_block,
    required: true,
    doc: "The item's content — a concise option word (\"Left\"), an icon, or both."
  )

  def toggle_group_item(assigns) do
    if assigns.variant, do: validate_in!(:variant, assigns.variant, @variants)
    if assigns.size, do: validate_in!(:size, assigns.size, @sizes)

    assigns =
      assign(assigns,
        state: if(assigns.checked, do: "on", else: "off"),
        variant: assigns.variant || "default",
        size: assigns.size || "default",
        variant_locked: not is_nil(assigns.variant),
        size_locked: not is_nil(assigns.size)
      )

    ~H"""
    <button
      type="button"
      aria-pressed={to_string(@checked)}
      data-polaris-toggle-group-item
      data-value={@value}
      data-state={@state}
      data-checked={to_string(@checked)}
      data-disabled={to_string(@disabled)}
      data-variant={@variant}
      data-size={@size}
      data-variant-locked={if(@variant_locked, do: "true")}
      data-size-locked={if(@size_locked, do: "true")}
      disabled={@disabled}
      tabindex={if(@checked, do: "0", else: "-1")}
      class={cn([item_base_classes(), @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  # The source's toggleVariants, as carried by `toggle` — duplicated here
  # because each Polaris module is copy-injected standalone by
  # `mix polaris.add` and must not import its siblings. The default
  # treatment and size render ungated; non-default variants/sizes gate on
  # the item's own data-variant/data-size so the group's shared values can
  # flow in through the hook (see "Variants & sizes").
  defp item_base_classes do
    [
      "inline-flex items-center justify-center gap-1 rounded-md text-sm font-medium",
      "transition-colors text-content-secondary hover:text-content-primary hover:bg-surface-muted",
      "bg-transparent py-1 h-10 px-3",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
      "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
      "disabled:pointer-events-none disabled:opacity-50",
      "data-[state=on]:bg-surface-muted data-[state=on]:text-content-primary",
      "aria-[pressed=true]:bg-surface-muted aria-[pressed=true]:text-content-primary",
      "data-[variant=outline]:border data-[variant=outline]:border-surface-border",
      "data-[variant=outline]:data-[state=on]:border-surface-border-hover",
      "data-[variant=outline]:aria-[pressed=true]:border-surface-border-hover",
      "data-[size=tiny]:h-[26px] data-[size=tiny]:px-2.5 data-[size=tiny]:text-xs",
      "data-[size=sm]:h-[34px] data-[size=sm]:px-2.5",
      "data-[size=lg]:h-11 data-[size=lg]:px-5"
    ]
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
