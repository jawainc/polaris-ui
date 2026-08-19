defmodule PolarisUI.Tokens do
  @moduledoc """
  The Polaris UI design token source — a Tailwind CSS v4 `@theme` block with
  semantic CSS custom properties.

  `mix polaris.install` injects `source/0` into the consuming application's
  `assets/css/app.css` (right after `@import "tailwindcss";`). Tailwind v4 maps
  each `--color-*` / `--font-*` variable to utilities, which is what components
  use in their class lists:

  | Token                          | Utilities                            | Value (dark, default) |
  |--------------------------------|--------------------------------------|-----------------------|
  | `--color-brand-emerald`        | `bg-`, `text-`, `border-`, `ring-` … | `#3ecf8e`             |
  | `--color-surface-ground`       | `bg-surface-ground`                  | `#0a0a0a`             |
  | `--color-surface-base`         | `bg-surface-base`                    | `#121212`             |
  | `--color-surface-panel`        | `bg-surface-panel`                   | `#1c1c1c`             |
  | `--color-surface-border`       | `border-surface-border`              | `#2e2e2e`             |
  | `--color-surface-border-hover` | `border-surface-border-hover`        | `#404040`             |
  | `--color-content-primary`      | `text-content-primary`               | `#ededed`             |
  | `--color-content-secondary`    | `text-content-secondary`             | `#a0a0a0`             |
  | `--color-content-muted`        | `text-content-muted`                 | `#707070`             |

  ## Theming

  Polaris is **dark-mode-first**: the dark palette is defined on `:root` (via
  `@theme`) and applies everywhere by default. Adding the `polaris-light`
  class to `<html>` (or to any subtree wrapper) flips the surface and content
  variables to the light palette — utilities keep working because Tailwind v4
  utilities reference the CSS variables directly.

  The optional `.polaris` class applies the ground surface and primary text
  color to a subtree (e.g. `<body class="polaris">`).

  Components must reference these semantic utilities only — never raw hex
  values (`bg-[#121212]` is forbidden in component source). New components may
  propose new tokens here instead.
  """

  @doc """
  The marker comment delimiting the injected token block. Used to keep
  `mix polaris.install` idempotent.
  """
  @spec marker() :: String.t()
  def marker, do: "polaris-ui-tokens"

  @doc """
  Returns the full design-token CSS (Tailwind v4 `@theme` block plus the
  `.polaris-light` and `.polaris` rules) that gets injected into the
  consuming app's stylesheet.
  """
  @spec source() :: String.t()
  def source do
    """
    /* polaris-ui-tokens:start */
    /*
     * Polaris UI design tokens — injected by `mix polaris.install`.
     * This block is yours to customize; re-running the installer will not
     * duplicate it. Reference tokens via Tailwind utilities such as
     * `bg-surface-panel`, `border-surface-border`, or `text-brand-emerald`.
     */
    @theme {
      /* Brand */
      --color-brand-emerald: #3ecf8e;
      --color-brand-emerald-hover: #36ba80;
      --color-brand-emerald-muted: rgba(62, 207, 142, 0.14);

      /* Status */
      --color-danger: #e5484d;
      --color-danger-muted: rgba(229, 72, 77, 0.14);
      --color-warning: #ffb224;
      --color-warning-muted: rgba(255, 178, 36, 0.14);
      --color-info: #38bdf8;
      --color-info-muted: rgba(56, 189, 248, 0.14);

      /* Surfaces (dark-first) */
      --color-surface-ground: #0a0a0a;
      --color-surface-base: #121212;
      --color-surface-panel: #1c1c1c;
      --color-surface-panel-hover: #232323;
      --color-surface-border: #2e2e2e;
      --color-surface-border-hover: #404040;

      /* Content */
      --color-content-primary: #ededed;
      --color-content-secondary: #a0a0a0;
      --color-content-muted: #707070;

      /* Typography — monospaced data controls are a Polaris signature */
      --font-mono: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      --font-sans: "Inter", ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
    }

    /* Light palette — add `polaris-light` to <html> (or any wrapper) to flip. */
    .polaris-light {
      --color-surface-ground: #fcfcfc;
      --color-surface-base: #ffffff;
      --color-surface-panel: #f6f6f6;
      --color-surface-panel-hover: #ededed;
      --color-surface-border: #e2e2e2;
      --color-surface-border-hover: #c8c8c8;
      --color-content-primary: #171717;
      --color-content-secondary: #525252;
      --color-content-muted: #8f8f8f;
      --color-brand-emerald-muted: rgba(62, 207, 142, 0.12);
    }

    /* Optional base scope — e.g. <body class="polaris"> */
    .polaris {
      background-color: var(--color-surface-ground);
      color: var(--color-content-primary);
    }
    /* polaris-ui-tokens:end */
    """
  end
end
