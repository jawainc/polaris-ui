defmodule PolarisUI.Components.StatusCodeTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.StatusCode` — chip
  anatomy and ordering, rounding sides, the three color families
  (including named strings and the method-skips-the-gate quirk),
  invalid-input fallbacks, typography, class merging, and globals,
  mirroring the Supabase design system fragment `ui-patterns/StatusCode`.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.StatusCode

  doctest PolarisUI.Components.StatusCode

  defp render_status_code(attrs \\ []) do
    assigns = %{attrs: Map.new(attrs)}

    rendered_to_string(~H"""
    <.status_code {@attrs} />
    """)
  end

  describe "anatomy" do
    test "renders the root, the mono shell, and the status chip" do
      html = render_status_code(status_code: 200)

      assert length(tags_with(html, "data-polaris-status-code")) == 1
      assert class_of(html, "data-polaris-status-code") =~ "flex items-center gap-2"
      assert html =~ "shrink-0 flex text-xs font-mono items-start justify-start"
      assert length(tags_with(html, "data-polaris-status-value")) == 1
    end

    test "no method chip by default" do
      refute render_status_code(status_code: 200) =~ "data-polaris-status-method"
    end

    test "renders the method chip and status chip side by side, method first" do
      html = render_status_code(method: "GET", status_code: 404)

      assert length(tags_with(html, "data-polaris-status-method")) == 1
      assert html =~ ">GET<"
      assert html =~ ">404<"
      assert text_position(html, ">GET<") < text_position(html, ">404<")
    end

    test "the method chip carries the fragment's half-chip chrome" do
      html = render_status_code(method: "POST", status_code: 201)

      classes = class_of(html, "data-polaris-status-method") |> String.split(" ")

      for expected <-
            ~w(select-text py-0.5 px-2 text-right rounded-l rounded-r-none bg-surface-base text-content-secondary border border-surface-border border-r-0 w-auto) do
        assert expected in classes
      end
    end

    test "the status chip carries the fragment's geometry and typography" do
      html = render_status_code(status_code: 200)

      classes = class_of(html, "data-polaris-status-value") |> String.split(" ")

      for expected <- ~w(py-0.5 px-2 border tabular-nums text-left w-auto) do
        assert expected in classes
      end
    end

    test "status codes render verbatim, strings included" do
      html = render_status_code(status_code: "502")

      assert html =~ ">502<"
    end
  end

  describe "rounding" do
    test "without a method the status chip rounds both sides" do
      html = render_status_code(status_code: 200)

      assert has_class?(html, "data-polaris-status-value", "rounded-l")
      assert has_class?(html, "data-polaris-status-value", "rounded-r")
      refute has_class?(html, "data-polaris-status-value", "rounded-l-0")
    end

    test "with a method the status chip keeps its left edge square" do
      html = render_status_code(method: "GET", status_code: 200)

      assert has_class?(html, "data-polaris-status-value", "rounded-l-0")
      assert has_class?(html, "data-polaris-status-value", "rounded-r")
      refute has_class?(html, "data-polaris-status-value", "rounded-l")

      assert has_class?(html, "data-polaris-status-method", "rounded-l")
      assert has_class?(html, "data-polaris-status-method", "rounded-r-none")
    end
  end

  describe "color families" do
    test "2xx renders the muted family with the plain-border fallback" do
      html = render_status_code(method: "GET", status_code: 200)

      chip = class_of(html, "data-polaris-status-value")

      assert chip =~ "text-content-secondary"
      assert chip =~ "bg-surface-panel"
      assert chip =~ "border-surface-border"
      refute chip =~ "bg-warning-muted"
      refute chip =~ "bg-danger-muted"
    end

    test "4xx — by number or digit string — renders the warning family" do
      for status <- [404, "404"] do
        html = render_status_code(method: "GET", status_code: status)

        chip = class_of(html, "data-polaris-status-value")

        assert chip =~ "text-warning"
        assert chip =~ "bg-warning-muted"
        assert chip =~ "border-warning-border"
        # exactly one border color: the fallback is merged away
        refute chip =~ "border-surface-border"
      end
    end

    test "5xx renders the danger family" do
      html = render_status_code(method: "GET", status_code: 502)

      chip = class_of(html, "data-polaris-status-value")

      assert chip =~ "text-danger"
      assert chip =~ "bg-danger-muted"
      assert chip =~ "border-danger-border"
      refute chip =~ "border-surface-border"
    end

    test "named warning strings render the warning family" do
      for status <- ["warning", "redirect", "4"] do
        html = render_status_code(method: "POST", status_code: status)

        assert class_of(html, "data-polaris-status-value") =~ "bg-warning-muted"
      end
    end

    test "named danger and muted strings render their families" do
      html = render_status_code(method: "GET", status_code: "error")
      assert class_of(html, "data-polaris-status-value") =~ "bg-danger-muted"

      for status <- ["info", "success"] do
        html = render_status_code(method: "GET", status_code: status)

        assert class_of(html, "data-polaris-status-value") =~ "bg-surface-panel"
      end
    end
  end

  describe "invalid inputs" do
    test "out-of-range and unparseable statuses fall back to muted" do
      for status <- [99, 600, "abc", "42", "999"] do
        html = render_status_code(status_code: status)

        chip = class_of(html, "data-polaris-status-value")

        assert chip =~ "bg-surface-panel"
        refute chip =~ "bg-warning-muted"
        refute chip =~ "bg-danger-muted"
      end
    end

    test "named strings without a method fail the validity gate" do
      html = render_status_code(status_code: "error")

      chip = class_of(html, "data-polaris-status-value")

      assert chip =~ "bg-surface-panel"
      refute chip =~ "text-danger"
    end

    test "numbers below 100 become their own string and land on the switch default" do
      html = render_status_code(method: "GET", status_code: 42)

      chip = class_of(html, "data-polaris-status-value")

      assert chip =~ "bg-surface-panel"
      refute chip =~ "bg-warning-muted"
      refute chip =~ "bg-danger-muted"
    end
  end

  describe "nil status_code" do
    test "renders an empty muted chip while the component still renders" do
      html = render_status_code()

      assert length(tags_with(html, "data-polaris-status-code")) == 1
      assert length(tags_with(html, "data-polaris-status-value")) == 1
      assert class_of(html, "data-polaris-status-value") =~ "bg-surface-panel"
      # the chip has no text content of its own
      refute html =~ ~r{data-polaris-status-value[^>]*>[^<]}
      refute html =~ "data-polaris-status-method"
    end
  end

  describe "typography" do
    test "chips sit in the shared mono shell and digits use tabular numerals" do
      html = render_status_code(method: "GET", status_code: 502)

      assert html =~ "text-xs font-mono"
      assert has_class?(html, "data-polaris-status-value", "tabular-nums")
      assert has_class?(html, "data-polaris-status-method", "text-right")
    end
  end

  describe "class merging and globals" do
    test "caller classes merge onto the root" do
      html = render_status_code(status_code: 200, class: "gap-4")

      root = class_of(html, "data-polaris-status-code") |> String.split(" ")

      assert "gap-4" in root
      refute "gap-2" in root
      assert "flex" in root
      assert "items-center" in root
    end

    test "rest globals forward to the root div" do
      html = render_status_code(status_code: 200, "data-track": "req-1")

      assert html =~ ~s{data-track="req-1"}
    end
  end

  describe "design rules" do
    test "no raw colors across every family and shape" do
      renders =
        for {method, status} <- [
              {nil, 200},
              {nil, 404},
              {"GET", 500},
              {"POST", "error"},
              {"PATCH", "warning"},
              {nil, nil}
            ] do
          render_status_code(method: method, status_code: status)
        end

      for html <- renders do
        refute html =~ "#["
      end
    end
  end

  # Membership on the exact space-separated class list — substring
  # checks cannot tell `rounded-l` apart from `rounded-l-0`.
  defp has_class?(html, marker, class) do
    html |> class_of(marker) |> String.split(" ") |> Enum.member?(class)
  end

  defp text_position(html, text), do: html |> :binary.match(text) |> elem(0)

  # Extracts the opening tags of every element carrying the marker.
  # The lookahead keeps prefixed markers apart (status-code vs
  # status-method) — bare data attributes render without ="...".
  defp tags_with(html, marker) do
    marker = Regex.escape(marker)

    html
    |> then(&Regex.scan(~r{<[^>]*#{marker}(?![\w-])[^>]*>}, &1))
    |> List.flatten()
  end

  # Extracts the class attribute of the element carrying the marker,
  # regardless of attribute order within the tag.
  defp class_of(html, marker) do
    marker = Regex.escape(marker)

    class_after = ~r{<[^>]*#{marker}(?![\w-])[^>]*?class="([^"]*)"[^>]*>}
    class_before = ~r{<[^>]*class="([^"]*)"[^>]*?#{marker}(?![\w-])[^>]*>}

    cond do
      match = Regex.run(class_after, html, capture: :all_but_first) -> hd(match)
      match = Regex.run(class_before, html, capture: :all_but_first) -> hd(match)
      true -> flunk("no element with marker #{marker}")
    end
  end
end
