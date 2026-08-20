defmodule PolarisUI.Components.ButtonTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Button` — every attribute,
  slot, and event passthrough, plus all interactive states. Styling follows
  the Supabase design system button (`packages/ui`) 1:1: muted brand fills
  with brand borders, 26–50px size scale, per-variant icon/spinner tints.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Button

  describe "variants" do
    test "default renders the panel surface with a strong border (the workhorse)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button>Create table</.button>
        """)

      assert html =~ "<button"
      assert html =~ "Create table"
      assert html =~ "bg-surface-panel"
      assert html =~ "border-surface-border"
      assert html =~ "text-content-primary"
      assert html =~ "hover:bg-surface-panel-hover"
      refute html =~ "bg-brand-fill"
    end

    test "primary is the muted emerald fill with brand border and bright accents" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="primary">Start your project</.button>
        """)

      # muted fill, not the bright emerald — that is reserved for accents
      assert html =~ "bg-brand-fill"
      assert html =~ "text-content-primary"
      assert html =~ "border-brand-border"
      assert html =~ "hover:bg-brand-fill-hover"
      assert html =~ "hover:border-brand-border-hover"
      refute html =~ "bg-brand-emerald "
    end

    test "secondary inverts: bright fill with dark text" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="secondary">Save changes</.button>
        """)

      assert html =~ "bg-content-primary"
      assert html =~ "text-surface-ground"
    end

    test "warning is the amber tint fill with amber border" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="warning">Transfer ownership</.button>
        """)

      assert html =~ "bg-warning-fill"
      assert html =~ "border-warning-border"
      assert html =~ "hover:border-warning-border-hover"
    end

    test "danger is the red tint fill with red border for destructive operations" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="danger">Delete project</.button>
        """)

      assert html =~ "bg-danger-fill"
      assert html =~ "border-danger-border"
      assert html =~ "hover:bg-danger-fill-hover"
      assert html =~ "hover:border-danger-border-hover"
    end

    test "outline is transparent with a strong border and no hover fill" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="outline">View logs</.button>
        """)

      assert html =~ "bg-transparent"
      assert html =~ "border-surface-border"
      assert html =~ "hover:border-content-secondary"
      refute html =~ "hover:bg-"
    end

    test "ghost is transparent until hover" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="ghost">Dismiss</.button>
        """)

      assert html =~ "bg-transparent"
      assert html =~ "text-content-primary"
      assert html =~ "hover:bg-content-primary/10"
    end

    test "link keeps button chrome: emerald text filling deep emerald on hover" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="link">Read the docs</.button>
        """)

      assert html =~ "text-brand-accent"
      assert html =~ "hover:bg-brand-deep"
      # it stays a button-shaped control, not underlined text
      assert html =~ "h-[38px]"
      refute html =~ "underline"
    end

    test "rejects an unknown variant" do
      assigns = %{bad: "sparkly"}

      assert_raise ArgumentError, ~r/:variant/, fn ->
        rendered_to_string(~H"""
        <.button variant={@bad}>Nope</.button>
        """)
      end
    end
  end

  describe "sizes" do
    @expectations %{
      "tiny" => {"h-[26px]", "px-2.5"},
      "small" => {"h-[34px]", "px-3"},
      "medium" => {"h-[38px]", "px-4"},
      "large" => {"h-[42px]", "px-4"},
      "huge" => {"h-[50px]", "px-6"}
    }

    test "every size mirrors the Supabase heights and svg auto-sizing" do
      for {size, {height, padding}} <- @expectations do
        assigns = %{size: size}

        html =
          rendered_to_string(~H"""
          <.button size={@size}>Deploy</.button>
          """)

        assert html =~ height, "expected #{height} for size #{size}"
        assert html =~ padding, "expected #{padding} for size #{size}"
        # svg auto-sizing (rendered escaped: `[&amp;_svg]:size-*`)
        assert html =~ "_svg]:size-"
      end
    end

    test "defaults to medium and scales text with size" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button>Deploy</.button>
        """)

      assert html =~ "h-[38px]"
      assert html =~ "text-sm"

      assigns = %{}

      large =
        rendered_to_string(~H"""
        <.button size="large">Deploy</.button>
        """)

      assert large =~ "text-base"
    end

    test "rejects an unknown size" do
      assigns = %{bad: "gargantuan"}

      assert_raise ArgumentError, ~r/:size/, fn ->
        rendered_to_string(~H"""
        <.button size={@bad}>Nope</.button>
        """)
      end
    end
  end

  describe "loading state" do
    test "shows the tinted spinner, sets aria-busy, and locks like disabled" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button loading>Deploy project</.button>
        """)

      assert html =~ ~s{aria-busy="true"}
      assert html =~ " disabled"
      assert html =~ "data-polaris-spinner"
      assert html =~ "animate-spin"
      # disabled semantics, exactly like the Supabase component
      assert html =~ "pointer-events-none"
      assert html =~ "opacity-50"
      # the label stays visible for layout stability
      assert html =~ "Deploy project"
    end

    test "spinner replaces the leading icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button loading>
          <:icon><svg data-icon="rocket" /></:icon>
          Deploy project
        </.button>
        """)

      assert html =~ "data-polaris-spinner"
      refute html =~ ~s{data-icon="rocket"}
    end

    test "spinner tint follows the variant" do
      assigns = %{}

      default =
        rendered_to_string(~H"""
        <.button loading>Deploy</.button>
        """)

      assert default =~ "text-content-secondary"

      assigns = %{}

      primary =
        rendered_to_string(~H"""
        <.button variant="primary" loading>Deploy</.button>
        """)

      assert primary =~ "text-brand-accent"

      assigns = %{}

      danger =
        rendered_to_string(~H"""
        <.button variant="danger" loading>Deploy</.button>
        """)

      assert danger =~ "text-danger"
    end

    test "spinner is hidden from assistive tech" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button loading>Deploy project</.button>
        """)

      assert html =~ ~s{aria-hidden="true"}
    end
  end

  describe "disabled state" do
    test "dims, disables pointer events, and drops out of the tab order" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button disabled>Delete project</.button>
        """)

      assert html =~ " disabled"
      assert html =~ "opacity-50"
      assert html =~ "cursor-not-allowed"
      assert html =~ "pointer-events-none"
      assert html =~ ~s{tabindex="-1"}
      refute html =~ "aria-busy"
    end

    test "a caller-provided tabindex always wins" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button disabled tabindex="0">Delete project</.button>
        """)

      assert html =~ ~s{tabindex="0"}
      refute html =~ ~s{tabindex="-1"}
    end
  end

  describe "focus-ring" do
    test "every variant carries the high-visibility focus-visible ring" do
      for variant <- ~w(primary default secondary warning danger outline ghost link) do
        assigns = %{variant: variant}

        html =
          rendered_to_string(~H"""
          <.button variant={@variant}>Focus me</.button>
          """)

        assert html =~ "focus-visible:ring-2", "missing ring for #{variant}"
        assert html =~ "focus-visible:ring-brand-emerald", "missing ring color for #{variant}"
        assert html =~ "focus-visible:ring-offset-2", "missing ring offset for #{variant}"

        assert html =~ "focus-visible:ring-offset-surface-ground",
               "missing offset color for #{variant}"
      end
    end
  end

  describe "slots" do
    test "renders leading icon, label, and trailing icon in order" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button>
          <:icon><svg data-icon="plus" /></:icon>
          Create table
          <:icon_right><svg data-icon="chevron-right" /></:icon_right>
        </.button>
        """)

      lead = position(html, ~s{data-icon="plus"})
      label = position(html, "Create table")
      trail = position(html, ~s{data-icon="chevron-right"})

      assert is_integer(lead) and is_integer(label) and is_integer(trail)
      assert lead < label and label < trail
    end

    test "icon_left is an accepted alias for the leading icon slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button>
          <:icon_left><svg data-icon="plus" /></:icon_left>
          Create table
        </.button>
        """)

      label = position(html, "Create table")
      lead = position(html, ~s{data-icon="plus"})

      assert is_integer(lead) and is_integer(label) and lead < label
    end

    test "icons are tinted per variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="primary">
          <:icon><svg data-icon="plus" /></:icon>
          Create table
        </.button>
        """)

      assert html =~ "text-brand-accent"
    end

    test "icon-only buttons render square and require an accessible name" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button aria-label="Close dialog"><:icon><svg data-icon="x" /></:icon></.button>
        """)

      assert html =~ ~s{aria-label="Close dialog"}
      assert html =~ ~s{data-icon="x"}
      assert html =~ "aspect-square"
      assert html =~ "p-0"
      refute html =~ "px-4"

      assert_raise ArgumentError, ~r/aria-label/, fn ->
        assigns = %{}

        rendered_to_string(~H"""
        <.button><:icon><svg data-icon="x" /></:icon></.button>
        """)
      end
    end
  end

  describe "link buttons (href)" do
    test "renders an anchor with the same variant classes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="primary" href="/new">Start your project</.button>
        """)

      assert html =~ "<a"
      assert html =~ ~s{href="/new"}
      assert html =~ "bg-brand-fill"
      refute html =~ "<button"
      # type is meaningless on anchors — must not leak through
      refute html =~ ~s{type="button"}
    end

    test "disabled anchors carry aria-disabled and disable pointer events" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button href="/new" disabled>Start your project</.button>
        """)

      assert html =~ ~s{aria-disabled="true"}
      assert html =~ "pointer-events-none"
      assert html =~ "opacity-50"
      # anchors have no native disabled attribute
      refute html =~ " disabled"
    end
  end

  describe "attributes and events" do
    test "renders the given html type" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button type="submit">Save changes</.button>
        """)

      assert html =~ ~s{type="submit"}
    end

    test "forwards global attributes and phx events via rest" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button data-testid="deploy" phx-click="deploy" name="action">Deploy project</.button>
        """)

      assert html =~ ~s{data-testid="deploy"}
      assert html =~ ~s{phx-click="deploy"}
      assert html =~ ~s{name="action"}
    end

    test "caller classes win over defaults through cn/1" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button class="bg-surface-base">Create table</.button>
        """)

      assert html =~ "bg-surface-base"
      # word-boundary refute: `hover:bg-surface-panel-hover` also contains the substring
      refute html =~ " bg-surface-panel " || html =~ " bg-surface-panel\""
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      for variant <- ~w(primary default secondary warning danger outline ghost link) do
        assigns = %{variant: variant}

        html =
          rendered_to_string(~H"""
          <.button variant={@variant} class="w-full">Any action</.button>
          """)

        refute html =~ "#[", "arbitrary-value class leaked for #{variant}"
      end
    end
  end

  # First byte offset of `pattern` in `html`, or nil — for ordering checks.
  defp position(html, pattern) do
    case :binary.match(html, pattern) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end
end
