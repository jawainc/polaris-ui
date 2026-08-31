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
- `PolarisUI.Components.Input` — the single-line text field, ported
  1:1 from the Supabase `packages/ui` Input (`input.tsx`, the shadcn
  input over Supabase tokens): the bordered panel fill that brightens
  on hover, the expanded `focus-ring` utility (border on `:focus`,
  emerald ring on `:focus-visible`), the `aria-invalid="true"` danger
  tint, read-only flattening, and disabled treatment — plus the full
  shared `SIZE_VARIANTS` scale (`tiny` 26px → `xlarge` 50px, default
  `small` 34px) and the flat `file:` part styling. Beyond the source,
  a `loading` attr locks the field (`aria-busy`, disabled) and
  overlays the brand spinner at the trailing edge.
- `PolarisUI.Components.InputOTP` — the one-time-password entry,
  ported from the Supabase `packages/ui` Input OTP (the `input-otp`
  library by @guilhermerodz): one real `<input>` (autocomplete
  one-time-code, overridable) overlaid invisibly on the slot row —
  exactly the library's architecture — with the server rendering the
  slot groups (chars from the controlled `value`, normalized against
  `pattern` (`any`/`digits`/`alnum`) and `max_length`) and `group_size`
  chunking them with dot separators (the 3+3 two-factor layout). A
  colocated runtime hook owns the slot choreography: capture-phase
  sanitization of typed/pasted input before LiveView reads the value,
  value mirroring, active-slot emerald ring from the caret position,
  and the fake caret blinking via the new `--animate-caret-blink`
  token (the Supabase docs' `caret-blink` keyframes). The slot row
  lives in a `phx-update="ignore"` subtree so patches never fight the
  hook.
- `PolarisUI.Components.KeyboardShortcut` — the platform-aware
  shortcut label, ported 1:1 from the Supabase `packages/ui`
  KeyboardShortcut: logical key names (`Meta`, `Alt`, `Shift`,
  `Enter`, `Esc`, `Tab`, arrows, single chars auto-uppercased)
  resolved to glyphs with the source's compact-vs-spaced join rule
  (`⌘K`, `⇧⌘M`, `Ctrl ↑`) in `pill` (bordered chip) and `inline`
  (quiet text) variants. The source resolves the platform client-side,
  so the port renders the Mac glyphs server-side and ships both labels
  (`data-resolved`/`data-alt`) with a tiny runtime hook that swaps in
  the non-Mac label on mount; `platform="mac"/"other"` pins the glyphs
  and skips the hook.
- `PolarisUI.Components.Label` — the accessible caption, ported 1:1
  from the Supabase `packages/ui` Label (the Radix Label primitive):
  a native `<label for>` with the source's exact treatment —
  `text-sm`, tight leading, `peer-disabled` cursor/opacity dimming
  for a disabled sibling control.
- `PolarisUI.Components.Menubar` — the persistent horizontal menu bar,
  ported from the Supabase `packages/ui` Menubar (Radix): the h-10
  bordered bar of trigger buttons plus the full item vocabulary —
  items (with `inset`), labels, separators, right-aligned shortcuts,
  checkbox/radio items with indicators (server-driven `checked`),
  radio groups, and hover/ArrowRight submenus with the auto-appended
  chevron. A colocated runtime hook implements the Radix Menubar
  interaction model: click/hover-open switching between menus, the
  pinned `align=start`/`alignOffset=-4`/`sideOffset=8` positioning
  with viewport flip, ArrowLeft/ArrowRight roaming between triggers
  and switching menus while open, arrows/Home/End cycling, typeahead,
  Escape closing inner-first, and item activation falling through to
  each item's own `phx-click`.
- `PolarisUI.Components.Mermaid` — diagrams from Mermaid-syntax text,
  ported from the Supabase `packages/ui-patterns` Mermaid (the
  `mermaid` npm library): a colocated runtime hook loads Mermaid 11
  from jsDelivr once per page (self-hostable via `mermaid_src`),
  initializes with the source's `theme: "base"` + diagram config,
  renders with a unique id per render, sanitizes non-XML `<br>` tags,
  and injects the SVG into the source's centered figure — with the
  pulse placeholder while loading and the danger error box ("Mermaid
  Error: …" + raw source) on invalid syntax. Where the source
  hardcodes two hex palettes, the port reads `themeVariables` from
  the Polaris design tokens at render time (purple accents excepted),
  so diagrams follow app palette overrides and the `polaris-light`
  flip (dark 14px / light 13px font switch included); re-renders are
  keyed off a chart+theme hash and the canvas sits in a
  `phx-update="ignore"` subtree.
- `PolarisUI.Components.NavigationMenu` — the header navigation bar with
  hover/click mega-menu panels, ported from the Supabase
  `packages/ui` NavigationMenu (shadcn over the Radix primitive): the
  `nav` root with the indicator diamond (the rotated `top-[60%]` square
  fading in under the open trigger), the `space-x-1` list, the `h-10`
  trigger with its auto-appended chevron rotating 180° on
  `data-state=open` (`navigationMenuTriggerStyle` cva over Polaris
  tokens — accent surfaces on hover/focus and while open), the panel,
  and the link. Where the source portals contents into the shared
  NavigationMenuViewport, the colocated runtime hook keeps panels in
  their items' DOM (LiveView-patch-safe) and positions them `fixed`,
  centered under the bar with the viewport's own panel treatment,
  clamped to the window; switching slides the new panel in from its
  trigger's direction (`from-start`/`from-end` motion). The Radix
  interaction model: click toggles, hover opens after a delay and
  switches instantly while open, pointer-leave closes after a grace
  period, Escape / click- / focus-outside close and refocus;
  ArrowLeft/Right roam triggers (switching open menus), ArrowDown opens
  and focuses the first panel control, Tab flows through panel links
  naturally; state re-syncs after LiveView patches and repositions on
  resize. The source's `renderViewport={false}` responsive scroll
  pattern composes by wrapping the list.
- `PolarisUI.Components.Pagination` — page navigation with previous and
  next links, ported from the shadcn Pagination the Supabase docs
  declare (the Supabase repo ships no implementation of its own): the
  `aria-label`ed nav landmark with the centered row, `pagination_item`
  `<li>`s, ghost `pagination_link`s swapping to the bordered outline
  fill when `is_active` (`aria-current="page"`, the source's
  `buttonVariants` ghost/outline swap over Polaris tokens and
  26/34/38px height scale), `pagination_previous`/`pagination_next`
  with the source's chevrons, `hidden sm:inline` verbs, and
  "Go to previous/next page" labels (relabel via the inner block), and
  the `pagination_ellipsis` dots with `sr-only` "More pages". Links are
  anchors — `href` for navigation or `phx-click`/`phx-value-page` for
  LiveView paging; anchors have no native disabled, so the disabled
  styling keys off `aria-disabled`.
- `PolarisUI.Components.Progress` — the completion indicator, ported
  1:1 from the Supabase `packages/ui` Progress (shadcn over Radix): the
  4px pill track on a muted surface tone with the bright
  `bg-content-primary` fill translating by the remaining percentage
  (computed server-side from `value`/`max`, clamped, `transition-all`
  smoothing between renders), `role="progressbar"` carrying
  `aria-valuemin`/`aria-valuemax`/`aria-valuenow` (omitted when
  unknown, the Radix `data-state="indeterminate"` contract, fill
  parked). The explicit `indeterminate` mode sweeps a half-width
  segment on the new `--animate-progress-indeterminate` token keyframes
  (added to `PolarisUI.Tokens`) for work with no known duration. No
  hook: progress updates ride ordinary LiveView patches.
- `PolarisUI.Components.RadioGroup` — the mutually exclusive
  single-select, porting the full Supabase `packages/ui` family: the
  base `radio_group` (16px circles with the filled brand dot and paired
  `<label for>`), `radio_group_card` (the `w-48` tiles — visual content
  above the label row, `show_indicator` to drop the circle), and
  `radio_group_stacked` (full-width segments joined with `-space-y-px`,
  first/last rounded, hover and check brightening the surface, `label`
  plus one-sentence `description`). One colocated runtime hook owns the
  Radix state machine for all three: click or arrows check (radios
  never uncheck), roving tabindex (checked item, else first enabled),
  seeding from per-item `checked` or the root `value`, re-application
  after LiveView patches, and syncing the hidden `name` input (bubbling
  `input`/`change` for `phx-change` forms) plus the optional
  `on_change` push with `%{"value" => value}`. Arrow keys wrap,
  Home/End bound the list; disabled locks native, dims, drops from the
  tab order, and is skipped by arrows.
- `PolarisUI.Components.Select` — the single-choice dropdown, ported
  from the Supabase `packages/ui` Select (shadcn over the Radix
  primitive): the trigger with the full
  `tiny`/`small`/`medium`/`large`/`xlarge` size scale (the source's
  `SIZE_VARIANTS`, `small` default), server-resolved selected label or
  muted placeholder (`data-placeholder`), and the 1.5-stroke chevron;
  the fixed-position `role="listbox"` popup (`z-50 max-h-96 min-w-32`,
  trigger-pinned width, side/align/offset with viewport flip,
  fade-zoom-slide entrance) with scroll chevron buttons that appear
  only while the list scrolls; options as `role="option"` rows with
  the reserved `left-2` indicator slot — the checked item carrying
  the filled circle (`bg-content-primary rounded-full`) with the bold
  knocked-out check (stroke-width 6) — under the source's uppercase
  mono group labels (`%{group:}` keying, one label per consecutive
  run, hairline separators between runs). Options are data (`"Apple"`
  or `%{value:, label:, disabled:, group:}` maps) so the trigger label
  and hidden `name` input resolve server-side; one colocated runtime
  hook owns open/close and selection client-side (re-applied after
  LiveView patches): Enter opens at the first item, Space/arrows at
  the selected, arrows cycle, Home/End bound, Enter/Space pick,
  typeahead jumps, Escape/Tab close and refocus the trigger, hover
  highlights via real DOM focus; selection syncs the hidden input
  (bubbling `input`/`change` for `phx-change` forms) and pushes the
  optional `on_change` event with `%{"value" => value}`. Per-option
  `disabled` greys and skips rows; `disabled` locks the trigger;
  `loading` swaps the chevron for the brand spinner (`aria-busy`).
- `PolarisUI.Components.Separator` — the hairline divider, ported 1:1
  from the Supabase `packages/ui` Separator (shadcn over Radix): a
  plain `<div>` with `shrink-0 bg-surface-border` (the source's
  `bg-border-muted` compat alias), `h-px w-full` horizontal /
  `h-full w-px` vertical (sized by its container), `data-orientation`
  always rendered. Like the source, `decorative` defaults to `true`
  (`role="none"`, removed from the a11y tree); `decorative={false}`
  carries `role="separator"` with `aria-orientation` only when
  vertical (horizontal is the ARIA default). No hook.
- `PolarisUI.Components.ScrollArea` — native scrolling with styled
  overlay scrollbars, ported from the Supabase `packages/ui`
  ScrollArea (shadcn over Radix): the `relative overflow-hidden` root,
  the native-scrolling viewport with native scrollbars hidden
  (`[scrollbar-width:none]` + `[&::-webkit-scrollbar]:hidden`) and
  `min-w-full` content sizing, and the absolutely-positioned overlay
  tracks (`w-2.5`, `p-px` plus the 1px transparent border keeping the
  8px `rounded-full bg-surface-border` pill thumb centered, taking no
  layout space). `orientation` picks `vertical` (the source default —
  one vertical bar), `horizontal` (the explicit ScrollBar child), or
  `both`; `type` picks the Radix visibility flavors — `hover` (the
  default; visible under the pointer, hidden 600ms after it leaves),
  `scroll`, `always`, `auto` — riding `data-state=visible|hidden`
  with opacity fades. One colocated runtime hook measures the
  viewport, sizes/positions thumbs, scrolls on thumb drag (pointer +
  touch), reveals/hides per the type, and re-measures on scroll,
  ResizeObserver resize, and LiveView patches; bars with nothing to
  scroll stay hidden (`data-overflow=false`).
- `PolarisUI.Components.Resizable` — draggable, keyboard-resizable
  panel groups, ported from the Supabase `packages/ui` Resizable over
  `react-resizable-panels` v4: the `flex h-full w-full` group
  (`flex-col` when `orientation="vertical"`, `group/resizable` +
  `data-orientation` driving the handles' inverse-orientation
  styling), the `basis-0` panels whose hook-owned `flex-grow`
  percentages size them (inner `overflow-auto` wrapper like the
  library's), and the 1px handle (`bg-surface-border`,
  `data-[separator=active]` recolor to the strong border) with the
  invisible 4px `::after` hit strip, the focusable `role="separator"`
  carrying `aria-orientation`/`aria-controls`/`aria-valuenow/min/max`,
  and — `with_handle` — the hover-revealed grip knob (rotated 90° in
  vertical groups). Sizes are percentages everywhere (`"25"`, `"25%"`,
  `25`); unspecified panels split the remainder. One colocated runtime
  hook owns the layout client-side (re-applied after LiveView
  patches): pointer drags with document-wide `ew-resize`/`ns-resize`
  cursors, proportional redistribution honoring per-panel
  `min_size`/`max_size`, `collapsible`/`collapsed_size`
  snap-and-restore (Enter toggles), the keyboard contract (arrows ±5
  points, Home/End extremes, F6 handle cycling), double-click reset
  to `default_size`, and optional `auto_save_id` persistence under
  the source's `react-resizable-panels-v4:` localStorage scheme
  (best-effort, failures swallowed).
- `PolarisUI.Components.NavMenu` — the tab-style sub-navigation row
  gains the source item's `focus-ring` treatment (emerald
  `focus-visible` ring with offset) alongside its active/hover/disabled
  states.
- `PolarisUI.Components.Popover` — the panel now enters with the
  source's animation — a fade plus the per-side slide from the
  trigger's edge (`data-[side=bottom]:slide-in-from-top-2` & co.),
  fired only on closed→open transitions so LiveView patches never
  replay it.
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
- `PolarisUI.Components.Sheet` — the edge-anchored panel, ported from the
  Supabase `packages/ui` Sheet (shadcn over the Radix Dialog): the
  `top`/`right`/`bottom`/`left` side ladder with inner-edge borders, the
  seven-step `size` scale resolved per axis (`content`, `default` third,
  `sm` quarter, `lg` half, `xl` five sixths, `xxl` sides-only `w-5/6`,
  `full`), the elevated `bg-surface-panel` surface with `shadow-lg`, the
  blurred scrim (droppable via `has_overlay={false}`), the
  header/body/`sheet_section`/footer anatomy with the source's
  `px-5 py-4` rhythm, and the built-in ✕ (droppable via
  `show_close={false}`). A colocated runtime hook slides the panel in
  from its edge over 300ms (the source's `slide-in-from-*` enter) and
  mirrors Radix's modal wiring — Tab trapping, first-focusable focus,
  focus restore, scroll lock, Escape, and scrim dismissal — all
  gated on the `modal` attribute so `modal={false}` renders the
  source's non-modal sheet (interactive page, no `aria-modal`,
  Escape still closes).
- `PolarisUI.Components.Sidebar` — the full shadcn sidebar family at the
  Supabase widths: `sidebar_provider` (the flex shell owning
  `--sidebar-width: 13rem` / `--sidebar-width-icon: 3rem` and painting
  itself under `variant="inset"`), `sidebar` with the
  `offcanvas`/`icon`/`none` collapse modes, `sidebar`/`floating`/`inset`
  variants, `left`/`right` sides, and the `overflowing` overlay mode —
  state riding the DOM exactly like the source (`data-state`,
  `data-collapsible` only-when-collapsed, `data-variant`, `data-side`)
  so every descendant restyles through Tailwind v4 group/peer
  variants. The complete primitive set: trigger (PanelLeft ghost),
  rail (mouse-only strip with the flip cursors), inset (`<main>` that
  rounds under `variant="inset"`), header/content/footer bands,
  separator, input, group/label/action/content, menu/item/button
  (active, `sm`/`default`/`lg` sizes, `outline` variant, `has_icon`
  icon-mode squares, `loading` dim-suppression, `tooltip` as the
  icon-collapsed native title, `href` link flavor), action
  (`show_on_hover`), badge, skeleton (50–90% random bar), and the
  sub/sub-item/sub-button subtree. A colocated runtime hook persists
  every state change to the source's `sidebar:state` cookie (7-day
  max-age), owns the mobile rung (the 18rem sheet with scrim/Escape
  dismissal, Tab trapping, and edge slide-in), and — opt-in via
  `shortcut`, matching the Supabase source shipping it disabled —
  the ⌘/Ctrl+B toggle.
- `PolarisUI.Components.Skeleton` — the pulsing placeholder, ported from
  the Supabase `packages/ui` Skeleton: one `<div>` over
  `animate-pulse rounded-md` filled with a new
  `--color-surface-muted` alpha token (the source's low-alpha
  `bg-muted` wash, flipping under `polaris-light`) so skeletons read
  over any surface; shape arrives entirely through `class` like the
  source's single `className` prop.
- `PolarisUI.Components.Slider` — the value/range picker, ported from the
  Supabase `packages/ui` Slider (shadcn over the Radix primitive): a
  value list whose length is the thumb count (a bare slider inherits
  the source's `[min, max]` quirk; single numbers normalize), the 4px
  pill track with the muted-foreground range span, 20px foreground
  discs with ground-color rings, and the full Radix interaction in a
  colocated runtime hook — step snapping and clamping, nearest-thumb
  track presses, drag-local painting (thumb, range, `aria-valuenow`,
  and hidden inputs) with `on_change`/`on_commit` pushed only on
  release and keypress, the arrows ±1 step / Shift±10 / PageUp/Down /
  Home/End keyboard contract, per-thumb `role="slider"` aria wiring,
  and one hidden range input per thumb when `name` is set.
- `PolarisUI.Components.Sonner` — the toast stack, ported from the
  Supabase `packages/ui` SonnerToaster (shadcn over sonner,
  unstyled-mode): `toaster` renders the fixed stack pinned to any of
  the six positions at the 356px width, and a colocated runtime hook
  owns the client lifecycle — newest-first toasts sliding in from the
  position edge (400ms), the collapsed stack (scaled/dimmed/clipped
  behind the front toast) expanding on hover/focus to measured
  heights, pausable 4s auto-close timers (loading and `:infinity`
  never auto-close), 45px/fling swipe dismissal, the 3-deep visible
  limit, Escape collapse, and ✕ close buttons surfacing on hover.
  Toasts fire with `push_event(socket, "sonner", Sonner.toast/2)` —
  the payload builder carrying `type` (with the Supabase StatusIcon
  badge set for info/warning/error and the emerald check for
  success), `description` (muted, hidden on collapsed non-front
  toasts), `duration`, `id` for update-in-place (loading → success),
  and `action`/`cancel` buttons pushing LiveView events before
  dismissing; warning/error toasts tint via the muted status tokens.
- `PolarisUI.Components.SuccessCheck` — the static 20px emerald disc with
  the 12px 3px-stroke check, ported 1:1 from the Supabase
  `packages/ui` SuccessCheck (`text-surface-ground` reproducing the
  source's `text-white dark:text-black` via theme tokens): the
  selected-state and completion-progress patterns documented, the
  glyph `aria-hidden` as a visual echo of row semantics.
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
