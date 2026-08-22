defmodule PolarisUI.Components.DataInputTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.DataInput` — anatomy,
  sizes, copy/reveal succession, states, slots, hook, and accessibility
  behavior, mirroring the Supabase design system fragment
  `ui-patterns/DataInputs/Input` 1:1: a chrome-owning group shell around a
  transparent control, with inline-start/end addons for icon, copy, reveal,
  and caller actions.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.DataInput

  @hook "PolarisUI.Components.DataInput.Input"

  describe "anatomy" do
    test "renders a labelled group shell around the transparent control" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="sb_secret_123" />
        """)

      assert html =~ ~s{id="key"}
      assert html =~ ~s{id="key-input"}
      assert html =~ ~s{role="group"}
      assert html =~ ~s{data-polaris-data-input}
      assert html =~ ~s{data-polaris-control}
      assert html =~ ~s{value="sb_secret_123"}
    end

    test "the shell owns the chrome; the control stays visually transparent" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="x" />
        """)

      shell = shell_class(html)

      assert shell =~ "rounded-md"
      assert shell =~ "border-surface-border"
      assert shell =~ "bg-surface-panel"
      assert shell =~ "transition-colors"

      control = control_class(html)

      assert control =~ "bg-transparent"
      assert control =~ "flex-1"
      assert control =~ "focus:outline-none"
    end

    test "suppresses password managers on the control like the fragment" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="x" />
        """)

      assert html =~ "data-1p-ignore"
      assert html =~ ~s{data-lpignore="true"}
      assert html =~ ~s{data-form-type="other"}
      assert html =~ "data-bwignore"
    end

    test "no hook or script without copy/reveal — a plain field stays JS-free" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="x" />
        """)

      refute html =~ "phx-hook="
      refute html =~ "data-phx-runtime-hook"
      refute html =~ "<script"
    end

    test "an id is not required for plain fields" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input name="api_key" value="x" />
        """)

      assert html =~ ~s{name="api_key"}
      refute html =~ "phx-hook="
    end
  end

  describe "sizes" do
    test "maps every Supabase input size" do
      sizes = %{
        "tiny" => "h-[26px]",
        "small" => "h-[34px]",
        "medium" => "h-[38px]",
        "large" => "h-[42px]",
        "xlarge" => "h-[50px]"
      }

      for {size, height} <- sizes do
        assigns = %{size: size}

        html =
          rendered_to_string(~H"""
          <.data_input id="a" size={@size} />
          """)

        assert control_class(html) =~ height, "missing #{height} for size #{size}"
      end
    end

    test "small is the default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" />
        """)

      assert control_class(html) =~ "h-[34px]"
    end

    test "rejects an unknown size" do
      assigns = %{bad: "gigantic"}

      assert_raise ArgumentError, ~r/:size/, fn ->
        rendered_to_string(~H"""
        <.data_input id="a" size={@bad} />
        """)
      end
    end

    test "rejects an unknown type" do
      assigns = %{bad: "color"}

      assert_raise ArgumentError, ~r/:type/, fn ->
        rendered_to_string(~H"""
        <.data_input id="a" type={@bad} />
        """)
      end
    end
  end

  describe "copy" do
    test "renders the Copy button with the lucide copy glyph and label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="1234567890" readonly copy />
        """)

      assert html =~ ~s{data-polaris-copy}
      assert html =~ ~s{data-polaris-copy-label}
      assert html =~ ">Copy</span>"
      # the lucide copy glyph (rect + trailing path)
      assert html =~ ~s{<rect width="14" height="14" x="8" y="8" rx="2" ry="2"}
      assert html =~ ~s{d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"}
    end

    test "copy requires an id and raises without one" do
      assigns = %{}

      assert_raise ArgumentError, ~r/need an id/, fn ->
        rendered_to_string(~H"""
        <.data_input value="x" copy />
        """)
      end
    end

    test "the clipboard payload rides along as data-copy-value" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input
          id="key"
          value="sb_secret_123•••••••"
          copy_value="sb_secret_1234567890"
          copy
        />
        """)

      assert html =~ ~s{data-copy-value="sb_secret_1234567890"}
      assert html =~ ~s{value="sb_secret_123•••••••"}
    end

    test "show_copy_on_hover fades the button in on shell hover" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="x" copy show_copy_on_hover />
        """)

      assert html =~ "opacity-0"
      assert html =~ "group-hover:opacity-100"
    end

    test "the copy event travels as data-copy-event for the hook to push" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="x" copy on_copy="key-copied" />
        """)

      assert html =~ ~s{data-copy-event="key-copied"}
    end
  end

  describe "reveal" do
    test "reveal requires an id and raises without one" do
      assigns = %{}

      assert_raise ArgumentError, ~r/need an id/, fn ->
        rendered_to_string(~H"""
        <.data_input value="x" reveal />
        """)
      end
    end

    test "masks as password with the real type carried for the hook" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="hunter2" reveal />
        """)

      assert html =~ ~s{type="password"}
      assert html =~ ~s{data-reveal-type="text"}
      assert html =~ ~s{data-polaris-reveal}
      assert html =~ ~r{>\s*Reveal\s*</span>}
      # no Copy button in the DOM (the hook script mentions the selector only)
      refute html =~ "data-polaris-copy>"
    end

    test "copy + reveal render in succession: Copy hidden until revealed" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="1234567890" readonly reveal copy />
        """)

      copy_at = position(html, "data-polaris-copy")
      reveal_at = position(html, "data-polaris-reveal")

      assert is_integer(copy_at) and is_integer(reveal_at)
      # both buttons exist; Copy starts hidden behind the reveal gate
      assert html =~ " hidden"
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook and ships its script when features demand it" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="x" copy />
        """)

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook drives select-on-focus, one-way reveal, and clipboard copy" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="key" value="x" reveal copy on_copy="copied" copy_value="real" />
        """)

      assert html =~ "input.select()"
      assert html =~ ~s{input.dataset.copyValue || input.value}
      assert html =~ "revealBtn.hidden = true"
      assert html =~ "copyBtn.hidden = false"
      assert html =~ ~s{copyLabel.textContent = "Copied"}
      assert html =~ "3000"
      assert html =~ "navigator.clipboard.writeText"
      assert html =~ "pushEvent"
    end
  end

  describe "states" do
    test "hover brightens the shell border" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" />
        """)

      assert shell_class(html) =~ "hover:border-surface-border-hover"
    end

    test "focus-visible on the control rings the shell, not the control" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" />
        """)

      shell = shell_class(html)

      assert shell =~ "has-[input:focus-visible]:ring-2"
      assert shell =~ "has-[input:focus-visible]:ring-brand-emerald"
      assert shell =~ "has-[input:focus-visible]:ring-offset-2"
    end

    test "aria-invalid tints the shell red through :has()" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" aria-invalid="true" />
        """)

      shell = shell_class(html)

      assert shell =~ "has-[input[aria-invalid=true]]:border-danger-border"
      assert shell =~ "has-[input[aria-invalid=true]]:bg-danger-muted"
      assert html =~ ~s{aria-invalid="true"}
    end

    test "disabled disables the control and dims the shell" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" disabled />
        """)

      assert html =~ " disabled"
      assert shell_class(html) =~ "has-[input:disabled]:cursor-not-allowed"
      assert control_class(html) =~ "disabled:text-content-muted"
    end

    test "readonly settles the shell border and brightens the control text" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" readonly />
        """)

      assert html =~ " readonly" || html =~ ~s{readonly=""}
      assert shell_class(html) =~ "has-[input:read-only]:border-surface-border"
      assert control_class(html) =~ "read-only:text-content-secondary"
    end
  end

  describe "slots" do
    test "the icon slot renders in the inline-start addon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" placeholder="https://your-org.okta.com">
          <:icon><svg data-icon="globe" /></:icon>
        </.data_input>
        """)

      assert html =~ ~s{data-icon="globe"}
      assert html =~ "order-first"
      assert html =~ "pl-2"
    end

    test "the actions slot renders after copy/reveal in the inline-end addon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" copy>
          <:actions><button data-testid="regenerate">Regenerate key</button></:actions>
        </.data_input>
        """)

      copy_at = position(html, "data-polaris-copy")
      actions_at = position(html, "data-testid=\"regenerate\"")

      assert is_integer(copy_at) and is_integer(actions_at) and copy_at < actions_at
      assert html =~ "order-last"
    end
  end

  describe "attributes and events" do
    test "forwards control attributes and phx events via rest" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" phx-blur="save-key" aria-describedby="key-hint" form="key-form" />
        """)

      assert html =~ ~s{phx-blur="save-key"}
      assert html =~ ~s{aria-describedby="key-hint"}
      assert html =~ ~s{form="key-form"}
    end

    test "caller classes merge onto the shell through cn/1" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" class="max-w-sm bg-surface-base" />
        """)

      shell = shell_class(html)

      assert shell =~ "max-w-sm"
      assert shell =~ "bg-surface-base"
      refute shell =~ "bg-surface-panel"
    end

    test "placeholder passes through for partial truncation" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" value="sb_secret_1234567890abcdefghij" placeholder="sb_secret_1234…" />
        """)

      assert html =~ ~s{placeholder="sb_secret_1234…"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.data_input id="a" value="x" reveal copy aria-invalid="true" />
        """)

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  # First byte offset of `pattern` in `html`, or nil — for ordering checks.
  defp position(html, pattern) do
    case :binary.match(html, pattern) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  # The class attribute of the group shell (first class= in the output).
  defp shell_class(html) do
    [_, class | _] = String.split(html, ~s{class="}, parts: 2)
    class |> String.split(~s{"}) |> List.first()
  end

  # The class attribute of the inner control (the input's class=).
  defp control_class(html) do
    [_, rest] = String.split(html, "<input", parts: 2)
    [_, class | _] = String.split(rest, ~s{class="}, parts: 2)
    class |> String.split(~s{"}) |> List.first()
  end
end
