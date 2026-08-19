if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Polaris.Install do
    @shortdoc "Installs Polaris UI design tokens into your stylesheet"

    @moduledoc """
    #{@shortdoc}

    Injects the Polaris UI Tailwind v4 `@theme` design tokens (see
    `PolarisUI.Tokens`) into your application's stylesheet, creating
    `assets/css/app.css` if no stylesheet is found.

    The installer is idempotent: it detects a previously injected token block by
    its marker comments and leaves it untouched, so you can safely customize the
    injected block and re-run the installer after upgrades.

    ## Example

        mix polaris.install

    ## What it does

      1. Locates your stylesheet (`assets/css/app.css`, `assets/css/main.css`,
         or `assets/css/application.css`).
      2. Warns and aborts injection if the file uses the Tailwind v3 directives
         (`@tailwind base`); Polaris UI requires Tailwind v4.
      3. Inserts the token block right after the `@import "tailwindcss"...`
         statement (appended to the end of the file when the import is not
         found).
      4. Prints next steps (`mix polaris.add <component>`).
    """

    use Igniter.Mix.Task

    @example "mix polaris.install"

    @css_candidates ["assets/css/app.css", "assets/css/main.css", "assets/css/application.css"]
    # Matches `@import "tailwindcss";` and qualified variants Phoenix 1.8
    # generates, e.g. `@import "tailwindcss" source(none);`
    @tailwind_import ~r/^\s*@import\s+"tailwindcss"[^;\n]*;[^\n]*$/m
    @tailwind_v3_directives "@tailwind base"

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        schema: [],
        positional: [],
        example: @example
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      case find_stylesheet(igniter) do
        nil ->
          igniter
          |> Igniter.create_new_file(
            List.first(@css_candidates),
            """
            @import "tailwindcss";

            """ <> PolarisUI.Tokens.source()
          )
          |> Igniter.add_notice(
            "No stylesheet was found, so #{List.first(@css_candidates)} was created with " <>
              "the Polaris UI tokens. Make sure it is bundled by your CSS build."
          )
          |> add_next_steps_notice()

        path ->
          igniter
          |> inject_tokens(path)
          |> add_next_steps_notice()
      end
    end

    defp find_stylesheet(igniter) do
      Enum.find(@css_candidates, &Igniter.exists?(igniter, &1))
    end

    defp inject_tokens(igniter, path) do
      marker = "#{PolarisUI.Tokens.marker()}:start"

      Igniter.update_file(igniter, path, fn source ->
        content = Rewrite.Source.get(source, :content)

        cond do
          String.contains?(content, marker) ->
            {:notice,
             "Polaris UI tokens are already present in #{path} — leaving your customized block untouched."}

          String.contains?(content, @tailwind_v3_directives) ->
            {:warning,
             "#{path} uses Tailwind v3 directives (@tailwind ...). Polaris UI requires " <>
               "Tailwind CSS v4 — upgrade Tailwind, replace the directives with " <>
               "@import \"tailwindcss\";, then re-run mix polaris.install."}

          true ->
            Rewrite.Source.update(
              source,
              :content,
              insert_tokens(content, PolarisUI.Tokens.source())
            )
        end
      end)
    end

    # Insert the token block immediately after the tailwind import so `@theme`
    # overrides flow naturally; fall back to appending at the end.
    defp insert_tokens(content, tokens) do
      case Regex.run(@tailwind_import, content, return: :index, capture: :first) do
        [{start, length} | _] ->
          at = start + length
          suffix = binary_part(content, at, byte_size(content) - at)

          binary_part(content, 0, at) <> "\n\n" <> tokens <> suffix

        nil ->
          String.trim_trailing(content) <> "\n\n" <> tokens <> "\n"
      end
    end

    defp add_next_steps_notice(igniter) do
      Igniter.add_notice(
        igniter,
        "Polaris UI is ready. Add components with `mix polaris.add <component>` " <>
          "(e.g. `mix polaris.add button drawer`), and run `mix polaris.add --list` " <>
          "to see the catalog."
      )
    end
  end
end
