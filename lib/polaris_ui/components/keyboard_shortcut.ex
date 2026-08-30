defmodule PolarisUI.Components.KeyboardShortcut do
  @moduledoc """
  The Polaris keyboard shortcut: a compact, platform-aware shortcut
  label — the port of the Supabase design system KeyboardShortcut
  (`packages/ui`, `KeyboardShortcut.tsx`).

  Renders logical key names (`Meta`, `ArrowUp`, `K`) as display glyphs
  (`⌘↑`, `⌘K`) in one flat `<span>` — combos are joined into a single
  label: every resolved key a single character joins compactly (`⌘K`,
  `⇧⌘M`), otherwise spaced (`Ctrl ↑`, `Ctrl K`). Single characters are
  uppercased automatically.

  ## Platform awareness

  `Meta` and `Alt` resolve per platform — `⌘`/`⌥` on Mac, `Ctrl`/`Alt`
  elsewhere. The source resolves client-side; the port renders the Mac
  glyphs server-side (deterministic HTML) and ships both resolved
  labels (`data-resolved` / `data-alt`) with a tiny runtime hook that
  swaps in the non-Mac label on mount when the visitor isn't on a Mac.
  Pass `platform` explicitly (`"mac"` / `"other"`) to pin the glyphs
  and skip the hook entirely — useful in emails or static pages.

  ## Variants

    * **`pill`** (default) — the bordered chip for menus, tooltips,
      and standalone shortcut rows.
    * **`inline`** — the quiet text-scale treatment for helper copy and
      button accessory slots ("Hit ⌘K to open search").

  ## Anatomy

      <.keyboard_shortcut keys={["Meta", "K"]} />
      <.keyboard_shortcut keys={["Meta", "Enter"]} variant="inline" />

  ## Where it fits

  For right-aligned glyphs inside menu items, the menu families ship
  their own `*_shortcut` pieces (the shadcn `ml-auto tracking-widest`
  treatment) — this component is for everywhere else.

  No hover/focus/disabled states — the pill's only stateful styling is
  its surface tint, which tracks the Polaris palette (dark-first, flips
  under `polaris-light`).
  """

  use PolarisUI.Component

  @variants ~w(pill inline)
  @platforms ~w(mac other)

  # The source's KEY_SYMBOLS — platform-static glyphs. `Meta`/`Alt` are
  # platform-aware and resolved in resolve_key/2.
  @key_symbols %{
    "Shift" => "⇧",
    "Enter" => "↵",
    "ArrowUp" => "↑",
    "ArrowDown" => "↓",
    "ArrowLeft" => "←",
    "ArrowRight" => "→",
    "Esc" => "Esc",
    "Escape" => "Esc",
    "Tab" => "Tab"
  }

  @doc """
  Renders the shortcut label from logical key names.
  """
  attr(:keys, :list,
    required: true,
    doc: """
    Ordered logical key names — `Meta`, `Alt`, `Shift`, `Enter`, `Esc`/
    `Escape`, `Tab`, `ArrowUp`/`ArrowDown`/`ArrowLeft`/`ArrowRight`,
    or any single character (uppercased automatically).
    """
  )

  attr(:variant, :string,
    values: @variants,
    default: "pill",
    doc: "`pill` — the bordered chip; `inline` — quiet text for helper copy."
  )

  attr(:platform, :string,
    default: nil,
    values: [nil | @platforms],
    doc: """
    Pin the platform glyph set: `mac` renders `⌘`/`⌥` server-side,
    `other` renders `Ctrl`/`Alt`. Default (`nil`) renders the Mac
    glyphs and ships a hook that swaps to the non-Mac label client-side.
    """
  )

  attr(:class, :string, default: nil, doc: "Additional classes merged onto the label.")

  attr(:rest, :global,
    doc: """
    Forwarded to the `<span>`: `id` (recommended — the platform hook
    needs one; a random id is generated when omitted), `data-*`, `phx-*`, …
    """
  )

  def keyboard_shortcut(assigns) do
    validate_in!(:variant, assigns.variant, @variants)
    validate_in!(:platform, assigns.platform, [nil | @platforms])

    # The platform-swap hook needs a DOM id (LiveView requires one per
    # hook element); take the caller's `id` through globals or generate.
    {hook_id, rest} =
      pop_key(assigns.rest, "id") || {Phoenix.LiveView.Utils.random_id(), assigns.rest}

    assigns =
      assign(assigns,
        rest: rest,
        hook_id: hook_id,
        resolved_label: format_label(assigns.keys, "mac"),
        alt_label: format_label(assigns.keys, "other")
      )

    ~H"""
    <span
      id={@hook_id}
      data-polaris-keyboard-shortcut
      data-variant={@variant}
      data-resolved={@resolved_label}
      data-alt={if(is_nil(@platform), do: @alt_label)}
      class={
        cn([
          "inline-flex shrink-0 whitespace-nowrap",
          "data-[variant=pill]:items-center data-[variant=pill]:rounded data-[variant=pill]:border data-[variant=pill]:border-surface-border data-[variant=pill]:bg-surface-panel/50 data-[variant=pill]:px-[5px] data-[variant=pill]:py-[3px] data-[variant=pill]:text-[11px] data-[variant=pill]:leading-none data-[variant=pill]:tracking-[-0.025em] data-[variant=pill]:text-content-secondary",
          "data-[variant=inline]:items-baseline data-[variant=inline]:text-[11px] data-[variant=inline]:leading-[inherit] data-[variant=inline]:text-content-primary/40",
          @class
        ])
      }
      phx-hook={if(is_nil(@platform), do: "#{inspect(__MODULE__)}.Root")}
      {@rest}
    >{if(@platform == "other", do: @alt_label, else: @resolved_label)}</span>
    <script :if={is_nil(@platform)} :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const el = this.el
          // The source's getIsMac(): navigator.platform is deprecated but
          // still first-class in the source; userAgent is the fallback.
          const isMac =
            (navigator.userAgent && navigator.userAgent.includes("Mac")) ||
            (navigator.platform &&
              (navigator.platform.startsWith("Mac") || navigator.platform === "iPhone"))
          if (!isMac && el.dataset.alt && el.dataset.alt !== el.dataset.resolved) {
            el.textContent = el.dataset.alt
          }
        }
      }
    </script>
    """
  end

  # resolve_key/2 — the source's KEY_SYMBOLS lookup: platform functions
  # for Meta/Alt, static map otherwise, unknown keys fall through as-is.
  defp resolve_key("Meta", "mac"), do: "⌘"
  defp resolve_key("Meta", _), do: "Ctrl"
  defp resolve_key("Alt", "mac"), do: "⌥"
  defp resolve_key("Alt", _), do: "Alt"

  defp resolve_key(key, _) do
    case Map.get(@key_symbols, key, key) do
      <<c::binary-size(1)>> -> String.upcase(c)
      resolved -> resolved
    end
  end

  # format_label/2 — the source's formatShortcutLabel: single-character
  # keys join compactly ("⌘K"), otherwise spaced ("Ctrl ↑").
  defp format_label(keys, platform) do
    resolved = Enum.map(keys, &resolve_key(&1, platform))

    if Enum.all?(resolved, &(String.length(&1) == 1)) do
      Enum.join(resolved, "")
    else
      Enum.join(resolved, " ")
    end
  end

  # Pops a key from a global-attrs map whether it arrived string- or
  # atom-keyed (a compile-time literal alias — no runtime atom creation).
  # Returns nil when absent.
  @rest_key_aliases %{"id" => :id}

  defp pop_key(rest, key) when is_binary(key) do
    alias_key = Map.get(@rest_key_aliases, key)

    cond do
      is_map_key(rest, key) ->
        {Map.get(rest, key), Map.delete(rest, key)}

      alias_key && is_map_key(rest, alias_key) ->
        {Map.get(rest, alias_key), Map.delete(rest, alias_key)}

      true ->
        nil
    end
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
