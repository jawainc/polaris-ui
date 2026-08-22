defmodule PolarisUI.Components.ErrorDisplay do
  @moduledoc """
  The Polaris error display: a card for surfacing API errors inline — a
  warning-toned header, a monospace error message block, an optional
  troubleshooting body, and an always-present "Contact support" footer
  link.

  Port of the Supabase design system fragment
  `ui-patterns/ErrorDisplay/ErrorDisplay` (a presentation component built
  on their `Card`): use it as the base for any inline error state in a
  dashboard — classification and troubleshooting wiring live with the
  caller, exactly like the Supabase `ErrorMatcher` composition.

  ## Anatomy

      <.error_display
        id="tables-error"
        title="Failed to load tables"
        error_message="ERROR: CONNECTION TERMINATED DUE TO CONNECTION TIMEOUT."
        support_form_params={%{project_ref: @project.ref}}
      />

    * **header** — an amber warning badge (filled triangle glyph) next to
      the `title`, rendered as an `<h3>` over a bottom hairline.
    * **message block** — the `error_message` in a `<pre>`: monospaced,
      amber on a muted amber tint, wrapped (never clipped) with
      `whitespace-pre-wrap`, capped at `max-h-32` with `overflow-auto`.
    * **inner block** — optional inline troubleshooting content (in the
      Supabase dashboard typically a troubleshooting accordion), rendered
      verbatim between the message and the footer.
    * **footer** — a help glyph, the hardcoded "Need help?" span, and the
      `support_label` link opening in a new tab. The footer is always
      rendered — there is no "hide support" option, matching the fragment.

  ## Warning tones on purpose

  The fragment deliberately uses the amber/warning palette even though it
  displays errors — the red "destructive" treatment is reserved for
  confirmation dialogs. Keep the amber for fidelity.

  ## Support URL

  `support_url` defaults to `/support/new`. A `support_form_params` map is
  encoded into the query string, skipping `nil` and empty values — pass
  keys like `project_ref`, `org_slug`, `category`, `subject`, `message`,
  `error`, or `sid` (a Sentry event id), mirroring the fragment's
  `SupportFormParams`.

  ## Events

    * `on_render` — a LiveView event name pushed once when the component
      mounts (the React `onRender` telemetry callback); handled by a
      colocated runtime hook, attached only when the event is set.
    * `on_support_click` — a LiveView event name fired when the support
      link is clicked; the browser still follows the link (no
      `preventDefault`), exactly like the React `onSupportClick`.

  ## States

  The root is a passive `role="alert"` region — like the admonition, it is
  not a control, so it deliberately has no hover, active, loading, or
  disabled affordances of its own. The interactive states that do exist
  live on the footer link: rest, hover (brightens to the secondary tone),
  and `:focus-visible` (the shared emerald ring). Slotted troubleshooting
  controls bring their own full state machines.

  ## Accessibility

    * The root renders `role="alert"` (assertive announcement) and
      `aria-labelledby` wired to the title id — derived from `id` as
      `"<id>-title"`, so multiple error displays on one page keep unique
      ids (improving on the fragment's hardcoded id).
    * The badge glyph and footer help glyph are `aria-hidden`
      decoration; the title text carries the semantics.

  ## Microcopy

  Per the Supabase copywriting guidelines: phrase the title as the failed
  action ("Failed to load tables"), keep the raw error message verbatim
  in the block, and always override `support_label` with the specific
  escalation verb when one exists.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the card root — the title id derives from it as
    `"<id>-title"` (wired to `aria-labelledby`), and the `on_render`
    colocated hook anchors on it.
    """
  )

  attr(:title, :string,
    required: true,
    doc: "Header heading — phrase it as the action that failed (\"Failed to load tables\")."
  )

  attr(:error_message, :string,
    required: true,
    doc: """
    The raw error text displayed verbatim in the monospace block — keep it
    unedited so it matches server logs.
    """
  )

  attr(:support_form_params, :map,
    default: nil,
    doc: """
    Map encoded into the support URL query string (`nil`/empty values
    skipped) — e.g. `%{project_ref: "my-project", category: "dashboard"}`.
    """
  )

  attr(:support_url, :string,
    default: "/support/new",
    doc: "Base URL the support link points at (query params appended when present)."
  )

  attr(:support_label, :string,
    default: "Contact support",
    doc: "Support link text — override with the specific escalation verb when one exists."
  )

  attr(:on_render, :string,
    default: nil,
    doc: "LiveView event pushed once on mount (telemetry — the React `onRender`)."
  )

  attr(:on_support_click, :string,
    default: nil,
    doc: "LiveView event fired when the support link is clicked (the link still navigates)."
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the card root — caller classes win via `cn/1`."
  )

  attr(:rest, :global, doc: "Forwarded to the root `<div>`: `data-*`, `phx-*`, …")

  slot(:icon,
    doc: """
    Custom header icon (inline SVG), rendered inside the amber badge
    instead of the default filled warning triangle.
    """
  )

  slot(:inner_block,
    doc: """
    Optional troubleshooting content rendered between the message block
    and the support footer — typically a disclosure of next steps.
    """
  )

  def error_display(assigns) do
    # LV creates an inner_block even when the do-block is empty, so
    # blank-render is the reliable signal for the body section.
    has_body? = slot_content?(assigns.inner_block, assigns)

    assigns =
      assigns
      |> assign(
        hook: "#{inspect(__MODULE__)}.Render",
        has_body?: has_body?,
        support_href: build_support_url(assigns.support_url, assigns.support_form_params),
        root_classes:
          cn([
            "overflow-hidden rounded-lg border border-surface-border",
            "bg-surface-panel text-content-primary shadow-xs",
            assigns.class
          ])
      )

    ~H"""
    <div
      id={@id}
      role="alert"
      aria-labelledby={"#{@id}-title"}
      class={@root_classes}
      data-polaris-error-display
      phx-hook={@on_render && @hook}
      data-render-event={@on_render}
      {@rest}
    >
      <div
        class="flex flex-row items-center gap-2.5 border-b border-surface-border p-3"
        data-polaris-error-display-header
      >
        <div class="rounded-md bg-warning p-1 text-surface-ground" data-polaris-error-display-badge>
          <%= if @icon != [] do %>
            {render_slot(@icon)}
          <% else %>
            <.warning_glyph />
          <% end %>
        </div>
        <h3
          id={"#{@id}-title"}
          class="mt-0 text-sm text-content-primary"
          data-polaris-error-display-title
        >
          {@title}
        </h3>
      </div>
      <div
        class="border-y border-warning bg-warning-muted px-4 py-3"
        data-polaris-error-display-message
      >
        <pre
          class="max-h-32 overflow-auto whitespace-pre-wrap break-words font-mono text-xs text-warning"
          data-polaris-error-display-pre
        >{@error_message}</pre>
      </div>
      <div :if={@has_body?} data-polaris-error-display-body>{render_slot(@inner_block)}</div>
      <div
        class="flex items-center gap-2 border-t border-surface-border px-3 py-2"
        data-polaris-error-display-footer
      >
        <div class="shrink-0 text-content-muted" data-polaris-error-display-help>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-4"
            aria-hidden="true"
          >
            <circle cx="12" cy="12" r="10" />
            <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
            <path d="M12 17h.01" />
          </svg>
        </div>
        <span class="text-sm text-content-secondary">Need help?</span>
        <a
          href={@support_href}
          target="_blank"
          rel="noopener noreferrer"
          phx-click={@on_support_click}
          class={
            cn([
              "shrink-0 text-sm text-content-primary underline transition-colors",
              "hover:text-content-secondary",
              "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
              "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
            ])
          }
          data-polaris-error-display-support
        >
          {@support_label}
        </a>
      </div>
    </div>
    <script :if={@on_render} :type={Phoenix.LiveView.ColocatedHook} name=".Render" runtime>
      {
        mounted() {
          // Fire exactly once per mount (the React useRef guard equivalent).
          const evt = this.el.dataset.renderEvent
          if (evt && typeof this.pushEvent === "function") {
            this.pushEvent(evt)
          }
        }
      }
    </script>
    """
  end

  # Mirrors the fragment's buildSupportUrl: params with nil/"" values are
  # dropped; an empty result keeps the bare base URL.
  defp build_support_url(base, params) when is_map(params) and params != %{} do
    query =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()
      |> URI.encode_query()

    if query == "", do: base, else: "#{base}?#{query}"
  end

  defp build_support_url(base, _params), do: base

  # The filled warning triangle from the Supabase AdmonitionIcons
  # (viewBox 0 0 22 20), sized to the badge like the fragment's w-3 h-3.
  defp warning_glyph(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 22 20"
      fill="currentColor"
      class="size-3"
      aria-hidden="true"
    >
      <path
        fill-rule="evenodd"
        clip-rule="evenodd"
        d="M8.15137 1.95117C9.30615 -0.0488281 12.1943 -0.0488281 13.3481 1.95117L20.7031 14.6992C21.8574 16.6992 20.4131 19.1992 18.104 19.1992H3.39502C1.08594 19.1992 -0.356933 16.6992 0.797364 14.6992L8.15137 1.95117ZM11.7666 16.0083C11.4971 16.2778 11.1313 16.4292 10.75 16.4292C10.3687 16.4292 10.0029 16.2778 9.7334 16.0083C9.46387 15.7388 9.3125 15.373 9.3125 14.9917C9.3125 14.9307 9.31641 14.8706 9.32373 14.811C9.33545 14.7197 9.35547 14.6304 9.38379 14.5439L9.41406 14.4609C9.48584 14.2803 9.59375 14.1147 9.7334 13.9751C10.0029 13.7056 10.3687 13.5542 10.75 13.5542C11.1313 13.5546 11.4971 13.7056 11.7666 13.9751C12.0366 14.2446 12.1875 14.6104 12.1875 14.9917C12.1875 15.373 12.0366 15.7388 11.7666 16.0083ZM10.75 4.69971C11.0317 4.69971 11.3022 4.81152 11.5015 5.01074C11.7007 5.20996 11.8125 5.48047 11.8125 5.76221V11.0747C11.8125 11.3564 11.7007 11.627 11.5015 11.8262C11.3022 12.0254 11.0317 12.1372 10.75 12.1372C10.4683 12.1372 10.1978 12.0254 9.99854 11.8262C9.79932 11.627 9.6875 11.3564 9.6875 11.0747V5.76221C9.6875 5.48047 9.79932 5.20996 9.99854 5.01074C10.1978 4.81152 10.4683 4.69971 10.75 4.69971Z"
      />
    </svg>
    """
  end
end
