# `mix igniter.install polaris_ui` looks for a task named `<package>.install`
# (i.e. `polaris_ui.install`) after adding the dependency — this alias makes
# that flow work while keeping `mix polaris.install` as the canonical task.
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PolarisUI.Install do
    @shortdoc "Installs Polaris UI (alias of mix polaris.install)"

    @moduledoc """
    #{@shortdoc}

    Automatically composed by `mix igniter.install polaris_ui`. Delegates all
    work to `mix polaris.install` — see that task for details.
    """

    use Igniter.Mix.Task

    @example "mix igniter.install polaris_ui"

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
      Igniter.compose_task(igniter, "polaris.install", igniter.args.argv)
    end
  end
end
