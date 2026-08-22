defmodule PolarisUI.Components.InfoTooltipTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.InfoTooltip` — anatomy,
  sides/alignment placement, states, the colocated hook, and
  accessibility, mirroring the Supabase design system fragment
  `ui-patterns/info-tooltip`: a bare 16px info-circle button opening a
  bordered text panel on hover/focus.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.InfoTooltip

  @hook "PolarisUI.Components.InfoTooltip.Tip"

  describe "anatomy" do
    test "renders the icon button trigger and the tooltip panel" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">Restricts access based on user policies</.info_tooltip>
        """)

      assert html =~ ~s{id="tip"}
      assert html =~ ~s{id="tip-content"}
      assert html =~ ~s{data-polaris-info-tooltip}
      assert html =~ ~s{data-polaris-info-tooltip-trigger}
      assert html =~ ~s{data-polaris-info-tooltip-content}
      assert html =~ "Restricts access based on user policies"
      assert html =~ ~s{viewBox="0 0 16 16"}
    end

    test "the trigger is a real button that does nothing on click" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      assert html =~ ~s{<button type="button"}
      refute html =~ "phx-click"
    end

    test "the panel chrome mirrors the Supabase TooltipContent" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      panel = panel_class(html)

      assert panel =~ "rounded-md"
      assert panel =~ "border-surface-border"
      assert panel =~ "bg-surface-base"
      assert panel =~ "px-3"
      assert panel =~ "py-1.5"
      assert panel =~ "text-xs"
      assert panel =~ "text-content-primary"
      assert panel =~ "shadow-md"
      assert panel =~ "max-w-[280px]"
    end

    test "the panel starts hidden and animates in on open" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      panel = panel_class(html)

      assert panel =~ "invisible"
      assert panel =~ "opacity-0"
      assert panel =~ "group-data-[state=open]/tooltip:visible"
      assert panel =~ "group-data-[state=open]/tooltip:opacity-100"
      assert panel =~ "duration-150"
    end

    test "the icon is muted at rest and brightens on hover and open" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      trigger = trigger_class(html)

      assert trigger =~ "text-content-muted"
      assert trigger =~ "hover:text-content-secondary"
      assert trigger =~ "group-data-[state=open]/tooltip:text-content-secondary"
    end
  end

  describe "sides and alignment" do
    test "top is the default side with centered alignment" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      wrapper = position_class(html)

      assert wrapper =~ "bottom-full"
      assert wrapper =~ "left-1/2"
      assert wrapper =~ "-translate-x-1/2"
      assert wrapper =~ "mb-1"
      assert html =~ ~s{data-side="top"}
      panel = panel_class(html)
      assert panel =~ "translate-y-1"
    end

    test "bottom/start and bottom/end placements" do
      assigns = %{}

      for align <- ~w(start end) do
        assigns = %{align: align}

        html =
          rendered_to_string(~H"""
          <.info_tooltip id="tip" side="bottom" align={@align}>text</.info_tooltip>
          """)

        wrapper = position_class(html)

        assert wrapper =~ "top-full"
        assert wrapper =~ "mt-1"
        assert wrapper =~ ((align == "start" && "left-0") || "right-0")
        panel = panel_class(html)
        assert panel =~ "-translate-y-1"
      end
    end

    test "left and right sides slide along the x axis" do
      assigns = %{}

      left =
        rendered_to_string(~H"""
        <.info_tooltip id="tip" side="left">text</.info_tooltip>
        """)

      assert position_class(left) =~ "right-full"
      assert position_class(left) =~ "mr-1"
      assert panel_class(left) =~ "translate-x-1"

      right =
        rendered_to_string(~H"""
        <.info_tooltip id="tip" side="right">text</.info_tooltip>
        """)

      assert position_class(right) =~ "left-full"
      assert position_class(right) =~ "ml-1"
      assert panel_class(right) =~ "-translate-x-1"
    end

    test "vertical centering on the horizontal sides" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip" side="right" align="center">text</.info_tooltip>
        """)

      wrapper = position_class(html)

      assert wrapper =~ "top-1/2"
      assert wrapper =~ "-translate-y-1/2"
    end

    test "the positioned wrapper owns the z-index" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      assert position_class(html) =~ "z-50"
    end

    test "invalid side or align raises a clear error" do
      assigns = %{}

      assert_raise ArgumentError, ~r/invalid value for :side/, fn ->
        rendered_to_string(~H"""
        <.info_tooltip id="tip" side="diagonal">text</.info_tooltip>
        """)
      end

      assert_raise ArgumentError, ~r/invalid value for :align/, fn ->
        rendered_to_string(~H"""
        <.info_tooltip id="tip" align="middle">text</.info_tooltip>
        """)
      end
    end
  end

  describe "hook and states" do
    test "attaches the colocated runtime hook to the root" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ "<script"
      assert html =~ "mouseenter"
      assert html =~ "focusin"
      assert html =~ ~r/"Escape"/
    end

    test "the root and trigger start closed" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      assert html =~ ~s{data-state="closed"}
    end

    test "the trigger carries the shared focus-visible ring" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      trigger = trigger_class(html)

      assert trigger =~ "focus-visible:ring-2"
      assert trigger =~ "focus-visible:ring-brand-emerald"
      assert trigger =~ "focus-visible:ring-offset-2"
    end
  end

  describe "accessibility and overrides" do
    test "the panel is role=tooltip and describedby wires it to the trigger" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      assert html =~ ~s{role="tooltip"}
      assert html =~ ~s{aria-describedby="tip-content"}
    end

    test "the trigger has an accessible name, overridable via label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip" label="What is pooling?">text</.info_tooltip>
        """)

      assert html =~ ~s{aria-label="What is pooling?"}
    end

    test "the glyph is aria-hidden decoration" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip">text</.info_tooltip>
        """)

      assert html =~ ~s{aria-hidden="true"}
    end

    test "caller classes merge onto the panel and globals reach the trigger" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.info_tooltip id="tip" class="max-w-sm" data-track="x">text</.info_tooltip>
        """)

      panel = panel_class(html)

      assert panel =~ "max-w-sm"
      assert panel =~ "rounded-md"
      assert html =~ ~s{data-track="x"}
    end
  end

  defp trigger_class(html) do
    ~r{class="([^"]*)"[^>]*data-polaris-info-tooltip-trigger}
    |> Regex.run(html, capture: :all_but_first)
    |> List.first()
  end

  # The absolutely-positioned wrapper precedes the panel in the DOM.
  defp position_class(html) do
    ~r{<span class="([^"]*)" role="presentation">}
    |> Regex.run(html, capture: :all_but_first)
    |> List.first()
  end

  defp panel_class(html) do
    ~r{class="([^"]*)"[^>]*data-polaris-info-tooltip-content}
    |> Regex.run(html, capture: :all_but_first)
    |> List.first()
  end
end
