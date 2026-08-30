defmodule PolarisUI.Components.Input do
  @moduledoc """
  The Polaris input: the single-line text field — the port of the
  Supabase design system Input (`packages/ui`, `input.tsx`), the
  shadcn-style input over Supabase's semantic tokens (here mapped to
  the Polaris palette: `bg-field` → `bg-surface-panel`,
  `border-control` → `border-surface-border`, destructive → danger).

  ## Anatomy

      <.label for="email">Email</.label>
      <.input id="email" type="email" name="email" placeholder="Email" />

  A plain `<input>` — the source wraps no primitive. The treatment: a
  bordered panel fill that brightens on hover, the emerald focus ring
  on keyboard focus (`focus-visible`), muted placeholder and disabled
  text, and the danger tint keyed off `aria-invalid="true"` (pass it
  through global attributes from your validation layer).

  ## Sizes

  The source's shared size scale (`SIZE_VARIANTS`, default `small`) —
  heights from 26px (`tiny`) to 50px (`xlarge`):

  | Size | Height | Text | Padding |
  |------|--------|------|---------|
  | `tiny` | 26px | `text-xs` | `px-2.5 py-1` |
  | `small` (default) | 34px | `text-base md:text-sm leading-4` | `px-3 py-2` |
  | `medium` | 38px | `text-base md:text-sm` | `px-4 py-2` |
  | `large` | 42px | `text-base` | `px-4 py-2` |
  | `xlarge` | 50px | `text-base` | `px-6 py-3` |

  ## States

    * **rest** — bordered panel fill, rounded-md.
    * **hover** — the border brightens (`border-surface-border-hover`).
    * **focus** — the border brightens and the emerald ring appears on
      keyboard focus (`focus-visible:ring-2`, the source's `focus-ring`
      utility expanded).
    * **invalid** — pass `aria-invalid="true"`: danger border, danger
      tinted fill, danger border on hover/focus.
    * **read-only** — flat border, secondary text.
    * **disabled** — not-allowed cursor, muted text (the source dims
      text only; the fill keeps its contrast).
    * **loading** — `loading` locks the field (`aria-busy`, disabled)
      and overlays the brand spinner at the trailing edge.

  File inputs inherit `file:border-0 file:bg-transparent` so
  `type="file"` renders cleanly at any size.

  ## Accessibility

    * Always pair with `<.label for={@id}>` (or `aria-label` through
      global attributes) — the input itself carries no label.
    * Validation layers set `aria-invalid="true"`, which drives the
      danger treatment; announce the reason with `field_error`.

  ## Microcopy

  Placeholders phrase the intent ("Email"), not the mechanics ("Type
  your email address here").

  Purely presentational — no colocated hook; all state rides native
  input attributes.
  """

  use PolarisUI.Component

  @sizes ~w(tiny small medium large xlarge)

  # The source's SIZE_VARIANTS (packages/ui/src/lib/constants.ts):
  # text + padding + height per size.
  defp size_classes("tiny"), do: "text-xs px-2.5 py-1 h-[26px]"
  defp size_classes("small"), do: "text-base md:text-sm leading-4 px-3 py-2 h-[34px]"
  defp size_classes("medium"), do: "text-base md:text-sm px-4 py-2 h-[38px]"
  defp size_classes("large"), do: "text-base px-4 py-2 h-[42px]"
  defp size_classes("xlarge"), do: "text-base px-6 py-3 h-[50px]"

  @doc """
  Renders the input.
  """
  attr(:type, :string,
    default: "text",
    doc:
      "The input type — `text`, `email`, `password`, `file`, … (`file` gets the flat file-part treatment)."
  )

  attr(:name, :string, default: nil, doc: "The form field name.")

  attr(:value, :string, default: nil, doc: "The current value.")

  attr(:placeholder, :string,
    default: nil,
    doc: "The hint text — phrase the intent (\"Email\"), never the mechanics."
  )

  attr(:size, :string,
    values: @sizes,
    default: "small",
    doc: "The source's shared size scale — `small` is the default everywhere in Supabase."
  )

  attr(:disabled, :boolean, default: false, doc: "Blocks editing, keeps the fill, mutes text.")

  attr(:readonly, :boolean, default: false, doc: "Blocks editing, keeps full contrast.")

  attr(:loading, :boolean,
    default: false,
    doc: """
    Locks the field while work is in flight: disables it, sets
    `aria-busy`, and overlays the brand spinner at the trailing edge.
    """
  )

  attr(:class, :string,
    default: nil,
    doc: "Additional classes merged onto the input — where the source's `className` lands."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the `<input>`: `id`, `phx-change`, `phx-blur`,
    `aria-invalid`, `maxlength`, `data-*`, …
    """
  )

  def input(assigns) do
    validate_in!(:size, assigns.size, @sizes)

    assigns =
      assign(assigns,
        locked?: assigns.disabled or assigns.loading,
        input_classes:
          cn([
            "flex h-10 w-full rounded-md border border-surface-border bg-surface-panel",
            "px-3 py-2 text-sm text-content-primary",
            "file:border-0 file:bg-transparent file:text-sm file:font-medium",
            "placeholder:text-content-muted",
            "transition-colors duration-200",
            "hover:border-surface-border-hover",
            "read-only:border-surface-border read-only:text-content-secondary",
            "focus:border-surface-border-hover focus:outline-none",
            "focus-visible:ring-2 focus-visible:ring-brand-emerald",
            "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground",
            "disabled:cursor-not-allowed disabled:text-content-muted",
            "aria-[invalid=true]:bg-danger-muted aria-[invalid=true]:border-danger-border",
            "aria-[invalid=true]:hover:border-danger aria-[invalid=true]:focus:border-danger",
            "aria-[invalid=true]:focus-visible:border-danger",
            size_classes(assigns.size),
            if(assigns.loading, do: "pr-9"),
            assigns.class
          ])
      )

    ~H"""
    <%= if @loading do %>
      <div data-polaris-input-loading class="relative w-full">
        <input
          data-polaris-input
          type={@type}
          name={@name}
          value={@value}
          placeholder={@placeholder}
          disabled
          readonly={@readonly}
          aria-busy="true"
          class={@input_classes}
          {@rest}
        />
        <svg
          data-polaris-input-spinner
          class="absolute right-3 top-1/2 size-4 -translate-y-1/2 animate-spin text-brand-accent"
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
      <input
        data-polaris-input
        type={@type}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        disabled={@locked?}
        readonly={@readonly}
        class={@input_classes}
        {@rest}
      />
    <% end %>
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
