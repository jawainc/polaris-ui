defmodule Mix.Tasks.Polaris.AddTest do
  use ExUnit.Case, async: false
  import Igniter.Test

  @moduledoc """
  The base engine ships no components yet (they land in Phase 2+), so these
  tests exercise the copy-inject pipeline with a temporary catalog fixture.
  The fixture is written into `lib/polaris_ui/components/` — exactly where
  real components will live — and removed afterwards.
  """

  @fixture_path "lib/polaris_ui/components/greeble.ex"

  @fixture_source """
  defmodule PolarisUI.Components.Greeble do
    @moduledoc false
    use PolarisUI.Component

    attr :label, :string, required: true
    attr :class, :string, default: nil

    def greeble(assigns) do
      ~H\"\"\"
      <div class={cn(["bg-surface-panel border border-surface-border font-mono", @class])}>
        {@label}
      </div>
      \"\"\"
    end
  end
  """

  setup do
    File.mkdir_p!(Path.dirname(@fixture_path))
    File.write!(@fixture_path, @fixture_source)

    on_exit(fn -> File.rm!(@fixture_path) end)

    :ok
  end

  test "copies a component under the caller's namespace with engine refs intact" do
    test_project()
    |> Igniter.compose_task("polaris.add", ["greeble", "--namespace", "MyAppWeb"])
    |> assert_creates("lib/my_app_web/components/ui/greeble.ex", fn content ->
      assert content =~ "defmodule MyAppWeb.Components.UI.Greeble do"
      # engine references are preserved — the dep keeps providing them
      assert content =~ "use PolarisUI.Component"
      assert content =~ "cn(["
      # the Polaris namespace must not leak into the copy
      refute content =~ "PolarisUI.Components"
    end)
  end

  test "rewrites references between Polaris components too" do
    # simulate a component that renders another Polaris component
    referencing =
      String.replace(
        @fixture_source,
        "{@label}",
        "<PolarisUI.Components.Icon.greeble_icon />{@label}"
      )

    File.write!(@fixture_path, referencing)

    test_project()
    |> Igniter.compose_task("polaris.add", ["greeble", "--namespace", "ShopifyWeb.Design"])
    |> assert_creates("lib/shopify_web/design/components/ui/greeble.ex", fn content ->
      assert content =~ "defmodule ShopifyWeb.Design.Components.UI.Greeble do"
      assert content =~ "<ShopifyWeb.Design.Components.UI.Icon.greeble_icon />"
      refute content =~ "PolarisUI.Components"
    end)
  end

  test "skips components that already exist and reports them" do
    test_project(
      files: %{
        "lib/my_app_web/components/ui/greeble.ex" =>
          "defmodule MyAppWeb.Components.UI.Greeble do\nend\n"
      }
    )
    |> Igniter.compose_task("polaris.add", ["greeble", "--namespace", "MyAppWeb"])
    |> assert_unchanged("lib/my_app_web/components/ui/greeble.ex")
    |> assert_has_notice("Skipped (already present): greeble.")
  end

  test "raises for unknown components and lists the catalog" do
    assert_raise Mix.Error, ~r/Unknown Polaris UI component: "definitely_not_a_component"/, fn ->
      test_project()
      |> Igniter.compose_task("polaris.add", ["definitely_not_a_component"])
    end
  end

  test "requires at least one component name" do
    assert_raise Mix.Error, ~r/expects at least one component name/, fn ->
      test_project()
      |> Igniter.compose_task("polaris.add", [])
    end
  end

  test "--list prints the catalog without changing anything" do
    test_project()
    |> Igniter.compose_task("polaris.add", ["--list"])
    |> assert_unchanged()
  end
end
