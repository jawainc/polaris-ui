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
  | `--color-brand-accent`         | `text-`, icons & spinners            | `#3ecf8e` (light: `#097d36`) |
  | `--color-brand-fill`           | `bg-brand-fill`                      | `#15593b` (light: `#72e3ad`) |
  | `--color-brand-border`         | `border-brand-border`                | `rgba(98,207,127,.3)` |
  | `--color-surface-ground`       | `bg-surface-ground`                  | `#0a0a0a`             |
  | `--color-surface-base`         | `bg-surface-base`                    | `#121212`             |
  | `--color-surface-panel`        | `bg-surface-panel`                   | `#1c1c1c`             |
  | `--color-surface-border`       | `border-surface-border`              | `#2e2e2e`             |
  | `--color-surface-border-hover` | `border-surface-border-hover`        | `#404040`             |
  | `--color-surface-muted`        | `bg-surface-muted`                   | `rgba(237,237,237,.08)` (light: `rgba(23,23,23,.06)`) |
  | `--color-content-primary`      | `text-content-primary`               | `#ededed`             |
  | `--color-content-secondary`    | `text-content-secondary`             | `#a0a0a0`             |
  | `--color-content-muted`        | `text-content-muted`                 | `#707070`             |
  | `--color-overlay`              | `bg-overlay`                         | `rgba(0,0,0,.4)` (theme-invariant) |

  Layout tokens live alongside the palette — `--card-padding-x`
  (default `1rem`) drives the shared horizontal rhythm of the card
  sections, `--animate-caret-blink` powers the input OTP's fake caret
  (the Supabase docs' `caret-blink` keyframes), and
  `--animate-progress-indeterminate` sweeps the Progress bar's
  unknown-duration state.

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

      /*
       * Button-role brand tokens, mirroring the Supabase design system
       * (packages/ui): fills are muted greens with visible brand borders;
       * the bright emerald (`brand-accent` in dark) is reserved for
       * icons, spinners, and link text.
       */
      --color-brand-accent: #3ecf8e;
      --color-brand-fill: #15593b;
      --color-brand-fill-hover: #3c945d;
      --color-brand-border: rgba(98, 207, 127, 0.3);
      --color-brand-border-hover: #62cf7f;
      --color-brand-deep: #0c3a25;

      /* Status */
      --color-danger: #e5484d;
      --color-danger-muted: rgba(229, 72, 77, 0.14);
      --color-warning: #ffb224;
      --color-warning-muted: rgba(255, 178, 36, 0.14);
      --color-info: #38bdf8;
      --color-info-muted: rgba(56, 189, 248, 0.14);

      /* Overlay — modal scrims. Theme-invariant by design: a modal dims its
       * backdrop in light mode too, so there is no .polaris-light override. */
      --color-overlay: rgba(0, 0, 0, 0.4);

      /* Status button-role tokens (tinted fills + matching borders) */
      --color-danger-fill: #541c15;
      --color-danger-fill-hover: #a44332;
      --color-danger-border: rgba(229, 72, 77, 0.3);
      --color-danger-border-hover: #e5484d;
      --color-warning-fill: #4a2900;
      --color-warning-fill-hover: #9d6506;
      --color-warning-border: rgba(255, 178, 36, 0.3);
      --color-warning-border-hover: #ffb224;

      /* Surfaces (dark-first) */
      --color-surface-ground: #0a0a0a;
      --color-surface-base: #121212;
      --color-surface-panel: #1c1c1c;
      --color-surface-panel-hover: #232323;
      --color-surface-border: #2e2e2e;
      --color-surface-border-hover: #404040;

      /*
       * Skeleton placeholder — a low-alpha content wash (the Supabase
       * `bg-muted` pattern) instead of an opaque surface, so skeletons
       * read over whatever surface sits behind them.
       */
      --color-surface-muted: rgba(237, 237, 237, 0.08);

      /* Content */
      --color-content-primary: #ededed;
      --color-content-secondary: #a0a0a0;
      --color-content-muted: #707070;

      /* Layout — card sections share this horizontal padding (the Supabase
       * --card-padding-x token; components reference it with a 1rem fallback
       * so installs predating the token keep rendering). */
      --card-padding-x: 1rem;

      /* Typography — monospaced data controls are a Polaris signature */
      --font-mono: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      --font-sans: "Inter", ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;

      /* Motion — the input-otp caret-blink animation (the Supabase docs'
       * tailwind keyframes, as a v4 --animate token) */
      --animate-caret-blink: caret-blink 1.25s ease-out infinite;

      @keyframes caret-blink {
        0%, 70%, 100% {
          opacity: 1;
        }
        20%, 50% {
          opacity: 0;
        }
      }

      /* Motion — the progress bar's indeterminate sweep (the half-width
       * segment traveling the track when duration is unknown) */
      --animate-progress-indeterminate: progress-indeterminate 1.5s ease-in-out infinite;

      @keyframes progress-indeterminate {
        0% {
          transform: translateX(-100%);
        }
        100% {
          transform: translateX(200%);
        }
      }
    }

    /* Light palette — add `polaris-light` to <html> (or any wrapper) to flip. */
    .polaris-light {
      --color-surface-ground: #fcfcfc;
      --color-surface-base: #ffffff;
      --color-surface-panel: #f6f6f6;
      --color-surface-panel-hover: #ededed;
      --color-surface-border: #e2e2e2;
      --color-surface-border-hover: #c8c8c8;
      --color-surface-muted: rgba(23, 23, 23, 0.06);
      --color-content-primary: #171717;
      --color-content-secondary: #525252;
      --color-content-muted: #8f8f8f;
      --color-brand-emerald-muted: rgba(62, 207, 142, 0.12);

      /* Button-role brand tokens flip like the Supabase light theme:
       * brighter fills, dark-green accents for text/icons. */
      --color-brand-accent: #097d36;
      --color-brand-fill: #72e3ad;
      --color-brand-fill-hover: #81d898;
      --color-brand-border: rgba(22, 182, 88, 0.75);
      --color-brand-border-hover: #097d36;
      --color-brand-deep: #d3f8e4;
      --color-danger-fill: #fdd9d3;
      --color-danger-fill-hover: #f8bdb4;
      --color-danger-border: rgba(204, 47, 36, 0.3);
      --color-danger-border-hover: #ca3214;
      --color-warning-fill: #ffe9d6;
      --color-warning-fill-hover: #fcd9b6;
      --color-warning-border: rgba(220, 121, 24, 0.3);
      --color-warning-border-hover: #dc7918;
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
