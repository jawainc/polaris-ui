# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
