defmodule PolarisUI.TokensTest do
  use ExUnit.Case, async: true

  alias PolarisUI.Tokens

  @source Tokens.source()

  defp theme_block, do: extract_block(@source, "@theme {")
  defp light_block, do: extract_block(@source, ".polaris-light {")

  defp extract_block(source, opener) do
    [_, rest] = :binary.split(source, opener)
    [block, _] = :binary.split(rest, "}")
    block
  end

  defp vars(block), do: Regex.scan(~r/--color-[\w-]+/, block) |> Enum.map(&List.first/1)

  test "defines the core Polaris palette from the architecture plan" do
    for token <- [
          "--color-brand-emerald",
          "--color-surface-ground",
          "--color-surface-base",
          "--color-surface-panel",
          "--color-surface-border",
          "--color-surface-border-hover"
        ] do
      assert token in vars(theme_block()), "expected #{token} in @theme"
    end
  end

  test "defines the signature brand emerald with the planned value" do
    assert theme_block() =~ ~s{--color-brand-emerald: #3ecf8e;}
  end

  test "declares monospaced and sans font stacks" do
    assert theme_block() =~ ~s{--font-mono:}
    assert theme_block() =~ "JetBrains Mono"
    assert theme_block() =~ ~s{--font-sans:}
  end

  test "every surface and content token has a light-mode override" do
    theme_vars = vars(theme_block()) |> MapSet.new()
    light_vars = vars(light_block()) |> MapSet.new()

    themable =
      theme_vars
      |> Enum.filter(&String.starts_with?(&1, ["--color-surface", "--color-content"]))
      |> MapSet.new()

    # Brand/status accents are theme-invariant by design (only muted tints
    # need adjusting), but surfaces and text must fully flip.
    missing = MapSet.difference(themable, light_vars)

    assert MapSet.size(missing) == 0,
           "expected light overrides for #{inspect(MapSet.to_list(missing))}"
  end

  test "provides the .polaris base scope class" do
    assert @source =~ ".polaris {"
    assert @source =~ "var(--color-surface-ground)"
  end

  test "wraps the injected block in idempotency markers" do
    assert @source =~ "#{Tokens.marker()}:start"
    assert @source =~ "#{Tokens.marker()}:end"
  end
end
