defmodule Mix.Tasks.Polaris.InstallTest do
  use ExUnit.Case, async: false
  import Igniter.Test

  @tokens PolarisUI.Tokens.source()

  test "injects tokens right after the tailwind import" do
    test_project(
      files: %{"assets/css/app.css" => "@import \"tailwindcss\";\nbody { margin: 0; }\n"}
    )
    |> Igniter.compose_task("polaris.install", [])
    |> assert_content_equals(
      "assets/css/app.css",
      "@import \"tailwindcss\";\n\n" <> @tokens <> "\nbody { margin: 0; }\n"
    )
  end

  test "injects after qualified imports like Phoenix 1.8's source(none)" do
    test_project(
      files: %{
        "assets/css/app.css" =>
          "@import \"tailwindcss\" source(none);\n@import \"phoenix-colocated/my_app/colocated.css\";\n"
      }
    )
    |> Igniter.compose_task("polaris.install", [])
    |> assert_content_equals(
      "assets/css/app.css",
      "@import \"tailwindcss\" source(none);\n\n" <>
        @tokens <>
        "\n@import \"phoenix-colocated/my_app/colocated.css\";\n"
    )
  end

  test "appends tokens when no tailwind import line is present" do
    test_project(files: %{"assets/css/app.css" => "body { margin: 0; }\n"})
    |> Igniter.compose_task("polaris.install", [])
    |> assert_content_equals(
      "assets/css/app.css",
      "body { margin: 0; }\n\n" <> @tokens <> "\n"
    )
  end

  test "is idempotent when tokens are already installed" do
    installed = "@import \"tailwindcss\";\n\n" <> @tokens

    test_project(files: %{"assets/css/app.css" => installed})
    |> Igniter.compose_task("polaris.install", [])
    |> assert_unchanged("assets/css/app.css")
  end

  test "warns and does not inject into a Tailwind v3 stylesheet" do
    test_project(
      files: %{
        "assets/css/app.css" => """
        @tailwind base;
        @tailwind components;
        @tailwind utilities;
        """
      }
    )
    |> Igniter.compose_task("polaris.install", [])
    |> assert_has_warning(
      "assets/css/app.css uses Tailwind v3 directives (@tailwind ...). Polaris UI requires " <>
        "Tailwind CSS v4 — upgrade Tailwind, replace the directives with " <>
        "@import \"tailwindcss\";, then re-run mix polaris.install."
    )
    |> assert_unchanged("assets/css/app.css")
  end

  test "creates the stylesheet when none exists" do
    test_project()
    |> Igniter.compose_task("polaris.install", [])
    |> assert_creates("assets/css/app.css", &String.contains?(&1, "--color-brand-emerald"))
    |> assert_has_notice(
      "Polaris UI is ready. Add components with `mix polaris.add <component>` " <>
        "(e.g. `mix polaris.add button drawer`), and run `mix polaris.add --list` " <>
        "to see the catalog."
    )
  end

  test "prefers app.css when both app.css and main.css exist" do
    test_project(
      files: %{
        "assets/css/app.css" => "@import \"tailwindcss\";\n",
        "assets/css/main.css" => "@import \"tailwindcss\";\n"
      }
    )
    |> Igniter.compose_task("polaris.install", [])
    |> assert_content_equals(
      "assets/css/app.css",
      "@import \"tailwindcss\";\n\n" <> @tokens <> "\n"
    )
    |> assert_unchanged("assets/css/main.css")
  end

  test "falls back to main.css when app.css is absent" do
    test_project(files: %{"assets/css/main.css" => "@import \"tailwindcss\";\n"})
    |> Igniter.compose_task("polaris.install", [])
    |> assert_content_equals(
      "assets/css/main.css",
      "@import \"tailwindcss\";\n\n" <> @tokens <> "\n"
    )
  end
end
