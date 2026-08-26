defmodule PolarisUI.Components.ExpandingTextarea do
  @moduledoc """
  The Polaris expanding textarea: a textarea that grows (and shrinks)
  with its content — the port of the Supabase design system
  ExpandingTextArea (`packages/ui`), the chat-style input that starts
  at single-line input height and expands as the text wraps.

  ## How it grows

  The colocated hook applies the source's measurement loop: reset
  `height` to `auto`, read `scrollHeight`, then set
  `height = max(40, scrollHeight)px` — the 40px floor matching the
  single-line input height (`h-10`) so one row of text renders exactly
  like an input. There is no maximum cap: the field grows unbounded,
  like the source. The hook re-measures on every LiveView patch (the
  value is server-driven) *and* through a `ResizeObserver`, because a
  measurement taken right after mount can catch the element mid-layout
  (e.g. while an ancestor panel is still settling its width) and bake
  in a wrong height — the exact bug the source's observer comments on.

  ## Anatomy

      <.expanding_textarea
        id="message"
        name="message"
        value={@message}
        placeholder="Type your message in multiple lines here."
        phx-change="update-message"
      />

  The textarea itself carries the source's surface treatment (the
  shadcn Textarea base over Polaris tokens): the bordered panel fill,
  the border that brightens on hover and on the emerald focus ring,
  and the invalid treatment (`aria-invalid="true"` tints the border
  and fill danger-red — pass it through global attributes from your
  validation layer).

  ## Controlled value

  `value` is required — the source is controlled-only, and the height
  recalculation keys off it. Drive it from your `phx-change` handler
  like any LiveView input.

  ## Accessibility

    * A real `<label>` (or `aria-label` through global attributes)
      should name the field — pass the matching `id`.
    * The element carries the source's static `aria-expanded="false"`
      and `rows="1"`.
    * Keyboard, selection, and IME behavior are native textarea
      behavior — the hook never touches focus or keys, only height.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the textarea — required because the colocated hook
    that owns the height anchors on it, and the label wiring target.
    """
  )

  attr(:value, :string,
    required: true,
    doc: """
    The current text — controlled-only (the source requires it): the
    height recalculation keys off every value change.
    """
  )

  attr(:name, :string, default: nil, doc: "The form field name.")

  attr(:placeholder, :string,
    default: nil,
    doc: "The hint text — phrase the intent (\"Type your message in multiple lines here.\")."
  )

  attr(:disabled, :boolean, default: false, doc: "Blocks editing and dims the field.")

  attr(:readonly, :boolean, default: false, doc: "Blocks editing, keeps full contrast.")

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the textarea — where the source's
    `className` lands.
    """
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the `<textarea>`: `phx-change`, `phx-blur`, `phx-focus`,
    `aria-invalid`, `maxlength`, `data-*`, …
    """
  )

  def expanding_textarea(assigns) do
    assigns =
      assign(assigns,
        hook: "#{inspect(__MODULE__)}.Root",
        textarea_classes:
          cn([
            "flex min-h-10 w-full resize-none rounded-md border border-surface-border",
            "bg-surface-panel px-3 py-2 text-base md:text-sm text-content-primary",
            "placeholder:text-content-muted",
            "transition-colors duration-200",
            "hover:border-surface-border-hover",
            "focus:border-surface-border-hover focus-visible:border-surface-border-hover",
            "focus:outline-none focus:ring-2 focus:ring-brand-emerald",
            "focus:ring-offset-2 focus:ring-offset-surface-ground",
            "aria-[invalid=true]:border-danger-border aria-[invalid=true]:bg-danger-muted",
            "aria-[invalid=true]:hover:border-danger",
            "disabled:cursor-not-allowed disabled:opacity-50",
            "box-border",
            assigns.class
          ])
      )

    ~H"""
    <textarea
      id={@id}
      data-polaris-expanding-textarea
      name={@name}
      rows="1"
      aria-expanded="false"
      placeholder={@placeholder}
      disabled={@disabled}
      readonly={@readonly}
      phx-hook={@hook}
      class={@textarea_classes}
      {@rest}
    ><%= @value %></textarea>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          this._measure = () => {
            const el = this.el
            // The source's single-line floor (h-10 = 40px): never shrink
            // below input height; grow only when content wraps.
            const singleLineHeightPx = 40
            el.style.height = "auto"
            const contentHeight = el.scrollHeight
            const target = Math.max(singleLineHeightPx, contentHeight) + "px"
            if (el.style.height !== target) {
              el.style.height = target
            }
          }
          this._measure()
          // Re-measure whenever the element's own box changes size — a
          // mount-time measurement can catch it mid-layout inside a
          // settling ancestor and bake in a wrong height.
          this._observer = new ResizeObserver(() => this._measure())
          this._observer.observe(this.el)
        },
        updated() {
          this._measure()
        },
        destroyed() {
          if (this._observer) {
            this._observer.disconnect()
            this._observer = null
          }
        }
      }
    </script>
    """
  end
end
