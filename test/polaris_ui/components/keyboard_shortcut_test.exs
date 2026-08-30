defmodule PolarisUI.Components.KeyboardShortcutTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.KeyboardShortcut` —
  the port of the Supabase design system KeyboardShortcut: the compact,
  platform-aware shortcut label.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.KeyboardShortcut

  @hook "PolarisUI.Components.KeyboardShortcut.Root"

  defp render_shortcut(assigns) do
    assigns =
      Map.merge(
        %{keys: ["Meta", "K"], variant: "pill", platform: nil, class: nil, rest: %{}},
        assigns
      )

    rendered_to_string(~H"""
    <.keyboard_shortcut
      keys={@keys}
      variant={@variant}
      platform={@platform}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "glyph resolution" do
    test "renders compact mac-style shortcuts for symbol and single-character keys" do
      html = render_shortcut(%{keys: ["Meta", "K"]})

      assert html =~ ~s{data-resolved="⌘K"}
      assert html =~ ">⌘K</span>"
    end

    test "renders arrow keys as symbols" do
      html = render_shortcut(%{keys: ["ArrowUp"]})

      assert html =~ ">↑</span>"
    end

    test "multi-key symbol combos stay compact (⇧⌘M)" do
      html = render_shortcut(%{keys: ["Shift", "Meta", "M"]})

      assert html =~ ">⇧⌘M</span>"
    end

    test "keeps word-style non-mac shortcuts readable (Ctrl ↑)" do
      html = render_shortcut(%{keys: ["Meta", "ArrowUp"]})

      assert html =~ ~s{data-alt="Ctrl ↑"}
    end

    test "single-character keys are uppercased automatically" do
      html = render_shortcut(%{keys: ["k"]})

      assert html =~ ">K</span>"
    end

    test "Esc, Escape, and Tab stay literal — the least surprising glyphs" do
      assert render_shortcut(%{keys: ["Escape"]}) =~ ">Esc</span>"
      assert render_shortcut(%{keys: ["Esc"]}) =~ ">Esc</span>"
      assert render_shortcut(%{keys: ["Tab"]}) =~ ">Tab</span>"
    end

    test "unknown keys fall through as themselves" do
      html = render_shortcut(%{keys: ["F5"]})

      assert html =~ ">F5</span>"
    end
  end

  describe "variants" do
    test "pill is the default — the bordered chip" do
      html = render_shortcut(%{})

      assert html =~ ~s{data-variant="pill"}
      pill = marker_class(html, "data-polaris-keyboard-shortcut")

      assert pill =~ "data-[variant=pill]:border data-[variant=pill]:border-surface-border"
      assert pill =~ "data-[variant=pill]:bg-surface-panel/50"
      assert pill =~ "data-[variant=pill]:px-[5px] data-[variant=pill]:py-[3px]"
      assert pill =~ "data-[variant=pill]:text-[11px]"
      assert pill =~ "data-[variant=pill]:text-content-secondary"
    end

    test "inline is the quiet text treatment for helper copy" do
      html = render_shortcut(%{variant: "inline"})

      assert html =~ ~s{data-variant="inline"}

      inline = marker_class(html, "data-polaris-keyboard-shortcut")

      assert inline =~ "data-[variant=inline]:text-[11px] data-[variant=inline]:leading-[inherit]"
      assert inline =~ "data-[variant=inline]:text-content-primary/40"
    end

    test "rejects unknown variants" do
      assert_raise ArgumentError, ~r/:variant/, fn -> render_shortcut(%{variant: "chip"}) end
    end
  end

  describe "platform" do
    test "default resolves client-side: mac glyphs server-side plus the swap hook" do
      html = render_shortcut(%{})

      assert html =~ ~s{data-resolved="⌘K"}
      assert html =~ ~s{data-alt="Ctrl K"}
      assert html =~ ~s{phx-hook="#{@hook}"}
    end

    test "platform=mac pins the mac glyphs — no hook, no alt label" do
      html = render_shortcut(%{platform: "mac"})

      assert html =~ ">⌘K</span>"
      refute html =~ ~s{data-alt=}
      refute html =~ ~s{phx-hook}
    end

    test "platform=other pins the non-mac glyphs — no hook" do
      html = render_shortcut(%{platform: "other", keys: ["Meta", "ArrowUp"]})

      assert html =~ ">Ctrl ↑</span>"
      refute html =~ ~s{phx-hook}
    end

    test "rejects unknown platforms" do
      assert_raise ArgumentError, ~r/:platform/, fn -> render_shortcut(%{platform: "linux"}) end
    end
  end

  describe "colocated hook" do
    test "ships its script inline with the runtime hook markers" do
      html = render_shortcut(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook swaps in the non-mac label only when it differs" do
      html = render_shortcut(%{})

      assert html =~ "el.dataset.alt !== el.dataset.resolved"
      assert html =~ "el.textContent = el.dataset.alt"
    end

    test "hook elements always carry a DOM id — caller's wins" do
      html = render_shortcut(%{rest: %{"id" => "save-shortcut"}})

      assert html =~ ~s{id="save-shortcut"}
    end

    test "a random id is generated when the caller passes none" do
      html = render_shortcut(%{})

      assert html =~ ~s{id="phx-}
    end
  end

  describe "customization" do
    test "merges the caller's class and forwards global attributes" do
      html = render_shortcut(%{class: "ml-3", rest: %{"data-testid" => "ks"}})

      assert marker_class(html, "data-polaris-keyboard-shortcut") =~ "ml-3"
      assert html =~ ~s{data-testid="ks"}
    end

    test "never hardcodes raw hex values" do
      refute render_shortcut(%{}) =~ "#[", "arbitrary-value class leaked"
    end
  end

  # The class attribute of the element carrying the given marker.
  defp marker_class(html, marker) do
    [_, after_marker | _] = String.split(html, marker, parts: 2)

    class =
      case :binary.match(after_marker, ~s{class="}) do
        {index, _} -> binary_part(after_marker, index + 7, byte_size(after_marker) - index - 7)
        :nomatch -> ""
      end

    class |> String.split(~s{"}) |> List.first()
  end
end
