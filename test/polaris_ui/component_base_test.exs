defmodule PolarisUI.ComponentBaseTest do
  @moduledoc """
  Smoke test for the component authoring base: `use PolarisUI.Component`,
  `cn/1` merging, and standalone rendering through `Phoenix.LiveViewTest`.

  This is the harness future component sessions will build on — real
  components get their own files under `test/polaris_ui/components/`.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  defmodule Pill do
    use PolarisUI.Component

    attr(:label, :string, required: true)
    attr(:class, :string, default: nil)
    attr(:rest, :global, doc: "forwarded to the span")

    def pill(assigns) do
      ~H"""
      <span
        class={
          cn([
            "inline-flex items-center rounded-md border border-surface-border",
            "bg-surface-panel px-2 py-1 font-mono text-xs text-content-secondary",
            @class
          ])
        }
        {@rest}
      >
        {@label}
      </span>
      """
    end
  end

  test "renders a component with its default token classes" do
    html = render(&Pill.pill/1, %{label: "users.id"})

    assert html =~ "users.id"
    assert html =~ "border-surface-border"
    assert html =~ "bg-surface-panel"
    assert html =~ "font-mono"
    assert html =~ "px-2 py-1"
  end

  test "caller class overrides win through cn/1" do
    html = render(&Pill.pill/1, %{label: "rowid", class: "px-4 bg-surface-base"})

    assert html =~ "px-4"
    assert html =~ "bg-surface-base"
    refute html =~ "px-2"
    refute html =~ "bg-surface-panel"
  end

  test "global attributes are forwarded" do
    html = render(&Pill.pill/1, %{label: "ok", "data-testid": "pill"})

    assert html =~ ~s{data-testid="pill"}
  end

  defp render(fun, assigns) do
    case render_component(fun, assigns) do
      {:safe, iodata} -> IO.iodata_to_binary(iodata)
      binary when is_binary(binary) -> binary
    end
  end
end
