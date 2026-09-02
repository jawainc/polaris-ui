defmodule PolarisUI.Components.ToggleGroupTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.ToggleGroup` — the
  port of the Supabase design system ToggleGroup family (shadcn over
  Radix): the `role="group"` container with its shared variant/size
  context, the `aria-pressed` items, the single/multiple selection
  seeds, and the colocated runtime hook owning the toggle (not radio)
  state machine with roving keyboard.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.ToggleGroup

  @hook "PolarisUI.Components.ToggleGroup.Root"

  defp render_group(assigns) do
    assigns =
      Map.merge(
        %{
          id: "alignment",
          type: "single",
          value: nil,
          variant: "default",
          size: "default",
          on_change: "set-alignment",
          class: nil,
          rest: %{},
          left_checked: false,
          center_checked: false,
          right_checked: false
        },
        assigns
      )

    rendered_to_string(~H"""
    <.toggle_group
      id={@id}
      type={@type}
      value={@value}
      variant={@variant}
      size={@size}
      on_change={@on_change}
      class={@class}
      {assigns[:rest]}
    >
      <.toggle_group_item value="left" checked={@left_checked}>Left</.toggle_group_item>
      <.toggle_group_item value="center" checked={@center_checked}>Center</.toggle_group_item>
      <.toggle_group_item value="right" checked={@right_checked}>Right</.toggle_group_item>
    </.toggle_group>
    """)
  end

  describe "root anatomy" do
    test "renders the role=group container anchored by the hook" do
      html = render_group(%{})

      assert html =~ ~s{id="alignment"}
      assert html =~ ~s{role="group"}
      assert html =~ ~s{data-polaris-toggle-group}
      assert html =~ ~s{phx-hook="#{@hook}"}
    end

    test "the group uses the source's joined container" do
      html = render_group(%{})

      assert group_class(html) =~ "flex items-center justify-center gap-1"
    end

    test "the type, variant, size, and event ride the dataset" do
      html = render_group(%{})

      assert html =~ ~s{data-type="single"}
      assert html =~ ~s{data-variant="default"}
      assert html =~ ~s{data-size="default"}
      assert html =~ ~s{data-change-event="set-alignment"}
    end

    test "omit the dataset entries when no event is set" do
      html = render_group(%{on_change: nil})

      refute html =~ "data-change-event="
    end

    test "caller classes merge onto the group" do
      html = render_group(%{class: "flex-wrap"})

      assert group_class(html) =~ "flex-wrap"
    end

    test "globals forward through rest" do
      html = render_group(%{rest: %{"aria-label" => "Text alignment", "data-testid" => "align"}})

      assert html =~ ~s{aria-label="Text alignment"}
      assert html =~ ~s{data-testid="align"}
    end
  end

  describe "items" do
    test "real aria-pressed buttons carrying their value" do
      html = render_group(%{})

      # Trailing space: the root's data-polaris-toggle-group and the
      # hook's [data-polaris-toggle-group-item] selectors must not count.
      assert count(html, ~s{data-polaris-toggle-group-item }) == 3
      item = item_chunk(html, "left")
      assert item =~ ~s{aria-pressed="false"}
      assert item =~ ~s{data-value="left"}
      assert item =~ ~s{data-state="off"}
      assert item =~ ~s{data-checked="false"}
      assert html =~ "Left"
    end

    test "items carry the toggle's ghost vocabulary" do
      html = render_group(%{})

      class = item_class(html, "left")

      assert class =~
               "inline-flex items-center justify-center gap-1 rounded-md text-sm font-medium"

      assert class =~
               "transition-colors text-content-secondary hover:text-content-primary hover:bg-surface-muted"

      assert class =~ "bg-transparent py-1 h-10 px-3"
      assert class =~ "data-[state=on]:bg-surface-muted data-[state=on]:text-content-primary"

      assert class =~
               "aria-[pressed=true]:bg-surface-muted aria-[pressed=true]:text-content-primary"
    end

    test "outline and non-default sizes gate on the item's dataset" do
      html = render_group(%{})

      class = item_class(html, "left")
      assert class =~ "data-[variant=outline]:border data-[variant=outline]:border-surface-border"
      assert class =~ "data-[size=tiny]:h-[26px] data-[size=tiny]:px-2.5 data-[size=tiny]:text-xs"
      assert class =~ "data-[size=sm]:h-[34px] data-[size=sm]:px-2.5"
      assert class =~ "data-[size=lg]:h-11 data-[size=lg]:px-5"
    end

    test "the group's variant and size seed the item dataset" do
      html = render_group(%{variant: "outline", size: "sm"})

      assert html =~ ~s{data-variant="outline"}
      assert html =~ ~s{data-size="sm"}
    end

    test "per-item variant/size lock against the group's shared values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.toggle_group id="mixed" variant="outline" size="lg">
          <.toggle_group_item value="a" variant="default" size="tiny">A</.toggle_group_item>
          <.toggle_group_item value="b">B</.toggle_group_item>
        </.toggle_group>
        """)

      a = item_chunk(html, "a")
      assert a =~ ~s{data-variant="default"}
      assert a =~ ~s{data-size="tiny"}
      assert a =~ ~s{data-variant-locked="true"}
      assert a =~ ~s{data-size-locked="true"}

      b = item_chunk(html, "b")
      # SSR falls back to the base look; the hook flows the group's
      # outline/lg in from mount (asserted in the hook describe).
      assert b =~ ~s{data-variant="default"}
      assert b =~ ~s{data-size="default"}
      refute b =~ "data-variant-locked"
      refute b =~ "data-size-locked"
    end

    test "items take the focus-ring and disabled treatments" do
      html = render_group(%{})

      class = item_class(html, "left")

      assert class =~
               "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-emerald"

      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
      assert class =~ "disabled:pointer-events-none disabled:opacity-50"
    end

    test "disabled items lock and drop from the tab order" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.toggle_group id="alignment">
          <.toggle_group_item value="left">Left</.toggle_group_item>
          <.toggle_group_item value="center" disabled>Center</.toggle_group_item>
        </.toggle_group>
        """)

      center = item_chunk(html, "center")
      assert center =~ " disabled"
      assert center =~ ~s{data-disabled="true"}
      assert center =~ ~s{tabindex="-1"}
    end

    test "item classes and globals forward" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.toggle_group id="alignment">
          <.toggle_group_item value="left" class="font-mono" data-testid="align-left">
            Left
          </.toggle_group_item>
        </.toggle_group>
        """)

      assert item_class(html, "left") =~ "font-mono"
      assert html =~ ~s{data-testid="align-left"}
    end
  end

  describe "seeds" do
    test "the root value seeds single selection as one id" do
      html = render_group(%{value: "center"})

      # The seed rides the root dataset; the hook owns painting and the
      # tab stop from mount, so items still render the base SSR state.
      assert html =~ ~s{data-value="center"}
      assert item_chunk(html, "center") =~ ~s{tabindex="-1"}
    end

    test "a multiple value list seeds the set" do
      html = render_group(%{type: "multiple", value: ["left", "right"]})

      assert html =~ ~s{data-value="left,right"}
    end

    test "per-item checked paints the server-rendered HTML" do
      html = render_group(%{left_checked: true})

      left = item_chunk(html, "left")
      assert left =~ ~s{data-state="on"}
      assert left =~ ~s{data-checked="true"}
      assert left =~ ~s{aria-pressed="true"}
      assert left =~ ~s{tabindex="0"}
    end

    test "no data-value attribute without a seed" do
      html = render_group(%{})

      root = group_chunk(html)
      refute root =~ "data-value="
    end
  end

  describe "validation" do
    test "rejects types outside single/multiple" do
      assert_raise ArgumentError, ~r/invalid value for :type/, fn ->
        render_group(%{type: "range"})
      end
    end

    test "rejects invalid group variant and size" do
      assert_raise ArgumentError, ~r/invalid value for :variant/, fn ->
        render_group(%{variant: "solid"})
      end

      assert_raise ArgumentError, ~r/invalid value for :size/, fn ->
        render_group(%{size: "xl"})
      end
    end

    test "rejects invalid per-item variant and size" do
      assigns = %{}

      assert_raise ArgumentError, ~r/invalid value for :variant/, fn ->
        rendered_to_string(~H"""
        <.toggle_group id="alignment">
          <.toggle_group_item value="left" variant="ghost">Left</.toggle_group_item>
        </.toggle_group>
        """)
      end

      assert_raise ArgumentError, ~r/invalid value for :size/, fn ->
        rendered_to_string(~H"""
        <.toggle_group id="alignment">
          <.toggle_group_item value="left" size="2xl">Left</.toggle_group_item>
        </.toggle_group>
        """)
      end
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_group(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
      assert html =~ "updated()"
      assert html =~ "destroyed()"
    end

    test "seeds from per-item checked, falling back to the root value" do
      html = render_group(%{})

      assert html =~ ~s{el.dataset.checked === "true"}
      assert html =~ ~s{(root.dataset.value || "").split(",").filter(Boolean)}
    end

    test "single keeps at most one seeded value" do
      html = render_group(%{})

      assert html =~ ~s{this._multiple() ? seeded : seeded.slice(0, 1)}
    end

    test "toggle semantics: clicking the active item deactivates it" do
      html = render_group(%{})

      assert html =~
               ~s{this._values = on ? this._values.filter((v) => v !== value) : this._values.concat([value])}

      assert html =~ ~s{this._values = on ? [] : [value]}
    end

    test "applies state, roving tabindex, and the shared variant/size" do
      html = render_group(%{})

      assert html =~ ~s{el.dataset.state = on ? "on" : "off"}
      assert html =~ ~s{el.setAttribute("aria-pressed", on ? "true" : "false")}
      assert html =~ "el.tabIndex = el === tabstop ? 0 : -1"
      assert html =~ "if (!el.dataset.variantLocked) el.dataset.variant = root.dataset.variant"
      assert html =~ "if (!el.dataset.sizeLocked) el.dataset.size = root.dataset.size"
    end

    test "the roving tab stop is the first on item, else the first enabled" do
      html = render_group(%{})

      assert html =~
               ~s{enabled.find((el) => this._values.indexOf(el.dataset.value) !== -1) || enabled[0]}
    end

    test "pushes single as a scalar (null when cleared) and multiple as a list" do
      html = render_group(%{})

      assert html =~
               "this.pushEvent(name, this._multiple() ? { value: this._values } : { value: this._values[0] || null })"
    end

    test "clicks are delegated on the root so morphs never orphan them" do
      html = render_group(%{})

      assert html =~ ~s{root.addEventListener("click", this._onClick)}
      assert html =~ ~s{event.target.closest("[data-polaris-toggle-group-item]")}
    end

    test "keyboard contract: arrows wrap, Home/End jump, automatic activation" do
      html = render_group(%{})

      for key <- ~w(ArrowDown ArrowUp ArrowRight ArrowLeft Home End) do
        assert html =~ ~s{event.key === "#{key}"}
      end

      assert html =~ "this._activate(next)"
      assert html =~ "next.focus()"
      assert html =~ "move((index + 1) % enabled.length)"
      assert html =~ "move((index - 1 + enabled.length) % enabled.length)"
    end

    test "disabled items are skipped and stay out of the tab order" do
      html = render_group(%{})

      assert html =~
               ~s{this._enabled = () => this._items().filter((el) => el.dataset.disabled !== "true")}

      assert html =~ ~s{item.dataset.disabled === "true"}
    end

    test "re-applies state after LiveView patches" do
      html = render_group(%{})

      updated =
        html
        |> String.split("updated() {")
        |> Enum.at(1)
        |> String.split("destroyed")
        |> List.first()

      assert updated =~ "this._apply()"
    end

    test "cleans up every listener on destroy" do
      html = render_group(%{})

      destroyed =
        html
        |> String.split("destroyed() {")
        |> Enum.at(1)
        |> String.split("},", parts: 2)
        |> List.first()

      for listener <- ~w(click keydown) do
        assert destroyed =~ "removeEventListener(\"#{listener}\""
      end
    end
  end

  describe "form participation" do
    test "no hidden inputs, by design — mirror through on_change" do
      html = render_group(%{})

      refute html =~ ~s{type="hidden"}
      refute html =~ ~s{class="sr-only"}
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_group(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  # ── helpers ──────────────────────────────────────────────────

  defp count(html, str), do: length(String.split(html, str)) - 1

  # The <button …> opening tag of the item whose data-value matches —
  # every attribute from `type` through `class`, before any content.
  # Segments are bounded at each </button> so one item never bleeds
  # into the next, and the root div's seed data-value is excluded.
  defp item_chunk(html, value) do
    html
    |> String.split("<button")
    |> Enum.drop(1)
    |> Enum.map(&(String.split(&1, "</button>", parts: 2) |> List.first()))
    |> Enum.find(&(&1 =~ ~s{data-value="#{value}"}))
    |> String.split(">", parts: 2)
    |> List.first()
  end

  defp item_class(html, value) do
    item_chunk(html, value)
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp group_chunk(html) do
    [_, rest | _] = String.split(html, ~s{data-polaris-toggle-group }, parts: 2)

    rest
    |> String.split(">")
    |> Enum.at(0)
  end

  defp group_class(html) do
    group_chunk(html)
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
