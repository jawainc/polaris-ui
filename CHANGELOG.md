# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `PolarisUI.Components.Admonition` — the callout pattern, styled 1:1 after
  the Supabase fragment `ui-patterns/Admonition` (on its shadcn `Alert`
  primitive): eight semantic types (`note`, `default`, `caution`,
  `warning`, `deprecation`, `danger`, `destructive`, `success`) collapsing
  into neutral / amber / red / emerald treatments, each with a
  type-derived `aria-label`; a 23px badge chip (info / triangle / check
  glyphs, replaceable via the `icon` slot or hidden with `show_icon`);
  paragraph titles (never headings); `description` + inner-block body
  slots with the Supabase paragraph rhythm; an `action` slot arranged per
  `layout` (`vertical`, `horizontal`, or `responsive` with container
  queries driven by the admonition's own width); `role="alert"` /
  `aria-label` overridable via global attributes (e.g. `role="status"`
  for passive announcements); and caller classes for sandwiched usage
  (`rounded-none border-x-0`). Interactive states (hover, focus-ring,
  loading, disabled) are delegated to the slotted action controls.
- `PolarisUI.Utils.slot_content?/2` — blank-detection for slot lists that
  handles both statically-inlined `Phoenix.LiveView.Rendered` inner
  blocks and arity-2 closure inner blocks (dynamic content / calls inside
  comprehensions). Exported through `use PolarisUI.Component`.
- `PolarisUI.Components.Button` — the first catalog component, styled 1:1 after
  the Supabase design system button (`packages/ui`): eight variants
  (`primary`, `default`, `secondary`, `warning`, `danger`, `outline`,
  `ghost`, `link`) with muted brand fills + brand borders, five sizes
  matching the Supabase height scale (26/34/38/42/50px with 14/18/20/20/24px
  auto-sized icons), leading/trailing icon slots tinted per variant,
  icon-only rendering with an enforced accessible name, link-as-button via
  `href` (the `asChild` equivalent), and full state coverage — rest, hover,
  `:focus-visible` ring, loading (per-variant spinner tint + `aria-busy` +
  locked), and disabled (dimmed, `tabindex="-1"`).
- New button-role design tokens (`--color-brand-fill`, `--color-brand-accent`,
  `--color-brand-border{,-hover}`, `--color-brand-deep`,
  `--color-danger-fill{,-hover}`, `--color-danger-border{,-hover}`,
  `--color-warning-fill{,-hover}`, `--color-warning-border{,-hover}`) with
  light-mode overrides derived from the Supabase light theme.

### Fixed

- `PolarisUI.Components.Button` icon-only detection crashed at runtime in
  real LiveViews when the label slot held dynamic content (closure inner
  block): `Phoenix.HTML.Safe.to_iodata/1` has no implementation for
  functions. The shared `slot_content?/2` helper now renders both slot
  shapes, matching what `render_slot/2` does.

## [0.1.0] - 2026-08-19

### Added

- Core engine: `PolarisUI.Component` (`use` macro), `PolarisUI.Utils.cn/1`
  Tailwind-aware class merger, and `PolarisUI.Tokens` design token source.
- Tailwind v4 `@theme` design tokens (dark-first) with a `.polaris-light`
  override palette and a `.polaris` base scope class.
- Component catalog (`PolarisUI.Components`) powering `mix polaris.add`.
- Igniter installers: `mix polaris.install` (token injection into
  `assets/css/app.css`) and `mix polaris.add <component...>` (copy-injects
  component source into `lib/<app>_web/components/ui/`).
