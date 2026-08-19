defmodule PolarisUI.Component do
  @moduledoc """
  Sets up a module for defining Polaris UI function components.

      defmodule MyAppWeb.Components.UI.Button do
        use PolarisUI.Component

        attr :variant, :string, default: "primary"

        def button(assigns) do
          ~H\"\"\"
          <button class={cn(["btn", @variant])}>{@label}</button>
          \"\"\"
        end
      end

  `use PolarisUI.Component` brings in:

    * everything from `use Phoenix.Component` — `attr/2,3`, `slot/1,2`,
      `assign/3`, the `~H` sigil, and friends.
    * `cn/1` from `PolarisUI.Utils` — the Tailwind-aware class merger used to
      merge default classes with the caller's `class` attribute.

  This module is provided by the `polaris_ui` engine dependency; it stays
  available even after component sources are copied into your application via
  `mix polaris.add`, so copied components keep working unmodified.
  """

  defmacro __using__(_opts) do
    quote do
      use Phoenix.Component
      import PolarisUI.Utils, only: [cn: 1]
    end
  end
end
