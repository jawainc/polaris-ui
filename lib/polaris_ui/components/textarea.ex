defmodule PolarisUI.Components.Textarea do
  @moduledoc """
  The Polaris textarea: the multi-line text field — the port of the
  Supabase design system Textarea (`packages/ui`, `textarea.tsx`), the
  shadcn-style textarea over Supabase's semantic tokens (here mapped
  to the Polaris palette: `bg-field` → `bg-surface-panel`,
  `border-control` → `border-surface-border`, destructive → danger).

  The multi-line sibling of `input` — it ports the same source family
  and mirrors its conventions. For the chat-style input that grows
  with its content, see `expanding_textarea` instead.

  ## Anatomy

      <.label for="bio">Biography</.label>
      <.textarea id="bio" name="bio" placeholder="Add a description" />

  A plain `<textarea>` — the source wraps no primitive and ships no
  size scale (unlike `input`). The treatment: the bordered panel fill
  with the source's 80px height floor, the border that brightens on
  hover and focus, the emerald focus ring on keyboard focus, the
  muted placeholder, and the danger tint keyed off
  `aria-invalid="true"` (pass it through global attributes from your
  validation layer).

  ## States

    * **rest** — bordered panel fill, rounded-md, `min-h-[80px]` floor.
    * **hover** — the border brightens (`border-surface-border-hover`).
    * **focus** — the border brightens and the emerald ring appears
      on keyboard focus (`focus-visible`, the source's `focus-ring`
      utility expanded).
    * **invalid** — pass `aria-invalid="true"`: danger border, danger
      tinted fill, danger border on hover/focus.
    * **read-only** — flat border, secondary text, full contrast.
    * **disabled** — not-allowed cursor and the whole field at half
      opacity (the source dims the field itself; `input` mutes text
      only — each follows its own source).
    * **loading** — `loading` locks the field (`aria-busy`, disabled)
      and overlays the brand spinner pinned to the top-right corner
      (the field is tall; `input` centers it on the trailing edge).

  ## Accessibility

    * Always pair with `<.label for={@id}>` (or `aria-label` through
      global attributes) — the textarea itself carries no label.
    * Validation layers set `aria-invalid="true"`, which drives the
      danger treatment; announce the reason with `field_error`.

  ## Microcopy

  Placeholders phrase the intent ("Add a description"), not the
  mechanics ("Type a few sentences about yourself here").

  Purely presentational — no colocated hook; all state rides native
  textarea attributes.
  """

  use PolarisUI.Component

  @doc """
  Renders the textarea.
  """
  attr(:name, :string, default: nil, doc: "The form field name.")

  attr(:value, :string,
    default: nil,
    doc: "The current text — rendered as the textarea's content."
  )

  attr(:placeholder, :string,
    default: nil,
    doc: "The hint text — phrase the intent (\"Add a description\"), never the mechanics."
  )

  attr(:rows, :integer,
    default: nil,
    doc: """
    Rows height hint. `nil` (the default) lets the browser default
    (2 rows in most) apply on top of the source's `min-h-[80px]` floor.
    """
  )

  attr(:disabled, :boolean,
    default: false,
    doc: "Blocks editing and dims the whole field to half opacity."
  )

  attr(:readonly, :boolean, default: false, doc: "Blocks editing, keeps full contrast.")

  attr(:loading, :boolean,
    default: false,
    doc: """
    Locks the field while work is in flight: disables it, sets
    `aria-busy`, and overlays the brand spinner at the top-right
    corner.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the textarea — where the source's `className` lands."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the `<textarea>`: `id`, `phx-change`, `phx-blur`,
    `phx-focus`, `aria-invalid`, `maxlength`, `data-*`, …
    """
  )

  def textarea(assigns) do
    assigns =
      assign(assigns,
        locked?: assigns.disabled or assigns.loading,
        textarea_classes:
          cn([
            "flex min-h-[80px] w-full rounded-md border border-surface-border bg-surface-panel",
            "px-3 py-2 text-base md:text-sm text-content-primary",
            "placeholder:text-content-muted",
            "transition-colors duration-200",
            "hover:border-surface-border-hover",
            "focus:border-surface-border-hover focus:outline-none",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "read-only:border-surface-border read-only:text-content-secondary",
            "disabled:cursor-not-allowed disabled:opacity-50",
            "aria-[invalid=true]:bg-danger-muted aria-[invalid=true]:border-danger-border",
            "aria-[invalid=true]:hover:border-danger aria-[invalid=true]:focus:border-danger",
            "aria-[invalid=true]:focus-visible:border-danger",
            if(assigns.loading, do: "pr-9"),
            assigns.class
          ])
      )

    ~H"""
    <%= if @loading do %>
      <div data-polaris-textarea-loading class="relative w-full">
        <textarea
          data-polaris-textarea
          name={@name}
          placeholder={@placeholder}
          rows={@rows}
          disabled
          readonly={@readonly}
          aria-busy="true"
          class={@textarea_classes}
          {@rest}
        ><%= @value %></textarea>
        <svg
          data-polaris-textarea-spinner
          class="absolute right-3 top-3 size-4 animate-spin text-brand-accent"
          viewBox="0 0 24 24"
          fill="none"
          aria-hidden="true"
        >
          <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" opacity="0.2" />
          <path
            d="M22 12a10 10 0 0 0-10-10"
            stroke="currentColor"
            stroke-width="3"
            stroke-linecap="round"
          />
        </svg>
      </div>
    <% else %>
      <textarea
        data-polaris-textarea
        name={@name}
        placeholder={@placeholder}
        rows={@rows}
        disabled={@locked?}
        readonly={@readonly}
        class={@textarea_classes}
        {@rest}
      ><%= @value %></textarea>
    <% end %>
    """
  end
end
