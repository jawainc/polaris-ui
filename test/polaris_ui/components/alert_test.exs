defmodule PolarisUI.Components.AlertTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Alert` — the port of
  the Supabase design system Alert primitive (`packages/ui`): a
  `role="alert"` region whose direct-child SVG becomes an absolutely
  positioned 23px badge, with the title/description sub-anatomy and the
  default / destructive / warning variant formula.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Alert

  defp render_alert(assigns) do
    assigns =
      Map.merge(
        %{variant: "default", title: nil, class: nil, rest: %{}},
        assigns
      )

    rendered_to_string(~H"""
    <.alert variant={@variant} title={@title} class={@class} {assigns[:rest]}>
      <:icon :if={assigns[:icon]}>
        {assigns[:icon]}
      </:icon>
      <:description :if={assigns[:description]}>
        {assigns[:description]}
      </:description>
      {assigns[:inner]}
    </.alert>
    """)
  end

  @icon {:safe, ~s{<svg viewBox="0 0 24 24" aria-hidden="true"></svg>}}

  describe "anatomy" do
    test "renders the alert region with the container chrome" do
      html = render_alert(%{title: "Heads up!"})

      assert html =~ ~s{role="alert"}
      assert html =~ ~s{data-polaris-alert="default"}

      class = root_class(html)
      assert class =~ "relative w-full"
      assert class =~ "rounded-lg"
      assert class =~ "border"
      assert class =~ "p-4"
      assert class =~ "text-sm"
      assert class =~ "text-content-primary"
    end

    test "the title renders as a medium paragraph" do
      html = render_alert(%{title: "Heads up!"})

      assert html =~ ~s{data-polaris-alert-title}
      assert html =~ "mt-0 mb-0.5 font-medium"
      assert html =~ "Heads up!"
    end

    test "the title is optional" do
      html = render_alert(%{})

      refute html =~ "data-polaris-alert-title"
    end

    test "the description renders with the paragraph rhythm" do
      html = render_alert(%{description: {:safe, "<p>Add components via the CLI.</p>"}})

      assert html =~ ~s{data-polaris-alert-description}
      assert html =~ "mb-0.5 text-sm font-normal text-content-secondary"
      assert html =~ "[&_p]:mb-0.5 [&_p:last-child]:mb-0"
      assert html =~ "Add components via the CLI."
    end

    test "the inner block renders like the description" do
      html = render_alert(%{inner: {:safe, "<p>Children slot copy.</p>"}})

      assert html =~ "Children slot copy."
      assert html =~ "text-content-secondary"
    end

    test "description and inner block can coexist, description first" do
      html =
        render_alert(%{
          description: {:safe, "<p>Description copy.</p>"},
          inner: {:safe, "<p>Children copy.</p>"}
        })

      assert position(html, "Description copy.") < position(html, "Children copy.")
    end
  end

  describe "icon badge" do
    test "a bare svg renders as a direct child where the auto-classes apply" do
      html = render_alert(%{icon: @icon})

      assert html =~ ~s{<svg viewBox="0 0 24 24"}

      class = root_class(html)
      # the absolute 23px badge formula, verbatim from the source cva
      assert class =~ "[&>svg~*]:pl-10"
      assert class =~ "[&>svg]:absolute [&>svg]:left-4 [&>svg]:top-4"
      assert class =~ "[&>svg]:flex [&>svg]:size-[23px] [&>svg]:p-1 [&>svg]:rounded-sm"
    end

    test "no icon slot, no svg styling concerns — the region still renders" do
      html = render_alert(%{title: "Note"})

      refute html =~ "<svg"
      assert html =~ "Note"
    end
  end

  describe "variants" do
    test "default is the neutral panel tint with inverted badge chip" do
      html = render_alert(%{icon: @icon})

      class = root_class(html)
      assert class =~ "bg-surface-panel/40"
      assert class =~ "border-surface-border"
      assert class =~ "[&>svg]:bg-content-primary [&>svg]:text-surface-ground"
    end

    test "destructive uses the red tint formula" do
      html = render_alert(%{variant: "destructive", icon: @icon})

      class = root_class(html)
      assert class =~ "bg-danger-muted"
      assert class =~ "border-danger-border"
      assert class =~ "[&>svg]:bg-danger"
    end

    test "warning uses the amber tint formula" do
      html = render_alert(%{variant: "warning", icon: @icon})

      class = root_class(html)
      assert class =~ "bg-warning-muted"
      assert class =~ "border-warning-border"
      assert class =~ "[&>svg]:bg-warning"
    end

    test "rejects an unknown variant" do
      assert_raise ArgumentError, ~r/:variant/, fn ->
        render_alert(%{variant: "sassy"})
      end
    end

    test "there is no success variant — that is an admonition concern" do
      assert_raise ArgumentError, ~r/:variant/, fn ->
        render_alert(%{variant: "success"})
      end
    end
  end

  describe "attributes" do
    test "caller classes merge last and win conflicts" do
      html = render_alert(%{class: "p-3"})

      class = root_class(html)
      assert class =~ "p-3"
      # whole-utility match — `[&>svg]:top-4` must not count as `p-4`
      refute class =~ ~r{(?:^|\s)p-4(?:\s|$)}
    end

    test "forwards global attributes via rest" do
      html = render_alert(%{rest: %{"data-testid" => "quota-alert", id: "quota"}})

      assert html =~ ~s{data-testid="quota-alert"}
      assert html =~ ~s{id="quota"}
    end

    test "a caller role overrides the assertive default" do
      html = render_alert(%{rest: %{role: "status"}})

      assert html =~ ~s{role="status"}
      assert count(html, ~s{role="}) == 1
    end
  end

  describe "states and accessibility" do
    test "the region is passive — no interactive affordances" do
      html = render_alert(%{})

      refute html =~ "hover:"
      refute html =~ "focus-visible"
      refute html =~ "cursor-pointer"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_alert(%{icon: @icon, variant: "warning"})

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

  defp count(html, pattern), do: length(String.split(html, pattern)) - 1

  # The class attribute of the alert root (the first class= in the output),
  # HTML-unescaped so selector assertions read naturally.
  defp root_class(html) do
    html
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
