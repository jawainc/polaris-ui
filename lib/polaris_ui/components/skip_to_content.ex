defmodule PolarisUI.Components.SkipToContent do
  @moduledoc """
  Port of the Supabase skip-link fragment (`ui-patterns/SkipToContent`): a
  keyboard-accessible skip link that stays fully off-screen until focused via
  Tab, then slides into view — pure CSS, no hook.

  ## Anatomy

      <.skip_to_content href="#main" />

  Renders a fixed positioning wrapper carrying the reveal mechanics, with a
  tiny default button rendered as an anchor (the LiveView equivalent of the
  React fragment's `asChild` anchor):

      <div class="fixed top-0 left-[10px] z-[100] w-fit
                  -translate-y-full focus-within:translate-y-[10px]
                  transition-transform duration-200 ease-out">
        <a href="#main" class="...tiny default button...">Skip to content</a>
      </div>

  ## The landmark target contract

  Callers own the landmark the link targets. It must carry:

    * a matching `id` — the hash href resolves to it;
    * `tabindex="-1"` — so activating the link moves focus onto the landmark
      itself, not just scrolls to it;
    * `outline-none` — the landmark must not show a visible focus ring; the
      next Tab lands on its first interactive child;
    * `scroll-mt-*` when a sticky header would otherwise cover the landmark
      after the jump.

      <.skip_to_content href="#main" />
      <main id="main" tabindex="-1" class="outline-none scroll-mt-24">
        {@children}
      </main>

  ## States

    * **rest** — translated fully off-screen (`-translate-y-full`): invisible
      to pointer users but still the first stop in the tab order.
    * **focused** — `focus-within:translate-y-[10px]` slides the link into
      view just below the top edge, animated by
      `transition-transform duration-200 ease-out`.

  ## Accessibility

  The link is a real focusable anchor, not a visual shim: place it at the
  root of the app chrome so Tab reaches it before navigation. The reveal is
  pure CSS (`focus-within:`), so it works with keyboard navigation, assistive
  technology, and JS disabled alike. Keep only content inside the target
  landmark — a skip into a `<main>` that also holds the sidebar would land
  the next Tab back in sidebar navigation.
  """

  use PolarisUI.Component
  import PolarisUI.Components.Button, only: [button: 1]

  attr(:href, :string,
    required: true,
    doc: """
    Hash href to the main content landmark, e.g. `"#main"`. The target must
    satisfy the landmark target contract described in the moduledoc.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the positioning wrapper (useful for demos
    or layout overrides) — caller classes win conflicts via `cn/1`.
    """
  )

  attr(:rest, :global,
    doc: "Forwarded to the positioning wrapper: `data-*`, `aria-*`, `phx-*`, …"
  )

  slot(:inner_block,
    doc: """
    Link label. Falls back to `"Skip to content"` when the do-block is absent
    or blank.
    """
  )

  def skip_to_content(assigns) do
    # LV creates an inner_block even when no do-block is given, so
    # blank-render is the reliable signal for the default label.
    label? = slot_content?(assigns.inner_block, assigns)

    assigns =
      assign(assigns,
        classes:
          cn([
            # w-fit: the wrapper is a block div by default and would otherwise
            # span the full content column — a skip link should hug its label.
            "fixed top-0 left-[10px] z-[100] w-fit",
            "-translate-y-full focus-within:translate-y-[10px]",
            "transition-transform duration-200 ease-out",
            assigns.class
          ]),
        label?: label?
      )

    ~H"""
    <div class={@classes} data-polaris-skip {@rest}>
      <.button size="tiny" variant="default" href={@href}>
        <%= if @label? do %>
          {render_slot(@inner_block)}
        <% else %>
          Skip to content
        <% end %>
      </.button>
    </div>
    """
  end
end
