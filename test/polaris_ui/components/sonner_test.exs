defmodule PolarisUI.Components.SonnerTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Sonner` — the port of
  the Supabase design system Sonner: the toaster stack, the unstyled
  toast panel, the payload builder, and the client-side lifecycle the
  hook owns.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Sonner

  @hook "PolarisUI.Components.Sonner.Toaster"

  defp render_toaster(assigns) do
    assigns =
      Map.merge(
        %{
          id: "toaster",
          position: "bottom-right",
          duration: 4000,
          visible: 3,
          gap: 14,
          offset: 24,
          expand: false,
          close_button: true,
          class: nil,
          rest: %{}
        },
        assigns
      )

    rendered_to_string(~H"""
    <.toaster
      id={@id}
      position={@position}
      duration={@duration}
      visible={@visible}
      gap={@gap}
      offset={@offset}
      expand={@expand}
      close_button={@close_button}
      class={@class}
      {assigns[:rest]}
    />
    """)
  end

  describe "the stack" do
    test "renders the notifications region with an empty fixed list" do
      html = render_toaster(%{})

      assert html =~ ~s{aria-label="Notifications"}
      assert html =~ ~s{aria-live="polite"}
      assert html =~ "data-polaris-sonner-list"
    end

    test "the list rides above every layer, sonner-style" do
      html = render_toaster(%{})

      assert html =~ "z-index: 999999999"
      assert html =~ "width: min(356px, calc(100vw - 32px));"
    end

    test "defaults carry the sonner contract" do
      html = render_toaster(%{})

      assert html =~ ~s{data-position="bottom-right"}
      assert html =~ ~s{data-duration="4000"}
      assert html =~ ~s{data-visible="3"}
      assert html =~ ~s{data-gap="14"}
      assert html =~ ~s{data-close-button="true"}
      assert html =~ ~s{data-expand="false"}
    end

    test "rejects an unknown position" do
      assert_raise ArgumentError, ~r/:position/, fn ->
        render_toaster(%{position: "middle-left"})
      end
    end
  end

  describe "positions" do
    test "bottom-right pins to the bottom-right corner" do
      html = render_toaster(%{position: "bottom-right"})

      assert html =~ "bottom: 24px; right: 24px;"
    end

    test "top-left pins to the top-left corner" do
      html = render_toaster(%{position: "top-left", offset: 16})

      assert html =~ "top: 16px; left: 16px;"
    end

    test "top-center centers on the top edge" do
      html = render_toaster(%{position: "top-center"})

      assert html =~ "top: 24px; left: 50%; transform: translateX(-50%);"
    end

    test "the custom offset reaches the style" do
      html = render_toaster(%{offset: 32})

      assert html =~ "bottom: 32px; right: 32px;"
    end
  end

  describe "colocated hook" do
    test "anchors the runtime hook on the root and ships its script inline" do
      html = render_toaster(%{})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "listens for server pushes on the sonner channel" do
      html = render_toaster(%{})

      assert html =~ ~s{this._listen("sonner"}
      assert html =~ "handleEvent"
    end

    test "toasts enter from the position edge over 400ms and exit over 200ms" do
      html = render_toaster(%{})

      assert html =~ "translateY(100%)"
      assert html =~ "translateX(100%)"
      assert html =~ "transform 400ms ease, opacity 400ms ease, height 400ms ease"
      assert html =~ "transform 200ms ease-out, opacity 200ms ease-out"
    end

    test "the stack collapses and expands like sonner" do
      html = render_toaster(%{})

      assert html =~ "scale("
      assert html =~ "pointerenter"
      assert html =~ "pointerleave"
      assert html =~ "Escape"
    end

    test "timers pause on hover and loading never auto-closes" do
      html = render_toaster(%{})

      assert html =~ "_pauseTimers"
      assert html =~ "_resumeTimers"
      assert html =~ ~s{toast.type === "loading" || toast.duration === Infinity}
    end

    test "swipe dismisses at 45px or a fast fling" do
      html = render_toaster(%{})

      assert html =~ "travel >= 45 || velocity > 0.11"
    end

    test "action and cancel buttons push their LiveView events and dismiss" do
      html = render_toaster(%{})

      assert html =~ "[data-action]"
      assert html =~ "[data-cancel]"
      assert html =~ "this._push(toast.action.event)"
      assert html =~ "this._push(toast.cancel.event)"
      assert html =~ "pushEvent"
    end
  end

  describe "toast payload styling" do
    test "the default toast is the unstyled-mode panel" do
      html = render_toaster(%{})

      assert html =~
               "group pointer-events-auto flex w-full items-start gap-2 rounded-md border px-5 py-3 text-sm font-normal shadow-lg"

      assert html =~ "bg-surface-panel border-surface-border text-content-primary"
    end

    test "warning and error toasts tint like the source's per-type classes" do
      html = render_toaster(%{})

      assert html =~ "bg-warning-muted border-warning"
      assert html =~ "bg-danger-muted border-danger"
    end

    test "the icon set — check, badges, spinner" do
      html = render_toaster(%{})

      assert html =~ "text-brand-emerald"
      assert html =~ "animate-spin"
      assert html =~ "_badgeIcon"
      assert html =~ "_infoPath"
      assert html =~ "_warningPath"
      assert html =~ "_errorPath"
    end

    test "the description hides on collapsed non-front toasts" do
      html = render_toaster(%{})

      assert html =~ "text-xs text-content-muted transition-opacity"
      assert html =~ "description.style.opacity ="
    end

    test "the close button surfaces on hover" do
      html = render_toaster(%{})

      assert html =~ "group-hover:opacity-100"
      assert html =~ ~s{aria-label="Dismiss notification"}
    end

    test "action and cancel wear the tiny button scales" do
      html = render_toaster(%{})

      assert html =~ "h-[26px] px-2.5 py-1 text-xs"
      assert html =~ "border-brand-border bg-brand-fill"
      assert html =~ "border-surface-border bg-surface-panel"
    end

    test "toast text is escaped against markup injection" do
      html = render_toaster(%{})

      assert html =~ "textContent"
      assert html =~ "innerHTML"
    end
  end

  describe "toast/2 payload builder" do
    test "a bare message renders the minimal payload" do
      assert toast("Row copied") == %{message: "Row copied", type: "default"}
    end

    test "options ride along — type, description, action, cancel, id, close_button" do
      payload =
        toast("Project deleted",
          type: "success",
          description: "Its data was removed.",
          action: %{label: "Undo", event: "undo-delete"},
          cancel: %{label: "Dismiss", event: "noop"},
          id: "delete-toast",
          close_button: false
        )

      assert payload[:type] == "success"
      assert payload[:description] == "Its data was removed."
      assert payload[:action] == %{label: "Undo", event: "undo-delete"}
      assert payload[:cancel] == %{label: "Dismiss", event: "noop"}
      assert payload[:id] == "delete-toast"
      assert payload[:close_button] == false
    end

    test "durations encode — ms integers pass through, :infinity sticks" do
      assert toast("Uploading…", duration: 2000)[:duration] == 2000
      assert toast("Uploading…", duration: :infinity)[:duration] == ":infinity"
      refute Map.has_key?(toast("Row copied"), :duration)
    end

    test "rejects an unknown type" do
      assert_raise ArgumentError, ~r/:type/, fn ->
        toast("Broken", type: "critical")
      end
    end

    test "rejects a non-integer duration" do
      assert_raise ArgumentError, ~r/:duration/, fn ->
        toast("Broken", duration: :soon)
      end
    end
  end

  describe "attributes" do
    test "forwards global attributes via rest" do
      html = render_toaster(%{rest: %{"data-testid" => "app-toaster"}})

      assert html =~ ~s{data-testid="app-toaster"}
    end

    test "caller classes merge onto the stack list" do
      html = render_toaster(%{class: "my-8"})

      assert html =~ "my-8"
    end

    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_toaster(%{})

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
