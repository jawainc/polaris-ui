defmodule PolarisUI.Components do
  @moduledoc """
  The Polaris UI component catalog.

  Components are authored as regular compiled modules in
  `lib/polaris_ui/components/` inside the `polaris_ui` package. Because Hex
  packages ship their `lib/` sources, `mix polaris.add <component>` can read a
  component's source straight from the installed dependency and copy-inject it
  into your application under your own namespace (e.g.
  `MyAppWeb.Components.UI.Button`) — giving you full ownership of the markup
  and styles while `PolarisUI.Utils` and `PolarisUI.Tokens` keep coming from
  the engine.

  This module resolves the component source directory in every context the
  catalog is consulted from:

    * as a Hex/path dependency — via `Mix.Project.deps_paths/0`
    * inside the `polaris_ui` repo itself — via the working directory
    * anywhere else — via `Application.app_dir/2` as a last resort

  ## Catalog entries

  `list/0` returns one entry per component file:

      %PolarisUI.Components.Entry{
        name: "button",
        module: PolarisUI.Components.Button,
        source: "lib/polaris_ui/components/button.ex"
      }

  The catalog currently holds components as they land: the `button` atom and
  the `admonition`, `collapsible_alert`, `collapsible_card_section`,
  `confirmation_modal`, `data_input`, `empty_state_presentational`,
  `error_display`, `filter_bar`, `form_item_layout`, `info_tooltip`, and
  `inner_side_menu` fragments, with more to follow.
  """

  @components_dir "lib/polaris_ui/components"

  defmodule Entry do
    @moduledoc """
    A catalog entry describing one copyable Polaris UI component.
    """

    defstruct [:name, :module, :source]

    @type t :: %__MODULE__{
            name: String.t(),
            module: module(),
            source: Path.t()
          }
  end

  @doc """
  Returns all registered components, sorted by name.
  """
  @spec list() :: [Entry.t()]
  def list do
    dir = components_dir()

    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Stream.filter(&String.ends_with?(&1, ".ex"))
      |> Stream.map(&Path.basename(&1, ".ex"))
      |> Stream.map(fn name ->
        %Entry{
          name: name,
          module: Module.concat([PolarisUI.Components, Macro.camelize(name)]),
          source: Path.join(@components_dir, "#{name}.ex")
        }
      end)
      |> Enum.sort_by(& &1.name)
    else
      []
    end
  end

  @doc """
  Returns the catalog entry with the given name, or `nil`.

  Accepts either form, e.g. `"button"` or `"Button"`.
  """
  @spec fetch(String.t() | atom()) :: Entry.t() | nil
  def fetch(name) when is_atom(name), do: fetch(Atom.to_string(name))

  def fetch(name) when is_binary(name) do
    normalized = name |> Macro.underscore() |> Path.basename(".ex")

    Enum.find(list(), &(&1.name == normalized))
  end

  @doc """
  Reads the source code of the given catalog entry.
  """
  @spec read_source!(Entry.t()) :: binary()
  def read_source!(%Entry{} = entry) do
    entry.source
    |> absolute_source_path()
    |> File.read!()
  end

  @doc """
  Resolves the absolute path of a component source file relative to the
  `polaris_ui` package root.
  """
  @spec absolute_source_path(Path.t()) :: Path.t()
  def absolute_source_path(relative) do
    Path.join(package_root(), relative)
  end

  defp components_dir do
    Path.join(package_root(), @components_dir)
  end

  # Dep resolution order:
  #
  #   1. `Mix.Project.deps_paths/0` — when polaris_ui is a dep of the project
  #      the task runs in (the `mix polaris.add` case).
  #   2. The working directory — when running inside the polaris_ui repo
  #      itself (tests, dogfooding).
  #   3. `Application.app_dir/2` — umbrella/exotic setups.
  defp package_root do
    dep_path =
      if Code.ensure_loaded?(Mix) and Mix.Project.get() do
        Mix.Project.deps_paths()[:polaris_ui]
      end

    cond do
      dep_path && File.dir?(Path.join(dep_path, @components_dir)) ->
        dep_path

      File.dir?(Path.join(File.cwd!(), @components_dir)) ->
        File.cwd!()

      true ->
        Application.app_dir(:polaris_ui)
    end
  end
end
