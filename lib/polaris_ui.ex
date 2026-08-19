defmodule PolarisUI do
  @moduledoc """
  Polaris UI — a dark-mode-first component system for Phoenix LiveView 1.1+
  and Tailwind CSS v4.

  Polaris UI brings Supabase-grade UI density, crisp dark-mode ergonomics,
  monospaced data controls, and real-time streams integration to Phoenix
  applications.

  ## Installation

  Add `polaris_ui` (plus dev-only [Igniter](https://hexdocs.pm/igniter), which
  powers the installers) to the deps of your Phoenix application:

      # mix.exs
      {:igniter, "~> 0.8", only: :dev},
      {:polaris_ui, "~> 0.1"}

  Then run the installer to inject the Polaris design tokens into your
  `assets/css/app.css`:

      $ mix deps.get
      $ mix polaris.install

  Or, in one shot with Igniter (adds both deps and runs the installer):

      $ mix igniter.install polaris_ui

  ## Adding components

  Components are not locked behind a library boundary — they are **copy-injected
  into your application** with full source ownership:

      $ mix polaris.add button drawer

  Each component is written to `lib/<your_app>_web/components/ui/` under your
  own namespace (e.g. `MyAppWeb.Components.UI.Button`), so you can freely
  customize markup and styles. The `polaris_ui` dependency still provides the
  shared engine (`PolarisUI.Utils.cn/1` and `PolarisUI.Tokens`).

  ## Design tokens

  `mix polaris.install` injects a Tailwind v4 `@theme` block that maps semantic
  CSS variables to Tailwind utilities. Components reference tokens such as:

      bg-surface-panel  border-surface-border  text-brand-emerald  font-mono

  Raw hex values never appear in component source — see `PolarisUI.Tokens` for
  the full palette, including the `.polaris-light` override palette.
  """

  @doc """
  Returns the version of the Polaris UI engine.
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:polaris_ui, :vsn) |> to_string()
  end
end
