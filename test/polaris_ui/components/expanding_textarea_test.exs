defmodule PolarisUI.Components.ExpandingTextareaTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.ExpandingTextarea` —
  the port of the Supabase design system ExpandingTextArea: the
  controlled textarea that auto-expands with its content via the
  scrollHeight measurement loop.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.ExpandingTextarea

  @hook "PolarisUI.Components.ExpandingTextarea.Root"

  defp render_textarea(assigns) do
    assigns =
      Map.merge(
        %{
          id: "message",
          value: "Hello",
          name: nil,
          placeholder: nil,
          disabled: false,
          readonly: false,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.expanding_textarea
      id={@id}
      value={@value}
      name={@name}
      placeholder={@placeholder}
      disabled={@disabled}
      readonly={@readonly}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "rendering" do
    test "renders a real textarea carrying the value as content" do
      html = render_textarea(%{})

      assert html =~ ~s{<textarea}
      assert html =~ ~s{id="message"}
      assert html =~ "Hello"
    end

    test "value is required — the source is controlled-only" do
      assigns = %{id: "message", value: "x", rest: %{}}

      assert_raise KeyError, ~r/value/, fn ->
        rendered_to_string(~H"""
        <.expanding_textarea id={@id} {assigns[:rest]} />
        """)
      end
    end

    test "rows=1 and aria-expanded=false, like the source" do
      html = render_textarea(%{})

      assert html =~ ~s{rows="1"}
      assert html =~ ~s{aria-expanded="false"}
    end

    test "forwards the name and placeholder" do
      html =
        render_textarea(%{
          name: "chat[message]",
          placeholder: "Type your message in multiple lines here."
        })

      assert html =~ ~s{name="chat[message]"}
      assert html =~ ~s{placeholder="Type your message in multiple lines here."}
    end

    test "forwards global attributes via rest — the invalid treatment is opt-in" do
      html =
        render_textarea(%{rest: %{"aria-invalid" => "true", "phx-change" => "update-message"}})

      assert html =~ ~s{aria-invalid="true"}
      assert html =~ ~s{phx-change="update-message"}
    end
  end

  describe "surface treatment" do
    test "the bordered panel fill with placeholder muting" do
      html = render_textarea(%{})

      assert html =~ "flex min-h-10 w-full resize-none rounded-md border border-surface-border"
      assert html =~ "bg-surface-panel px-3 py-2 text-base md:text-sm text-content-primary"
      assert html =~ "placeholder:text-content-muted"
    end

    test "the border brightens on hover; the emerald ring carries focus" do
      html = render_textarea(%{})

      assert html =~ "hover:border-surface-border-hover"
      assert html =~ "focus:ring-2 focus:ring-brand-emerald"
      assert html =~ "focus:ring-offset-2 focus:ring-offset-surface-ground"
      assert html =~ "focus:outline-none"
    end

    test "aria-invalid tints the border and fill danger" do
      html = render_textarea(%{})

      assert html =~
               "aria-[invalid=true]:border-danger-border aria-[invalid=true]:bg-danger-muted"

      assert html =~ "aria-[invalid=true]:hover:border-danger"
    end

    test "box-border keeps padding inside the measurement" do
      html = render_textarea(%{})

      assert html =~ "box-border"
    end

    test "caller classes merge onto the textarea" do
      html = render_textarea(%{class: "max-h-60"})

      assert html =~ "max-h-60"
    end
  end

  describe "states" do
    test "disabled dims and blocks editing" do
      html = render_textarea(%{disabled: true})

      assert html =~ ~r/<textarea[^>]*\sdisabled(?=[\s>])/
      assert html =~ "disabled:cursor-not-allowed disabled:opacity-50"
    end

    test "readonly blocks editing, keeps full contrast" do
      html = render_textarea(%{readonly: true})

      assert html =~ ~r/<textarea[^>]*\sreadonly(?=[\s>])/
      refute html =~ ~r/<textarea[^>]*\sdisabled(?=[\s>])/
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the textarea and ships its script inline" do
      html = render_textarea(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the measurement loop is the source's scrollHeight technique" do
      html = render_textarea(%{})

      assert html =~ ~s{el.style.height = "auto"}
      assert html =~ "el.scrollHeight"
      assert html =~ "Math.max(singleLineHeightPx, contentHeight)"
    end

    test "the 40px single-line floor matches input height" do
      html = render_textarea(%{})

      assert html =~ "const singleLineHeightPx = 40"
    end

    test "re-measures on every LiveView patch and via ResizeObserver" do
      html = render_textarea(%{})

      assert html =~ "updated()"
      assert html =~ "ResizeObserver"
      assert html =~ "this._observer.observe(this.el)"
      assert html =~ "disconnect()"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_textarea(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
