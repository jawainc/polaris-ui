defmodule PolarisUI.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :polaris_ui,
      version: @version,
      elixir: "~> 1.15",
      description: description(),
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [docs: :docs, "hex.build": :docs, "hex.publish": :docs]
    ]
  end

  def application do
    [extra_applications: [:logger, :inets, :ssl]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Dark-mode-first UI components for Phoenix LiveView 1.1+ and Tailwind CSS v4, " <>
      "delivered as copy-injected source code via Igniter."
  end

  defp deps do
    [
      # Phoenix LiveView 1.1+ is required for Colocated Hooks
      # (`<script :type={Phoenix.LiveView.ColocatedHook}>`) used by interactive components.
      {:phoenix_live_view, "~> 1.1"},
      # Igniter powers `mix polaris.install` and `mix polaris.add`. Declared
      # `optional: true` per Igniter's library-author guide: consuming apps that
      # have Igniter (dev-only) get the installers, and Igniter never leaks
      # into production releases. Task modules are compile-gated on
      # `Code.ensure_loaded?(Igniter)`.
      {:igniter, "~> 0.8", optional: true},
      {:ex_doc, "~> 0.40", only: [:dev, :docs], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md),
      links: links()
    ]
  end

  # TODO: set POLARIS_UI_REPO_URL (or hardcode the canonical GitHub URL here)
  # before running `mix hex.publish`.
  defp links do
    if url = System.get_env("POLARIS_UI_REPO_URL") do
      %{"GitHub" => url}
    else
      %{}
    end
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: System.get_env("POLARIS_UI_REPO_URL"),
      groups_for_modules: [
        "Component Infrastructure": [
          PolarisUI.Component,
          PolarisUI.Components,
          PolarisUI.Tokens,
          PolarisUI.Utils
        ]
      ]
    ]
  end
end
