defmodule PolarisUI.Components.Avatar do
  @moduledoc """
  The Polaris avatar: an image element with a fallback for representing
  the user.

  Port of the Supabase design system Avatar (`packages/ui`, built on the
  Radix Avatar primitive): a 40px circular root (`span`) that clips an
  image to the circle, layered over a bordered fallback that renders
  whenever the image has not loaded — while loading, when `src` is
  missing, or when the image fails.

  ## Anatomy

      <.avatar
        src="https://github.com/mildtomato.png"
        alt="@mildtomato"
        fallback="MT"
      />

    * **root** — `relative flex h-10 w-10 shrink-0 overflow-hidden
      rounded-full`; size and shape are overridden through `class` (there
      are no size variants upstream — `class="h-12 w-12"` for the 48px
      treatment).
    * **image** — `aspect-square h-full w-full`, filling the circle.
    * **fallback** — a full-size bordered surface circle centering the
      fallback content (initials like `MT`); text color and size inherit
      from the surrounding context, exactly like the primitive.

  ## Fallback behavior

  The server renders the fallback visible; the colocated runtime hook
  hides it the moment the image finishes loading (and restores it on
  error) — the LiveView equivalent of Radix's load-status tracking. With
  no `src`, nothing loads and the fallback stands alone, no hook shipped.

  ## Accessibility

    * `alt` is forwarded to the `<img>`; pass the handle form
      (`alt="@mildtomato"`) when the avatar is the only identification, or
      `alt=""` (the default) for decorative avatars next to text that
      already names the user.
    * The root is a non-interactive `<span>` — no role or `aria-*` is
      added (matching the primitive); semantics come from the image or the
      adjacent text.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  attr(:src, :string,
    default: nil,
    doc: "Image URL. When nil, only the fallback renders and no hook ships."
  )

  attr(:alt, :string,
    default: "",
    doc: """
    `<img>` alt text — `"@handle"` when the avatar stands alone, `""`
    (the default) when adjacent text already identifies the user.
    """
  )

  attr(:fallback, :string,
    default: nil,
    doc: "Initials or short text shown until the image loads / when it fails (\"MT\")."
  )

  attr(:class, :string,
    default: nil,
    doc: """
    Additional classes merged onto the root — the supported way to resize
    (`class="h-12 w-12"`), since upstream ships no size variants.
    """
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the root `<span>`: `id`, `data-*`, `phx-*`, …
    """
  )

  slot(:inner_block,
    doc: """
    Rich fallback content, rendered inside the fallback circle after the
    `fallback` initials — e.g. a status dot or a custom glyph.
    """
  )

  def avatar(assigns) do
    assigns =
      assigns
      |> assign(
        root_classes:
          cn(["relative flex h-10 w-10 shrink-0 overflow-hidden rounded-full", assigns.class]),
        fallback_classes:
          cn([
            "flex h-full w-full items-center justify-center rounded-full",
            "bg-surface-panel border border-surface-border"
          ]),
        hook: if(assigns.src, do: "#{inspect(__MODULE__)}.Image", else: nil)
      )

    ~H"""
    <span class={@root_classes} data-polaris-avatar phx-hook={@hook} {@rest}>
      <img
        :if={@src}
        src={@src}
        alt={@alt}
        class="aspect-square h-full w-full"
        data-polaris-avatar-image
      />
      <span class={@fallback_classes} data-polaris-avatar-fallback>
        {@fallback}{render_slot(@inner_block)}
      </span>
    </span>
    <script :if={@src} :type={Phoenix.LiveView.ColocatedHook} name=".Image" runtime>
      {
        mounted() {
          this._loaded = false
          this._sync = (loaded) => {
            this._loaded = loaded
            const fallback = this.el.querySelector("[data-polaris-avatar-fallback]")
            if (!fallback) return
            if (loaded) {
              fallback.classList.add("hidden")
            } else {
              fallback.classList.remove("hidden")
            }
          }
          const img = this.el.querySelector("[data-polaris-avatar-image]")
          if (!img) return
          if (img.complete && img.naturalWidth > 0) {
            this._sync(true)
            return
          }
          this._onLoad = () => this._sync(true)
          this._onError = () => this._sync(false)
          img.addEventListener("load", this._onLoad)
          img.addEventListener("error", this._onError)
        },
        updated() {
          // Re-apply after LiveView patches, which may restore the fallback.
          if (this._sync) this._sync(this._loaded)
        },
        destroyed() {
          const img = this.el.querySelector("[data-polaris-avatar-image]")
          if (img) {
            if (this._onLoad) img.removeEventListener("load", this._onLoad)
            if (this._onError) img.removeEventListener("error", this._onError)
          }
        }
      }
    </script>
    """
  end
end
