defmodule PolarisUI.Components.ResizableTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Resizable` — the port
  of the Supabase design system Resizable (`react-resizable-panels`
  v4): the flex group, the percentage panels, the separator handles
  with their hit strips and grip knobs, and the layout persistence
  contract.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Resizable

  @hook "PolarisUI.Components.Resizable.Root"

  defp render_group(assigns) do
    assigns =
      Map.merge(
        %{
          id: "layout",
          orientation: "horizontal",
          auto_save_id: nil,
          class: nil,
          rest: %{},
          inner_block: fn -> [] end
        },
        assigns
      )

    rendered_to_string(~H"""
    <.resizable_group
      id={@id}
      orientation={@orientation}
      auto_save_id={@auto_save_id}
      class={@class}
      {@rest}
    >
      <.resizable_panel default_size="25" id="layout-sidebar">Sidebar</.resizable_panel>
      <.resizable_handle />
      <.resizable_panel default_size="75" id="layout-content">Content</.resizable_panel>
    </.resizable_group>
    """)
  end

  defp render_panel(assigns) do
    assigns =
      Map.merge(
        %{
          id: nil,
          default_size: nil,
          min_size: "0",
          max_size: "100",
          collapsible: false,
          collapsed_size: "0",
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.resizable_panel
      id={@id}
      default_size={@default_size}
      min_size={@min_size}
      max_size={@max_size}
      collapsible={@collapsible}
      collapsed_size={@collapsed_size}
      class={@class}
      {@rest}
    >
      Body
    </.resizable_panel>
    """)
  end

  defp render_handle(assigns) do
    assigns =
      Map.merge(
        %{
          id: nil,
          with_handle: false,
          disabled: false,
          disable_double_click: false,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.resizable_handle
      id={@id}
      with_handle={@with_handle}
      disabled={@disabled}
      disable_double_click={@disable_double_click}
      class={@class}
      {@rest}
    />
    """)
  end

  describe "group anatomy" do
    test "renders the flex group anchored by the hook" do
      html = render_group(%{})

      assert html =~ ~s{id="layout"}
      assert html =~ ~s{data-polaris-resizable-group}
      assert html =~ ~s{data-orientation="horizontal"}
      assert html =~ ~s{phx-hook="#{@hook}"}

      class = group_class(html)
      assert class =~ "group/resizable flex h-full w-full overflow-hidden"
    end

    test "vertical groups stack as a column" do
      html = render_group(%{orientation: "vertical"})

      assert html =~ ~s{data-orientation="vertical"}

      class = group_class(html)
      assert class =~ "flex-col"
    end

    test "caller chrome merges onto the group" do
      html = render_group(%{class: "max-w-md rounded-lg border"})

      class = group_class(html)
      assert class =~ "max-w-md rounded-lg border"
    end

    test "rejects unknown orientations at render time" do
      assert_raise ArgumentError, ~r/invalid value for :orientation/, fn ->
        render_group(%{orientation: "diagonal"})
      end
    end
  end

  describe "panel anatomy" do
    test "renders the flex pane with the source's flex layout contract" do
      html = render_panel(%{id: "p1", default_size: "25"})

      assert html =~ ~s{id="p1"}
      assert html =~ ~s{data-polaris-resizable-panel}
      class = panel_class(html)
      assert class =~ "flex min-h-0 min-w-0 shrink grow basis-0 overflow-hidden"
    end

    test "the default size seeds flex-grow for SSR and the hook" do
      html = render_panel(%{id: "p1", default_size: "25"})

      assert html =~ ~s{data-default-size="25"}
      assert html =~ "flex-grow: 25"
    end

    test "sizes normalize: percent signs strip, integers stringify" do
      assert render_panel(%{id: "p1", default_size: "25%"}) =~ ~s{data-default-size="25"}
      assert render_panel(%{id: "p1", default_size: 25}) =~ ~s{data-default-size="25"}
    end

    test "panels without a default size omit the seed" do
      html = render_panel(%{id: "p1"})

      refute html =~ ~s{data-default-size=}
      refute html =~ "flex-grow:"
    end

    test "constraints and collapse flags ride data attributes for the hook" do
      html =
        render_panel(%{
          id: "p1",
          min_size: "10",
          max_size: "90",
          collapsible: true,
          collapsed_size: "5"
        })

      assert html =~ ~s{data-min-size="10"}
      assert html =~ ~s{data-max-size="90"}
      assert html =~ ~s{data-collapsible="true"}
      assert html =~ ~s{data-collapsed-size="5"}
    end

    test "content scrolls inside the pane like the source's inner wrapper" do
      html = render_panel(%{id: "p1"})

      assert html =~ ~s{data-polaris-resizable-panel-content}
      class = content_class(html)
      assert class =~ "h-full w-full overflow-auto"
    end

    test "forwards global attributes via rest" do
      html = render_panel(%{id: "p1", rest: %{"data-testid" => "sidebar"}})

      assert html =~ ~s{data-testid="sidebar"}
    end
  end

  describe "handle anatomy" do
    test "renders the 1px separator line with the source treatment" do
      html = render_handle(%{})

      assert html =~ ~s{data-polaris-resizable-handle}
      assert html =~ ~s{role="separator"}
      assert html =~ ~s{data-separator="inactive"}

      class = handle_class(html)
      assert class =~ "relative flex items-center justify-center bg-surface-border"
      assert class =~ "w-px"
      assert class =~ "transition-colors"
    end

    test "the invisible 4px hit strip widens the pointer target" do
      html = render_handle(%{})

      class = handle_class(html)

      assert class =~
               "after:absolute after:inset-y-0 after:left-1/2 after:w-1 after:-translate-x-1/2"
    end

    test "horizontal styling keys off the group's orientation (the vertical group)" do
      html = render_handle(%{})

      class = handle_class(html)
      assert class =~ "group-data-[orientation=vertical]/resizable:h-px"
      assert class =~ "group-data-[orientation=vertical]/resizable:w-full"
      assert class =~ "group-data-[orientation=vertical]/resizable:after:h-1"
    end

    test "active drags recolor the line to the strong border" do
      html = render_handle(%{})

      class = handle_class(html)
      assert class =~ "data-[separator=active]:bg-surface-border-hover"
    end

    test "the handle is focusable with the source's ring" do
      html = render_handle(%{})

      assert html =~ ~s{tabindex="0"}

      class = handle_class(html)

      assert class =~
               "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-brand-emerald"

      assert class =~ "focus-visible:ring-offset-1"
    end

    test "no grip renders without with_handle" do
      html = render_handle(%{})

      refute html =~ "size-2.5"
      refute html =~ ~s{<circle}
    end

    test "with_handle renders the hover-revealed grip knob" do
      html = render_handle(%{with_handle: true})

      class = grip_class(html)
      assert class =~ "z-10 flex h-4 w-3 items-center justify-center rounded-xs"
      assert class =~ "opacity-0 transition-opacity duration-200"
      assert class =~ "group-data-[separator=hover]:opacity-100"
      assert class =~ "group-data-[separator=active]:opacity-100"
      assert html =~ "rotate-90"
    end

    test "disabled locks the handle and drops it from the tab order" do
      html = render_handle(%{disabled: true})

      assert html =~ ~s{data-separator="disabled"}
      assert html =~ ~s{aria-disabled="true"}
      assert html =~ ~s{tabindex="-1"}

      class = handle_class(html)
      assert class =~ "cursor-not-allowed"
    end

    test "disable_double_click rides the data attribute the hook reads" do
      html = render_handle(%{disable_double_click: true})

      assert html =~ ~s{data-disable-double-click="true"}
    end

    test "forwards global attributes via rest" do
      html = render_handle(%{rest: %{"aria-label" => "Resize sidebar"}})

      assert html =~ ~s{aria-label="Resize sidebar"}
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_group(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "sizes the panels with flex-grow percentages" do
      html = render_group(%{})

      assert html =~ "panel.style.flexGrow"
    end

    test "carries the keyboard contract: arrows ±5, Home/End, Enter, F6" do
      html = render_group(%{})

      assert html =~ "this._resize(panel, event.key === growKey ? 5 : -5)"
      assert html =~ "config.minSize - current"
      assert html =~ "config.maxSize - current"
      assert html =~ ~s{event.key === "Enter"}
      assert html =~ ~s{event.key === "F6"}
    end

    test "applies the drag cursor document-wide and restores it" do
      html = render_group(%{})

      assert html =~ ~s{document.body.style.cursor = isVertical() ? "ns-resize" : "ew-resize"}
      assert html =~ ~s{document.body.style.cursor = ""}
    end

    test "double-click resets to the default size" do
      html = render_group(%{})

      assert html =~ "dblclick"
      assert html =~ "defaultSize - (this._layout[panel.id] ?? 0)"
    end

    test "auto_save_id persists under the source's v4 storage scheme" do
      html = render_group(%{auto_save_id: "docs-layout"})

      assert html =~ ~s{data-auto-save-id="docs-layout"}
      assert html =~ ~s{"react-resizable-panels-v4:"}
      assert html =~ "localStorage.setItem"
    end

    test "groups without auto_save_id never touch storage" do
      html = render_group(%{})

      refute html =~ ~s{data-auto-save-id=""}
    end

    test "re-applies the layout after LiveView patches" do
      html = render_group(%{})

      assert html =~ "updated()"
      assert html =~ "this._apply()"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_group(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp group_class(html), do: class_of(html, "data-polaris-resizable-group")

  defp panel_class(html), do: class_of(html, "data-polaris-resizable-panel")

  defp content_class(html), do: class_of(html, "data-polaris-resizable-panel-content")

  defp handle_class(html), do: class_of(html, "data-polaris-resizable-handle")

  defp grip_class(html) do
    # The grip is the first classed element after the handle's inline
    # cursor style.
    [_, rest | _] = String.split(html, ~s{style="cursor: auto;"}, parts: 2)

    rest
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
  end

  # Extracts the class attribute of the element carrying the marker,
  # regardless of attribute order within the tag.
  defp class_of(html, marker) do
    marker = Regex.escape(marker)
    class_after = ~r{<[^>]*#{marker}[^>]*?class="([^"]*)"[^>]*>}
    class_before = ~r{<[^>]*class="([^"]*)"[^>]*?#{marker}[^>]*>}

    cond do
      match = Regex.run(class_after, html, capture: :all_but_first) -> hd(match)
      match = Regex.run(class_before, html, capture: :all_but_first) -> hd(match)
      true -> flunk("no element with marker #{marker}")
    end
  end
end
