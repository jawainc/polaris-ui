defmodule PolarisUI.Components.CollapsibleTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Collapsible` — the port
  of the Supabase design system Collapsible (Radix primitive): the
  low-level disclosure with a colocated runtime hook owning the open
  state, the explicit-tabindex trigger, and the animated grid-rows
  content region.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Collapsible

  @hook "PolarisUI.Components.Collapsible.Root"

  defp render_collapsible(assigns) do
    assigns =
      Map.merge(
        %{
          id: "usage",
          default_open: false,
          disabled: false,
          on_change: nil,
          class: nil,
          trigger_class: nil,
          content_class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.collapsible
      id={@id}
      default_open={@default_open}
      disabled={@disabled}
      on_change={@on_change}
      class={@class}
      {assigns[:rest]}
    >
      <:trigger class={@trigger_class}>View usage instructions</:trigger>
      <:content class={@content_class}>
        <p>Run `mix deps.get` to fetch dependencies.</p>
      </:content>
    </.collapsible>
    """)
  end

  describe "anatomy" do
    test "renders the hook root with the closed state by default" do
      html = render_collapsible(%{})

      assert html =~ ~s{id="usage"}
      assert html =~ ~s{data-polaris-collapsible }
      assert html =~ ~s{data-state="closed"}
      assert html =~ ~s{data-disabled="false"}
      assert html =~ ~s{phx-hook="#{@hook}"}
    end

    test "default_open renders the open state" do
      html = render_collapsible(%{default_open: true})

      assert html =~ ~s{data-state="open"}
      assert html =~ ~s{aria-expanded="true"}
    end

    test "the trigger is a real button with derived ids" do
      html = render_collapsible(%{})

      assert html =~ ~s{id="usage-trigger"}
      assert html =~ ~s{aria-controls="usage-content"}
      assert html =~ "View usage instructions"
    end

    test "the content renders inside the animated region" do
      html = render_collapsible(%{})

      assert html =~ ~s{id="usage-content"}
      assert html =~ "Run `mix deps.get` to fetch dependencies."

      class = content_class(html)
      assert class =~ "grid overflow-hidden transition-all duration-150 ease-out"
      assert class =~ "data-[state=closed]:grid-rows-[0fr]"
      assert class =~ "data-[state=open]:grid-rows-[1fr]"
    end
  end

  describe "states" do
    test "the trigger carries the focus-ring treatment" do
      html = render_collapsible(%{})

      class = trigger_class(html)
      assert class =~ "cursor-pointer"
      assert class =~ "focus-visible:outline-none"
      assert class =~ "focus-visible:ring-2 focus-visible:ring-brand-emerald"
      assert class =~ "focus-visible:ring-offset-2 focus-visible:ring-offset-surface-ground"
    end

    test "disabled locks the trigger and drops it from the tab order" do
      html = render_collapsible(%{disabled: true})

      assert html =~ ~s{data-disabled="true"}
      chunk = trigger_chunk(html)
      assert chunk =~ " disabled"
      assert chunk =~ ~s{tabindex="-1"}
      assert trigger_class(html) =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end

    test "enabled triggers render the explicit Safari tabindex" do
      html = render_collapsible(%{})

      assert trigger_chunk(html) =~ ~s{tabindex="0"}
    end

    test "motion-reduce disables the height animation" do
      html = render_collapsible(%{})

      assert content_class(html) =~ "motion-reduce:transition-none"
    end
  end

  describe "colocated hook" do
    test "ships the runtime hook script inline" do
      html = render_collapsible(%{})

      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "toggles from the server-rendered state" do
      html = render_collapsible(%{default_open: true})

      assert html =~ ~s{this._open = this.el.dataset.state === "open"}
      assert html =~ "this._open = !this._open"
    end

    test "disabled roots and triggers refuse to toggle" do
      html = render_collapsible(%{})

      assert html =~ "trigger.disabled"
      assert html =~ ~s{this.el.dataset.disabled === "true"}
    end

    test "pushes the on_change event when configured" do
      html = render_collapsible(%{on_change: "usage-toggled"})

      assert html =~ ~s{data-change-event="usage-toggled"}
      assert html =~ ~s[pushEvent(name, { state: this._open ? "open" : "closed" })]
    end

    test "no data-change-event attribute without on_change" do
      html = render_collapsible(%{})

      refute html =~ "data-change-event"
    end

    test "re-applies state after LiveView patches" do
      html = render_collapsible(%{})

      assert html =~ "updated()"
      assert html =~ "LiveView patches may stomp"
    end

    test "applies state to the root, trigger, and content" do
      html = render_collapsible(%{})

      assert html =~ "this.el.dataset.state = state"
      assert html =~ ~s{trigger.setAttribute("aria-expanded", String(this._open))}
      assert html =~ "content.dataset.state = state"
    end
  end

  describe "accessibility" do
    test "trigger and region are wired by derived ids" do
      html = render_collapsible(%{})

      assert html =~ ~s{role="region"}
      assert html =~ ~s{aria-labelledby="usage-trigger"}
      assert html =~ ~s{aria-controls="usage-content"}
    end

    test "closed regions are invisible to assistive tech" do
      html = render_collapsible(%{})

      assert content_class(html) =~ "data-[state=closed]:invisible"
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_collapsible(%{rest: %{"data-testid" => "usage-disclosure"}})

      assert html =~ ~s{data-testid="usage-disclosure"}
    end

    test "root, trigger, and content classes merge" do
      html =
        render_collapsible(%{
          class: "w-[350px] space-y-2",
          trigger_class: "font-medium hover:underline",
          content_class: "pt-2"
        })

      # the root renders its class before the marker; trigger/content after
      assert html =~ ~s{class="w-[350px] space-y-2" data-polaris-collapsible}
      assert trigger_class(html) =~ "font-medium hover:underline"
      assert content_class(html) =~ "pt-2"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_collapsible(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp trigger_chunk(html) do
    [_, rest | _] = String.split(html, "data-polaris-collapsible-trigger", parts: 2)
    String.split(rest, ">") |> Enum.at(0)
  end

  defp content_chunk(html) do
    [_, rest | _] = String.split(html, "data-polaris-collapsible-content", parts: 2)
    String.split(rest, ">") |> Enum.at(0)
  end

  defp trigger_class(html) do
    trigger_chunk(html)
    |> String.split(~s{class="})
    |> Enum.at(1)
    |> String.split("\"")
    |> List.first()
    |> unescape()
  end

  defp content_class(html) do
    content_chunk(html)
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
