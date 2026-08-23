defmodule PolarisUI.Components.AvatarTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Avatar` — the port of
  the Supabase design system Avatar (Radix primitive): a 40px circular
  root clipping an image, layered over a bordered fallback that the
  colocated hook hides once the image loads.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Avatar

  @hook "PolarisUI.Components.Avatar.Image"

  defp render_avatar(assigns) do
    assigns =
      Map.merge(
        %{src: nil, alt: "", fallback: nil, class: nil, rest: %{}},
        assigns
      )

    rendered_to_string(~H"""
    <.avatar
      src={@src}
      alt={@alt}
      fallback={@fallback}
      class={@class}
      {assigns[:rest]}
    >
      {assigns[:inner]}
    </.avatar>
    """)
  end

  describe "anatomy" do
    test "renders the 40px circular clipping root" do
      html = render_avatar(%{src: "https://github.com/mildtomato.png", fallback: "MT"})

      class = root_class(html)
      assert class =~ "relative"
      assert class =~ "flex"
      assert class =~ "h-10 w-10"
      assert class =~ "shrink-0"
      assert class =~ "overflow-hidden"
      assert class =~ "rounded-full"
      assert html =~ ~s{data-polaris-avatar}
    end

    test "renders the image filling the circle" do
      html = render_avatar(%{src: "https://github.com/mildtomato.png", alt: "@mildtomato"})

      assert html =~ ~s{src="https://github.com/mildtomato.png"}
      assert html =~ ~s{alt="@mildtomato"}
      assert html =~ ~s{data-polaris-avatar-image}
      assert html =~ "aspect-square h-full w-full"
    end

    test "renders the bordered fallback circle with the initials" do
      html = render_avatar(%{src: "https://github.com/mildtomato.png", fallback: "MT"})

      assert html =~ ~s{data-polaris-avatar-fallback}
      assert html =~ "MT"

      fallback = marker_class(html, "data-polaris-avatar-fallback")
      assert fallback =~ "flex h-full w-full items-center justify-center"
      assert fallback =~ "rounded-full"
      assert fallback =~ "bg-surface-panel"
      assert fallback =~ "border border-surface-border"
    end

    test "the fallback renders rich inner block content after the initials" do
      html = render_avatar(%{src: "u.png", fallback: "MT", inner: {:safe, "<i>dot</i>"}})

      fallback = fallback_chunk(html)
      assert fallback =~ "MT"
      assert fallback =~ "<i>dot</i>"
      assert position(fallback, "MT") < position(fallback, "<i>dot</i>")
    end
  end

  describe "fallback wiring" do
    test "with src, the runtime hook ships and anchors on the root" do
      html = render_avatar(%{src: "u.png", fallback: "MT"})

      assert html =~ ~s{phx-hook="#{@hook}"}
      assert html =~ ~s{data-phx-runtime-hook="#{@hook}"}
      assert html =~ ~s{window["phx_hook_#{@hook}"]}
      assert html =~ "mounted()"
    end

    test "the hook hides the fallback on load and restores it on error" do
      html = render_avatar(%{src: "u.png"})

      assert html =~ "img.complete"
      assert html =~ "naturalWidth"
      assert html =~ ~s{addEventListener("load"}
      assert html =~ ~s{addEventListener("error"}
      assert html =~ ~s{classList.add("hidden")}
      assert html =~ ~s{classList.remove("hidden")}
    end

    test "the hook re-applies after LiveView patches" do
      html = render_avatar(%{src: "u.png"})

      assert html =~ "updated()"
      assert html =~ "_sync(this._loaded)"
    end

    test "without src, only the fallback renders and no hook ships" do
      html = render_avatar(%{fallback: "MT"})

      refute html =~ "data-polaris-avatar-image"
      refute html =~ "phx-hook"
      refute html =~ "data-phx-runtime-hook"
      assert html =~ "MT"
    end

    test "alt defaults to empty (decorative) for the image" do
      html = render_avatar(%{src: "u.png"})

      assert html =~ ~s{alt=""}
    end
  end

  describe "attributes" do
    test "caller classes resize the root — the documented size override" do
      html = render_avatar(%{src: "u.png", class: "h-12 w-12"})

      class = root_class(html)
      assert class =~ "h-12 w-12"
      refute class =~ "h-10"
    end

    test "forwards global attributes via rest" do
      html = render_avatar(%{rest: %{"id" => "user-avatar", "data-testid" => "avatar"}})

      assert html =~ ~s{id="user-avatar"}
      assert html =~ ~s{data-testid="avatar"}
    end
  end

  describe "accessibility" do
    test "the root is a non-interactive span with no role" do
      html = render_avatar(%{src: "u.png"})

      refute html =~ "role="
      refute html =~ "tabindex"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      html = render_avatar(%{src: "u.png", fallback: "MT"})

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

  # The class attribute of the element carrying the given marker. The
  # avatar renders `class=` before its `data-` markers, so search the
  # chunk preceding the marker and take the nearest class attribute.
  defp marker_class(html, marker) do
    [before_marker | _] = String.split(html, marker, parts: 2)

    before_marker
    |> String.split(~s{class="})
    |> List.last()
    |> String.split("\"")
    |> List.first()
  end

  defp root_class(html), do: marker_class(html, "data-polaris-avatar")

  # The chunk between the fallback marker and the closing root tag.
  defp fallback_chunk(html) do
    [_, after_marker | _] = String.split(html, "data-polaris-avatar-fallback", parts: 2)

    case :binary.match(after_marker, "</span>") do
      {index, _} -> binary_part(after_marker, 0, index)
      :nomatch -> after_marker
    end
  end
end
