if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Polaris.Add do
    @shortdoc "Copies Polaris UI components into your application"

    @moduledoc """
    #{@shortdoc}

    Reads each named component's source from the `polaris_ui` package and
    copy-injects it into `lib/<app>_web/components/ui/` under your application's
    namespace — e.g. `mix polaris.add button` creates
    `lib/my_app_web/components/ui/button.ex` defining
    `MyAppWeb.Components.UI.Button`. You own the copied source: edit markup and
    classes freely. The `polaris_ui` engine (`PolarisUI.Utils.cn/1`,
    `PolarisUI.Tokens`) keeps providing the shared machinery.

    ## Example

        mix polaris.add button drawer
        mix polaris.add data_grid --namespace MyAppWeb.Design

    ## Options

      * `--namespace` — the target namespace. Defaults to the conventional
        `<YourApp>Web` inferred from your `mix.exs` application name.
      * `--list` — print the available components instead of copying anything.

    Existing files are never overwritten; the task reports them as skipped.
    After copying, import the component modules where they are used (e.g. in
    your `MyAppWeb` html helpers).
    """

    use Igniter.Mix.Task

    @example "mix polaris.add button drawer"

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        schema: [namespace: :string, list: :boolean],
        aliases: [],
        positional: [components: [rest: true, optional: true]],
        example: @example
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      if igniter.args.options[:list] do
        print_catalog()
        igniter
      else
        copy_components(igniter, igniter.args.positional[:components] || [])
      end
    end

    defp copy_components(_igniter, []) do
      Mix.raise("""
      mix polaris.add expects at least one component name.

          mix polaris.add button drawer

      Run `mix polaris.add --list` to see the available components.
      """)
    end

    defp copy_components(igniter, names) do
      entries = Enum.map(names, &fetch_entry!/1)
      namespace = namespace(igniter)

      {igniter, copied, skipped} =
        Enum.reduce(entries, {igniter, [], []}, fn entry, {acc, copied, skipped} ->
          path = component_path(namespace, entry)

          if Igniter.exists?(acc, path) do
            {acc, copied, [entry.name | skipped]}
          else
            contents =
              entry
              |> PolarisUI.Components.read_source!()
              |> rewrite_module_names(namespace)

            {Igniter.create_new_file(acc, path, contents), [entry.name | copied], skipped}
          end
        end)

      notices =
        [
          if(copied != [],
            do:
              "Added #{Enum.count(copied)} component(s): #{Enum.join(copied, ", ")} — " <>
                "import #{namespace}.Components.UI.#{first_module(copied)} (et al) where used."
          ),
          if(skipped != [],
            do: "Skipped (already present): #{Enum.join(skipped, ", ")}."
          )
        ]
        |> Enum.reject(&is_nil/1)

      Enum.reduce(notices, igniter, &Igniter.add_notice(&2, &1))
    end

    defp fetch_entry!(name) do
      case PolarisUI.Components.fetch(name) do
        nil ->
          Mix.raise("""
          Unknown Polaris UI component: #{inspect(name)}

          Available components:

          #{catalog_listing()}
          """)

        entry ->
          entry
      end
    end

    defp namespace(igniter) do
      case Keyword.get(igniter.args.options, :namespace) do
        nil ->
          app =
            if Mix.Project.get() do
              Mix.Project.config()[:app]
            else
              :my_app
            end

          Macro.camelize(Atom.to_string(app)) <> "Web"

        namespace ->
          namespace
      end
    end

    # Components are authored under `PolarisUI.Components.*`. Rewrite the
    # module namespace (and any references between Polaris components) to the
    # caller's namespace. `PolarisUI.Component`, `PolarisUI.Utils`, and
    # `PolarisUI.Tokens` engine references must NOT be rewritten.
    defp rewrite_module_names(source, namespace) do
      String.replace(source, "PolarisUI.Components.", "#{namespace}.Components.UI.")
    end

    defp component_path(namespace, entry) do
      "lib/#{Macro.underscore(namespace)}/components/ui/#{entry.name}.ex"
    end

    defp first_module([name | _]), do: Macro.camelize(name)

    defp print_catalog do
      Mix.shell().info("""
      Polaris UI components:

      #{catalog_listing()}
      """)
    end

    defp catalog_listing do
      case PolarisUI.Components.list() do
        [] ->
          "  (none yet — components land in upcoming Polaris UI phases)"

        entries ->
          Enum.map_join(entries, "\n", &"  * #{&1.name} (#{inspect(&1.module)})")
      end
    end
  end
end
