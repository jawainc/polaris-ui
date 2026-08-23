# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `PolarisUI.Components.Accordion` — the vertically stacked disclosure
  pattern, styled 1:1 after the Supabase `packages/ui` Accordion (shadcn
  over Radix): `border-b`-separated items, full-width underlined triggers
  with auto-rotating chevrons (suppressible per item via `hide_icon`,
  the `hideIcon` prop), and 150ms ease-out animated content regions —
  implemented with the CSS `grid-template-rows` technique (closed regions
  `invisible` for screen readers) instead of Radix's measured-height
  keyframes, and disabled under `prefers-reduced-motion`. A colocated
  runtime hook owns the WAI-ARIA open-state machine client-side:
  `type="single"`/`"multiple"` with `collapsible`, `default_open`
  seeding, roving tabindex (ArrowUp/ArrowDown/Home/End, one tab stop per
  accordion, first-open trigger active), per-item `disabled` triggers
  (native disabled, `tabindex="-1"`, skipped by arrows, 50% opacity),
  re-application after LiveView patches, and an optional `on_change`
  event mirroring toggles to the server. Explicit trigger `tabindex` per
  the Supabase Safari fix, emerald `focus-visible` ring, and derived
  `aria-expanded`/`aria-controls`/`role="region"`/`aria-labelledby`
  wiring.
- `PolarisUI.Components.Alert` — the low-level callout primitive, styled
  1:1 after the Supabase `packages/ui` Alert: a `role="alert"` region
  whose *direct-child* SVG becomes the absolutely-positioned 23px badge
  (`left-4 top-4`, padded, rounded, tinted per variant — the exact
  `[&>svg]:*` / `[&>svg~*]:pl-10` selector formula from the source cva);
  a `title` rendered as the `AlertTitle` paragraph; and
  `description` + inner-block body slots with the paragraph rhythm.
  Three variants like the source — `default`, `destructive`, `warning`
  (success callouts are an `<.admonition>` concern) — on translucent
  tinted fills with matching badge chips. `role` overridable via global
  attributes (`role="status"` for passive announcements); no interactive
  affordances of its own.
- `PolarisUI.Components.AlertDialog` — the critical-confirmation modal,
  styled 1:1 after the Supabase `packages/ui` AlertDialog (Radix
  primitive): a `role="alertdialog"` that **cannot be dismissed from
  outside** (no ✕, no backdrop click) and initially focuses the cancel
  button (the Radix safety default). A full-bleed bordered title bar
  (`border-b px-5 py-3`), a single-paragraph `aria-describedby`
  description, an optional body slot that flattens full-bleed
  `<.admonition>` children (which take over the footer's separator via
  the source's `:has()` selector), and a cancel-first footer of tiny
  26px buttons (`flex-col-reverse` stacking the action above the cancel
  on mobile). `variant` tints the action button
  (`primary`/`warning`/`danger`); omitting `action_label` yields the
  close-only acknowledgement pattern. `loading` mirrors the source's
  async machinery: the action spins with the gerund
  `action_label_loading`, both buttons lock, and the colocated runtime
  hook refuses to push Escape while pending. The hook also traps Tab,
  restores focus, and locks background scroll; the seven Supabase
  dialog widths ship as `size`.
- `PolarisUI.Components.AspectRatio` — the ratio box, ported 1:1 from
  the Supabase AspectRatio (a pure Radix re-export): the two-element
  padding-bottom wrapper (`padding-bottom: 100 / ratio %`, rounded to
  four decimals) with an absolutely-positioned inner div carrying the
  caller's `class`/`rest`/`style` — merged *before* the primitive's
  `position: absolute; inset: 0` so the ratio math can never break, the
  same precedence Radix applies. `ratio` defaults to `1.0` (square) and
  raises on zero/negative/non-numeric values. Pure CSS, no hook.
- `PolarisUI.Components.Avatar` — the user representation, styled 1:1
  after the Supabase `packages/ui` Avatar (Radix primitive): a 40px
  circular clipping root (`relative flex h-10 w-10 shrink-0
  overflow-hidden rounded-full`, resized via `class` — upstream ships no
  size variants), an `aspect-square h-full w-full` image, and a bordered
  panel-surface fallback centering the `fallback` initials or rich
  inner-block content. A colocated runtime hook hides the fallback the
  moment the image loads and restores it on error (re-applying after
  LiveView patches); without `src` only the fallback renders and no
  hook ships. `alt` defaults to `""` (decorative) per the Radix
  guidance.
- `PolarisUI.Components.Badge` — the contextual metadata pill, styled
  1:1 after the Supabase `packages/ui` Badge: 9px uppercase medium text
  with `0.07em` tracking, sub-pixel-scale padding (`px-[5.5px] py-[3px]`),
  `rounded-full`, and a baked-in 1px border. Five variants following the
  source formula — `default` (elevated surface, muted text), `warning` /
  `success` / `destructive` (10%-alpha tinted fill + full-strength text
  + translucent color border), and `secondary` (the quiet faint fill,
  the only variant with a hover). Renders a `<span>` so badges sit
  inline in links and paragraphs; no size variants, dot props, or
  interactive affordances upstream — and none added.
- `PolarisUI.Components.Calendar` — the month-grid date picker, styled
  1:1 after the Supabase `packages/ui` Calendar (a react-day-picker v9
  wrapper): the bordered `p-3` surface, centered caption between two
  absolutely-positioned chevron nav buttons (`h-7 w-7`, half-opacity
  until hover, `aria-disabled` at the bounds), a `role="grid"` table
  with flex weekday rows (`w-9` narrow labels with full-name
  `aria-label`s) and 36px day buttons (`h-9 w-9` ghost + the source's
  `aria-selected` hover suppressions). `single` and `range` modes:
  selected days fill with the signature emerald + near-black text for
  WCAG-safe contrast; complete ranges tint middles with the muted brand
  fill and round only the end caps; today carries a quiet panel chip.
  A colocated runtime hook owns months, selection, and the react-day-picker
  keyboard standard client-side (month regeneration with the same markup,
  RDP toggle/range semantics, min/max clamping, one tab stop with
  arrows / Home / End / PageUp / PageDown navigation, `aria-live`
  caption announcements, re-render after LiveView patches, and an
  optional `on_select` event with mode-shaped payloads). Outside days
  dim (`opacity-50`), out-of-bound days stay focusable-but-inert
  (`aria-disabled`, no hover), and `week_starts_on` rotates the header.
- `PolarisUI.Components.Card` — the bordered content surface, styled 1:1
  after the Supabase `packages/ui` Card: clipped corners
  (`overflow-hidden rounded-lg`), panel fill, high-contrast border, and
  the hairline `shadow-xs`; sectioned header/content/footer sharing the
  `px-[var(--card-padding-x,1rem)]` rhythm (the Supabase
  `--card-padding-x` token, now shipped in `PolarisUI.Tokens` with a
  fallback for pre-existing installs) with `border-b` separators —
  dropped via `last:border-none` when no footer follows; the title is
  the signature 12px monospaced uppercase `<h3>`. Presentational by
  design: interactive states belong to the controls composed inside.
- `PolarisUI.Components.Carousel` — the slideshow with motion and swipe,
  ported from the shadcn/ui Carousel that the Supabase design system
  documents (Supabase ships no source of its own): the
  `role="region"`/`aria-roledescription="carousel"` root, snapped
  scroll viewport (scrollbar-hidden, `cursor-grab` drag) wrapping the
  flex track with the `-ml-4`/`pl-4` spacing model, `basis-full
  snap-start` slides (`role="group"`), and the 32px circular outline
  prev/next buttons floated outside the viewport edges (rotated 90°
  for `orientation="vertical"`, which subcomponents take explicitly —
  the shadcn context made literal). The embla engine becomes a
  colocated runtime hook over CSS scroll-snap: snap-point prev/next
  scrolling, button enablement at the bounds, arrow-key navigation,
  mouse drag with post-drag click suppression, and an optional
  `on_change` event with `%{"selected" => index, "count" => slides}`
  for slide counters.
- `PolarisUI.Components.Checkbox` — the boolean control, styled 1:1
  after the Supabase `packages/ui` Checkbox (shadcn over Radix): the
  16px `rounded-sm` box over a faint panel fill, inverting on check to
  the bright fill + dark check (the source's foreground/background
  inversion — never emerald), with cross-fading Check (strokeWidth 4)
  and mixed-state dash indicators. A colocated runtime hook owns the
  Radix toggle cycle (unchecked → checked → unchecked, indeterminate →
  checked), syncs a visually-hidden native checkbox for form
  participation — dispatching bubbling `input`/`change` so `phx-change`
  forms observe toggles — and optionally pushes `on_change` with the
  state and value. The paired `<label for>` dims through the `peer`
  relationship; disabled boxes take the explicit Safari `tabindex="-1"`
  fix; focus is the shared emerald ring.
- `PolarisUI.Components.Collapsible` — the low-level disclosure
  primitive, ported from the Supabase `packages/ui` Collapsible (a
  near-passthrough over Radix): slot-based `:trigger`/`:content`
  composition with derived id wiring (`aria-expanded` +
  `aria-controls`, `role="region"` + `aria-labelledby`). The unstyled
  Supabase primitive gains only the shared interaction states (cursor,
  focus ring, disabled with the explicit Safari tabindex fix); the
  150ms ease-out `grid-template-rows` height animation (closed regions
  `invisible`) ships by default — the Supabase docs' opt-in
  `animate-collapsible-up/down` made standard — disabled under
  `prefers-reduced-motion` and opt-out via `class="transition-none"`.
  A colocated runtime hook owns the open state (seeded from
  `default_open`, re-applied after LiveView patches, refusing disabled
  roots/triggers) and optionally pushes `on_change` with the state.
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
