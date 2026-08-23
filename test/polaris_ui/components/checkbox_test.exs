defmodule PolarisUI.Components.CheckboxTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Checkbox` — the port of
  the Supabase design system Checkbox (shadcn over Radix): the 16px
  inverting box, the check/dash indicators, the paired label, the hidden
  form input, and the colocated runtime hook owning the toggle cycle.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Checkbox

  @hook "PolarisUI.Components.Checkbox.Box"

  defp render_checkbox(assigns) do
    assigns =
      Map.merge(
        %{
          id: "terms",
          name: nil,
          value: "on",
          checked: false,
          indeterminate: false,
          disabled: false,
          on_change: nil,
          class: nil,
          rest: %{},
          label: "Accept terms and conditions"
        },
        assigns
      )

    rendered_to_string(~H"""
    <.checkbox
      id={@id}
      name={@name}
      value={@value}
      checked={@checked}
      indeterminate={@indeterminate}
      disabled={@disabled}
      on_change={@on_change}
      class={@class}
      {assigns[:rest]}
    >
      {@label}
    </.checkbox>
    """)
  end

  describe "anatomy" do
    test "renders the role=checkbox box anchored by the hook" do
      html = render_checkbox(%{})

      assert html =~ ~s{id="terms"}
      assert html =~ ~s{data-polaris-checkbox-box}
      assert html =~ ~s{role="checkbox"}
      assert html =~ ~s{aria-checked="false"}
      assert html =~ ~s{data-state="unchecked"}
      assert html =~ ~s{phx-hook="#{@hook}"}
    end

    test "renders the 16px box with the source treatment" do
      html = render_checkbox(%{})

      class = box_class(html)
      assert class =~ "peer group flex h-4 w-4 shrink-0"
      assert class =~ "items-center justify-center rounded-sm"
      assert class =~ "border border-surface-border bg-surface-panel/25"
      assert class =~ "transition-colors duration-150 ease-in-out"
      assert class =~ "hover:border-surface-border-hover"
    end

    test "renders the label wired to the box" do
      html = render_checkbox(%{})

      assert html =~ ~s{<label for="terms" id="terms-label"}
      assert html =~ "Accept terms and conditions"
      label_class = label_class(html)
      assert label_class =~ "cursor-pointer text-sm font-medium leading-none"
      assert label_class =~ "peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
      assert html =~ ~s{aria-labelledby="terms-label"}
    end

    test "renders without a label when there is no inner block" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.checkbox id="bare" name="bare" />
        """)

      refute html =~ ~s{id="bare-label"}
      refute html =~ "<label"
    end

    test "the check icon cross-fades in when checked" do
      html = render_checkbox(%{})

      assert html =~ ~s{<path d="M20 6 9 17l-5-5">}
      check = icon_chunk(html)
      assert check =~ "h-3 w-3 opacity-0 transition-opacity"
      assert check =~ "group-data-[state=checked]:opacity-100"
    end

    test "the dash icon shows for the mixed state" do
      html = render_checkbox(%{})

      assert html =~ ~s{<path d="M5 12h14">}
      assert html =~ "group-data-[state=indeterminate]:opacity-100"
    end
  end

  describe "states" do
    test "checked inverts the box like the source" do
      html = render_checkbox(%{checked: true})

      assert html =~ ~s{data-state="checked"}
      assert html =~ ~s{aria-checked="true"}
      class = box_class(html)
      assert class =~ "data-[state=checked]:bg-content-primary"
      assert class =~ "data-[state=checked]:text-surface-ground"
      assert class =~ "data-[state=checked]:border-content-primary"
    end

    test "indeterminate renders the mixed state" do
      html = render_checkbox(%{indeterminate: true})

      assert html =~ ~s{data-state="indeterminate"}
      assert html =~ ~s{aria-checked="mixed"}
      assert box_class(html) =~ "data-[state=indeterminate]:bg-content-primary"
    end

    test "the box carries the focus-ring treatment" do
      html = render_checkbox(%{})

      class = box_class(html)
      assert class =~ "focus-visible:outline-none"
      assert class =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    end

    test "disabled locks the box, drops it from the tab order, and dims the label" do
      html = render_checkbox(%{disabled: true})

      chunk = box_chunk(html)
      assert chunk =~ " disabled"
      assert chunk =~ ~s{tabindex="-1"}
      assert box_class(html) =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end

    test "enabled boxes render the explicit Safari tabindex" do
      html = render_checkbox(%{})

      assert box_chunk(html) =~ ~s{tabindex="0"}
    end
  end

  describe "form participation" do
    test "with name, renders the hidden native checkbox" do
      html = render_checkbox(%{name: "terms", checked: true})

      assert html =~ ~s{<input type="checkbox" name="terms" value="on"}
      assert html =~ "checked"
      assert html =~ ~s{class="sr-only"}
      assert html =~ ~s{tabindex="-1"}
      assert html =~ ~s{data-polaris-checkbox-input}
    end

    test "the hidden input is unchecked when unchecked" do
      html = render_checkbox(%{name: "terms"})

      refute html =~ ~s{value="on" checked}
    end

    test "without name, no hidden input renders" do
      html = render_checkbox(%{})

      refute html =~ ~s{type="checkbox"}
    end

    test "the value rides along for the on_change payload" do
      html = render_checkbox(%{name: "scopes", value: "read:logs"})

      assert box_chunk(html) =~ ~s{data-value="read:logs"}
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_checkbox(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "seeds state from the server-rendered data-state" do
      html = render_checkbox(%{})

      assert html =~ ~s{this._state = this.el.dataset.state || "unchecked"}
    end

    test "implements the Radix toggle cycle" do
      html = render_checkbox(%{})

      assert html =~ ~s{this._state = this._state === "checked" ? "unchecked" : "checked"}
    end

    test "syncs the hidden input and mirrors aria-checked" do
      html = render_checkbox(%{})

      assert html =~ "this._input.checked = this._state !== \"unchecked\""
      assert html =~ "this._input.indeterminate = this._state === \"indeterminate\""
      assert html =~ "aria-checked"
    end

    test "bubbles input/change so phx-change forms observe the toggle" do
      html = render_checkbox(%{})

      assert html =~ ~s[new Event("input", { bubbles: true })]
      assert html =~ ~s[new Event("change", { bubbles: true })]
    end

    test "pushes the on_change event when configured" do
      html = render_checkbox(%{on_change: "toggle-terms"})

      assert html =~ ~s{data-change-event="toggle-terms"}

      assert html =~
               ~s[pushEvent(name, { state: this._state, value: this.el.dataset.value })]
    end

    test "no data-change-event attribute without on_change" do
      html = render_checkbox(%{})

      refute html =~ "data-change-event"
    end

    test "re-applies state after LiveView patches" do
      html = render_checkbox(%{})

      assert html =~ "updated()"
    end
  end

  describe "accessibility" do
    test "icons are aria-hidden decoration" do
      html = render_checkbox(%{})

      assert count(html, ~s{aria-hidden="true"}) >= 2
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_checkbox(%{rest: %{"data-testid" => "terms-box"}})

      assert html =~ ~s{data-testid="terms-box"}
    end

    test "classes merge onto the box and win conflicts via cn/1" do
      html = render_checkbox(%{class: "h-5 w-5"})

      class = box_class(html)
      assert class =~ "h-5 w-5"
      refute class =~ "h-4 w-4"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_checkbox(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  defp box_chunk(html) do
    [_, rest | _] = String.split(html, "data-polaris-checkbox-box", parts: 2)
    String.split(rest, ">") |> Enum.at(0)
  end

  defp box_class(html) do
    box_chunk(html)
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp label_class(html) do
    [_, rest | _] = String.split(html, ~s{id="terms-label"}, parts: 2)

    rest
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  # The chunk just before the check icon's path — its svg attributes.
  defp icon_chunk(html) do
    before_path = html |> String.split(~s{<path d="M20 6 9 17l-5-5"}) |> List.first()
    String.slice(before_path, -250..-1//1)
  end

  defp unescape(class) do
    class
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
