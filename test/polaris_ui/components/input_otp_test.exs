defmodule PolarisUI.Components.InputOTPTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.InputOTP` — the port
  of the Supabase design system Input OTP (the `input-otp` library):
  the one real input overlaid on the slot row.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.InputOTP

  @hook "PolarisUI.Components.InputOTP.Root"

  defp render_otp(assigns) do
    assigns =
      Map.merge(
        %{
          id: "otp",
          name: "pin",
          value: "",
          max_length: 6,
          group_size: nil,
          pattern: "any",
          disabled: false,
          autofocus: false,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.input_otp
      id={@id}
      name={@name}
      value={@value}
      max_length={@max_length}
      group_size={@group_size}
      pattern={@pattern}
      disabled={@disabled}
      autofocus={@autofocus}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "root" do
    test "renders the container and the invisible input over the slots" do
      html = render_otp(%{})

      assert html =~ ~s{<div id="otp" data-polaris-input-otp}
      assert html =~ ~s{data-max-length="6"}
      assert html =~ ~s{data-pattern="any"}

      assert html =~
               ~s{class="relative flex items-center gap-2 has-[:disabled]:opacity-50"}

      assert html =~ ~s{<input id="otp-input" data-polaris-input-otp-input}
      assert html =~ ~s{type="text"}
      assert input_class(html) =~ "absolute inset-0 z-10"
    end

    test "max_length drives the slot count and the input's maxlength" do
      html = render_otp(%{max_length: 4})

      assert html =~ ~s{maxlength="4"}
      assert length(slot_texts(html)) == 4
    end

    test "the value renders into the slots server-side (no-JS graceful state)" do
      html = render_otp(%{value: "12"})

      assert slot_texts(html) == ["1", "2", "", "", "", ""]
      assert html =~ ~s{value="12"}
    end

    test "single group by default — no separators" do
      html = render_otp(%{})

      assert count_marker(html, ~s{<div data-polaris-input-otp-group }) == 1
      assert count_marker(html, ~s{<div data-polaris-input-otp-separator }) == 0
    end

    test "group_size chunks the slots with dot separators between groups" do
      html = render_otp(%{group_size: 3})

      assert count_marker(html, ~s{<div data-polaris-input-otp-group }) == 2
      assert count_marker(html, ~s{<div data-polaris-input-otp-separator }) == 1

      assert html =~ ~s{<div data-polaris-input-otp-separator role="separator"}
      assert html =~ ~s{<circle cx="12" cy="12" r="5"}
    end

    test "the slot carries the source's classes — border-y/r, first/last rounding, active ring" do
      html = render_otp(%{})

      # `data-slot-index` disambiguates the slot from the `-slots` wrapper
      slot = marker_class(html, "data-polaris-input-otp-slot data-slot-index")

      assert slot =~
               "relative flex h-10 w-10 items-center justify-center border-y border-r border-surface-border"

      assert slot =~ "first:rounded-l-md first:border-l last:rounded-r-md"
      assert slot =~ "data-[active=true]:ring-2 data-[active=true]:ring-brand-emerald"
    end
  end

  describe "patterns" do
    test "digits normalizes the value server-side and sets numeric inputmode" do
      html = render_otp(%{pattern: "digits", value: "1a2b3"})

      assert html =~ ~s{data-pattern="digits"}
      assert html =~ ~s{inputmode="numeric"}
      assert html =~ ~s{value="123"}
      assert slot_texts(html) == ["1", "2", "3", "", "", ""]
    end

    test "alnum keeps letters and digits only" do
      html = render_otp(%{pattern: "alnum", value: "a1-2"})

      assert html =~ ~s{value="a12"}
    end

    test "any keeps whatever was typed, sliced to max_length" do
      html = render_otp(%{value: "abcdefgh"})

      assert html =~ ~s{value="abcdef"}
    end

    test "rejects unknown patterns" do
      assert_raise ArgumentError, ~r/:pattern/, fn -> render_otp(%{pattern: "hex"}) end
    end
  end

  describe "states" do
    test "disabled blocks entry and dims the row" do
      html = render_otp(%{disabled: true})

      assert html =~ ~s{disabled}

      assert marker_class(html, "data-polaris-input-otp") =~ "has-[:disabled]:opacity-50"
    end

    test "autofocus forwards to the input" do
      assert render_otp(%{autofocus: true}) =~ ~s{autofocus}
    end
  end

  describe "accessibility & form wiring" do
    test "autocomplete defaults to one-time-code for SMS autofill" do
      assert render_otp(%{}) =~ ~s{autocomplete="one-time-code"}
    end

    test "autocomplete and aria-label are overridable through rest" do
      html =
        render_otp(%{
          rest: %{
            "autocomplete" => "off",
            "aria-label" => "App code",
            "phx-change" => "pin-changed"
          }
        })

      assert html =~ ~s{autocomplete="off"}
      assert html =~ ~s{aria-label="App code"}
      assert html =~ ~s{phx-change="pin-changed"}
      refute html =~ ~s{autocomplete="one-time-code"}
    end

    test "aria-label defaults to Verification code" do
      assert render_otp(%{}) =~ ~s{aria-label="Verification code"}
    end

    test "the slots row lives in a phx-update=ignore subtree" do
      html = render_otp(%{})

      assert html =~ ~s{<div id="otp-slots" phx-update="ignore" data-polaris-input-otp-slots}
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the input and ships its script inline" do
      html = render_otp(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
    end

    test "the hook sanitizes typed and pasted input against the pattern" do
      html = render_otp(%{})

      assert html =~ ~s{pattern === "digits"}
      assert html =~ ~s{replace(/[^0-9]/g, "")}
      assert html =~ ~s{replace(/[^a-zA-Z0-9]/g, "")}
      assert html =~ "out.slice(0, this._max)"
    end

    test "the hook mirrors the value into slots and blinks the fake caret" do
      html = render_otp(%{})

      assert html =~ "animate-caret-blink"
      assert html =~ "slot.dataset.active"
      assert html =~ "data-polaris-input-otp-caret"
    end

    test "the hook re-syncs after LiveView patches" do
      html = render_otp(%{})

      assert html =~ "updated()"
      assert html =~ "this._render()"
    end
  end

  describe "customization" do
    test "merges the caller's class onto the container" do
      html = render_otp(%{class: "gap-3"})

      assert marker_class(html, "data-polaris-input-otp") =~ "gap-3"
    end

    test "never hardcodes raw hex values" do
      refute render_otp(%{}) =~ "#[", "arbitrary-value class leaked"
    end
  end

  defp input_class(html), do: marker_class(html, "data-polaris-input-otp-input")

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

  defp count_marker(html, marker), do: count_occurrences(html, marker, 0)

  defp count_occurrences(html, marker, count) do
    case :binary.match(html, marker) do
      {index, length} ->
        count_occurrences(
          binary_part(html, index + length, byte_size(html) - index - length),
          marker,
          count + 1
        )

      :nomatch ->
        count
    end
  end

  # The text content of every slot element, in slot order — anchored on
  # the opening tag so neither the `-slots` wrapper nor the hook's own
  # selectors can match. Trimmed: the formatter may wrap the inner
  # block across lines (the hook normalizes whitespace on mount anyway).
  @slot_tag_regex ~r{<div\s+data-polaris-input-otp-slot\s+data-slot-index="\d+"[^>]*>([^<]*)</div>}

  defp slot_texts(html) do
    Regex.scan(@slot_tag_regex, html, capture: :all_but_first)
    |> Enum.map(fn [text] -> String.trim(text) end)
  end
end
