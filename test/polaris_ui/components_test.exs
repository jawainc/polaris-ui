defmodule PolarisUI.ComponentsTest do
  use ExUnit.Case, async: true

  alias PolarisUI.Components

  test "list/0 returns sorted entries with module and source metadata" do
    entries = Components.list()

    names = Enum.map(entries, & &1.name)
    assert names == Enum.sort(names)

    for entry <- entries do
      assert entry.module == Module.concat([PolarisUI.Components, Macro.camelize(entry.name)])
      assert entry.source == "lib/polaris_ui/components/#{entry.name}.ex"
    end
  end

  test "fetch/1 accepts underscore, camelized, and atom names" do
    for entry <- Components.list() do
      expected = entry.name

      assert %{name: ^expected} = Components.fetch(expected)
      assert %{name: ^expected} = Components.fetch(Macro.camelize(expected))
      assert %{name: ^expected} = Components.fetch(String.to_atom(expected))
    end
  end

  test "fetch/1 returns nil for unknown components" do
    refute Components.fetch("definitely_not_a_polaris_component")
  end
end
