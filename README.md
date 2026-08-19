# Polaris UI

Dark-mode-first UI components for **Phoenix LiveView 1.1+** and **Tailwind CSS v4**.

Polaris UI brings Supabase-grade UI density, crisp dark-mode ergonomics, monospaced
data controls, and real-time streams integration to Phoenix applications.

## Why it looks familiar

Polaris is dark-first and token-driven by design:

* Signature emerald accent (`#3ecf8e`) on layered dark surfaces (`#0a0a0a` → `#121212` → `#1c1c1c`)
* Muted, high-contrast borders (`#2e2e2e` → `#404040`)
* Monospaced fonts for data-dense controls (keys, IDs, SQL, JSON)
* Action-oriented microcopy — buttons use direct verbs ("Create table", not "Submit")

## Installation

Add `polaris_ui` to your Phoenix application's dependencies, plus [Igniter](https://hexdocs.pm/igniter)
(dev-only — it powers the installers and never ships to production):

```elixir
# mix.exs
defp deps do
  [
    {:igniter, "~> 0.8", only: :dev},
    {:polaris_ui, "~> 0.1"}
  ]
end
```

Then run the installer:

```bash
mix deps.get
mix polaris.install
```

Or in one shot (adds both dependencies and runs the installer):

```bash
mix igniter.install polaris_ui
```

`mix polaris.install` injects the Polaris design tokens into `assets/css/app.css`
as a Tailwind v4 `@theme` block. Tailwind maps each token to utilities your
components (and your own code) can use:

```html
<div class="bg-surface-panel border border-surface-border text-content-secondary font-mono">
```

The installer is idempotent — it leaves an already-injected block untouched, so
you can customize it freely.

> **Tailwind v4 required.** The installer detects Tailwind v3 directives
> (`@tailwind base;`) and warns instead of injecting.
>
> **Igniter required.** The `mix polaris.*` tasks are compiled only when
> Igniter is present in your app (dev environment), which is why `{:igniter,
> "~> 0.8", only: :dev}` is part of the standard setup above.

## Design tokens

| Token                          | Utilities                          | Dark (default) | Light (`.polaris-light`) |
| ------------------------------ | ---------------------------------- | -------------- | ------------------------ |
| `--color-brand-emerald`        | `bg-` `text-` `border-` `ring-` …  | `#3ecf8e`      | `#3ecf8e`                |
| `--color-surface-ground`       | `bg-surface-ground`                | `#0a0a0a`      | `#fcfcfc`                |
| `--color-surface-base`         | `bg-surface-base`                  | `#121212`      | `#ffffff`                |
| `--color-surface-panel`        | `bg-surface-panel`                 | `#1c1c1c`      | `#f6f6f6`                |
| `--color-surface-border`       | `border-surface-border`            | `#2e2e2e`      | `#e2e2e2`                |
| `--color-surface-border-hover` | `border-surface-border-hover`      | `#404040`      | `#c8c8c8`                |
| `--color-content-primary`      | `text-content-primary`             | `#ededed`      | `#171717`                |
| `--color-content-secondary`    | `text-content-secondary`           | `#a0a0a0`      | `#525252`                |
| `--color-content-muted`        | `text-content-muted`               | `#707070`      | `#8f8f8f`                |
| `--font-mono`                  | `font-mono`                        | JetBrains Mono → system fallbacks | — |

Full palette (including `danger`, `warning`, `info`, and `*-muted` tints): see
`PolarisUI.Tokens`.

**Theming** — Polaris is dark-mode-first; the dark palette applies by default. Add
`polaris-light` to `<html>` (or any subtree wrapper) to flip surfaces and text to
the light palette. Utilities keep working in both modes because Tailwind v4
utilities reference the CSS variables directly. The optional `polaris` class
applies the ground surface + primary text color to a subtree (e.g.
`<body class="polaris">`).

## Adding components

Components are **copy-injected, not locked away**:

```bash
mix polaris.add button drawer          # copy components into your app
mix polaris.add --list                 # see the catalog
```

Each component's source is copied from the installed `polaris_ui` package into
`lib/<your_app>_web/components/ui/` under your own namespace:

```
lib/my_app_web/components/ui/button.ex   →  defmodule MyAppWeb.Components.UI.Button
```

You own the copied source — customize markup and styles without fighting CSS
overrides. The `polaris_ui` engine dependency keeps providing the shared
machinery (`PolarisUI.Utils.cn/1`, `PolarisUI.Tokens`), so copied components work
unmodified. Use `--namespace` to target a different namespace.

## Authoring components against the engine

Components in this package are authored like this:

```elixir
defmodule PolarisUI.Components.Button do
  use PolarisUI.Component

  attr :variant, :string, default: "secondary"
  attr :class, :string, default: nil
  attr :rest, :global

  def button(assigns) do
    ~H"""
    <button
      class={
        cn([
          "rounded-md border border-surface-border bg-surface-panel px-3 py-1.5",
          "text-xs text-content-primary hover:border-surface-border-hover",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
```

Rules for Polaris components (enforced in review and tests):

1. **Tokens only** — never hardcode raw hex values (`bg-[#121212]` is
   forbidden); reference `PolarisUI.Tokens` utilities instead.
2. **`cn/1` for merging** — combine default classes with the caller's `class`
   attribute; conflicts resolve with "caller wins" semantics.
3. **LiveView 1.1+ idioms** — full `attr`/`slot` specs, `Phoenix.HTML.FormField`
   support where relevant, and [Colocated
   Hooks](https://hexdocs.pm/phoenix_live_view/colocated-hooks.html)
   (`<script :type={Phoenix.LiveView.ColocatedHook}>`) for client-side
   interactivity — no separate JS asset files.
4. **Isolated tests** — every component gets tests under
   `test/polaris_ui/components/`.

## Development

```bash
mix setup               # deps.get
mix test                # engine + installer tests
mix format              # includes ~H via Phoenix.LiveView.HTMLFormatter
mix docs                # HexDocs
```

The test suite covers the class merger (`PolarisUI.Utils.cn/1`), token
consistency (every surface/content token has a light override), the Igniter
installers (in-memory project patching), and a component-rendering harness for
future component sessions.

## Publishing (maintainers)

```bash
POLARIS_UI_REPO_URL=https://github.com/<org>/polaris_ui mix hex.build
POLARIS_UI_REPO_URL=https://github.com/<org>/polaris_ui mix hex.publish
```

Set the canonical repository URL in `mix.exs` (`links/0`) before the first
publish.

## License

MIT — see [LICENSE](LICENSE.md).
