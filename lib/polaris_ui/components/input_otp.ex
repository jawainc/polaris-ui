defmodule PolarisUI.Components.InputOTP do
  @moduledoc """
  The Polaris input OTP: the accessible one-time-password entry — the
  port of the Supabase design system Input OTP (`packages/ui`,
  `input-otp.tsx`, built on the `input-otp` library by @guilhermerodz).

  ## How it works

  The `input-otp` library renders one real `<input>` holding the whole
  code, overlaid invisibly on the slot row — clicking any slot focuses
  the input, and the caret position maps to the active slot. The port
  reproduces exactly that: the server renders the input plus the slot
  groups (chars from `value`), and a colocated runtime hook owns the
  slot choreography — sanitizing typed/pasted input against `pattern`
  and `max_length`, mirroring the value into the slots, tracking the
  active slot (emerald ring), and blinking the fake caret
  (`--animate-caret-blink`) in the active empty slot.

  The slot row lives in a `phx-update="ignore"` subtree so LiveView
  patches never fight the hook; the *input* stays server-controlled,
  and the hook's `updated()` re-syncs the slots after every patch.

  ## Anatomy

      <.input_otp id="otp" name="pin" max_length={6} group_size={3} value={@pin} phx-change="pin-changed" />

  `max_length` sets the slot count (the source's `maxLength`);
  `group_size` chunks the slots into groups joined by dot separators
  (the source's `InputOTPGroup` + `InputOTPSeparator` composition) —
  `group_size={3}` with `max_length={6}` renders the canonical 3+3
  two-factor layout.

  ## Controlled value

  `value` is the controlled code — drive it from your `phx-change`
  handler like any LiveView input; the hook re-renders the slots from
  the input's value after each patch. The server also normalizes it
  against `pattern` and `max_length` so the rendered HTML always shows
  a valid code.

  ## Keyboard & paste

  Typing appends at the caret (kept at the end, like the library);
  Backspace clears the previous slot; ArrowLeft/ArrowRight/Home/End
  move between slots; paste fills the whole code (sanitized against
  `pattern`, clamped to `max_length`); `autocomplete="one-time-code"`
  lets SMS codes autofill.

  ## Accessibility

    * Name the field for assistive tech via `aria-label` (through
      globals — the default is "Verification code"), or a
      `<.label for="otp-input">` bound to the inner input's id
      (`<id>-input`).
    * The slots are presentation only (the real input carries the
      value); the container dims while disabled
      (`has-[:disabled]:opacity-50`, the source's treatment).
    * `aria-invalid="true"` (through globals) marks the invalid state;
      pair it with `field_error` for the message.

  The colocated hook is a *runtime* hook, so it works without any JS
  bundler wiring in the consuming app (see
  `Phoenix.LiveView.ColocatedHook`).
  """

  use PolarisUI.Component

  @patterns ~w(any digits alnum)

  # Global attrs arrive string-keyed; these aliases cover callers that
  # pass the atom-keyed form. Compile-time literals only — no runtime
  # atom creation.
  @rest_key_aliases %{"autocomplete" => :autocomplete, "aria-label" => :"aria-label"}

  @doc """
  Renders the OTP input with its slot row.
  """
  attr(:id, :string,
    required: true,
    doc: """
    Unique id for the OTP root — the inner input gets `<id>-input`
    and the slot row `<id>-slots`.
    """
  )

  attr(:name, :string, default: nil, doc: "The form field name.")

  attr(:value, :string,
    default: "",
    doc: "The controlled code — normalized against `pattern` and sliced to `max_length`."
  )

  attr(:max_length, :integer,
    default: 6,
    doc: "The number of slots — the source's `maxLength`."
  )

  attr(:group_size, :integer,
    default: nil,
    doc: "Slots per group; groups are joined by dot separators (`nil` renders one group)."
  )

  attr(:pattern, :string,
    values: @patterns,
    default: "any",
    doc: """
    Accepted characters: `any`, `digits` (0-9), or `alnum`
    (a-z, A-Z, 0-9 — the input-otp `REGEXP_ONLY_DIGITS_AND_CHARS`).
    Applied on the server (rendered value) and by the hook (typed and
    pasted input).
    """
  )

  attr(:disabled, :boolean, default: false, doc: "Blocks entry and dims the slot row.")

  attr(:autofocus, :boolean, default: false, doc: "Focuses the input on mount.")

  attr(:class, :string,
    default: nil,
    doc:
      "Additional classes merged onto the visible container — the source's `containerClassName`."
  )

  attr(:rest, :global,
    doc: """
    Forwarded to the `<input>`: `phx-change`, `phx-blur`, `aria-label`
    (default "Verification code"), `aria-invalid`, `autocomplete`
    (default "one-time-code"), `data-*`, …
    """
  )

  def input_otp(assigns) do
    validate_in!(:pattern, assigns.pattern, @patterns)

    {autocomplete, rest} =
      pop_key(assigns.rest, "autocomplete") || {"one-time-code", assigns.rest}

    {aria_label, rest} = pop_key(rest, "aria-label") || {"Verification code", rest}

    assigns =
      assign(assigns,
        rest: rest,
        autocomplete: autocomplete,
        aria_label: aria_label,
        hook: "#{inspect(__MODULE__)}.Root",
        normalized_value: normalize_value(assigns.value, assigns.pattern, assigns.max_length),
        inputmode: inputmode(assigns.pattern)
      )

    ~H"""
    <div
      id={@id}
      data-polaris-input-otp
      data-max-length={to_string(@max_length)}
      data-pattern={@pattern}
      class={cn(["relative flex items-center gap-2 has-[:disabled]:opacity-50", @class])}
    >
      <input
        id={"#{@id}-input"}
        data-polaris-input-otp-input
        type="text"
        name={@name}
        value={@normalized_value}
        maxlength={to_string(@max_length)}
        autocomplete={@autocomplete}
        inputmode={@inputmode}
        aria-label={@aria_label}
        disabled={@disabled}
        autofocus={@autofocus}
        class="absolute inset-0 z-10 h-full w-full cursor-default bg-transparent p-0 opacity-0 outline-none"
        phx-hook={@hook}
        {@rest}
      />
      <div
        id={"#{@id}-slots"}
        phx-update="ignore"
        data-polaris-input-otp-slots
        class="flex items-center gap-2"
      >
        <%= for item <- slot_items(@normalized_value, @max_length, @group_size) do %>
          <%= if item == :separator do %>
            <div data-polaris-input-otp-separator role="separator" class="flex items-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="currentColor"
                class="size-4"
                aria-hidden="true"
              >
                <circle cx="12" cy="12" r="5" />
              </svg>
            </div>
          <% else %>
            <div data-polaris-input-otp-group class="flex items-center">
              <div
                :for={{char, index} <- item}
                data-polaris-input-otp-slot
                data-slot-index={to_string(index)}
                data-active="false"
                class={
                  cn([
                    "relative flex h-10 w-10 items-center justify-center border-y border-r border-surface-border",
                    "text-sm text-content-primary transition-all",
                    "first:rounded-l-md first:border-l last:rounded-r-md",
                    "data-[active=true]:z-10 data-[active=true]:ring-2 data-[active=true]:ring-brand-emerald",
                    "data-[active=true]:ring-offset-2 data-[active=true]:ring-offset-surface-ground"
                  ])
                }
              >
                {char}
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Root" runtime>
      {
        mounted() {
          const root = this.el.closest("[data-polaris-input-otp]")
          const slotsWrap = root.querySelector("[data-polaris-input-otp-slots]")
          this._root = root
          this._max = parseInt(root.dataset.maxLength || "6", 10)

          // The library's REGEXP_ONLY_* patterns, applied to typed and
          // pasted input alike.
          this._sanitize = (value) => {
            const pattern = root.dataset.pattern
            let out = value
            if (pattern === "digits") out = out.replace(/[^0-9]/g, "")
            else if (pattern === "alnum") out = out.replace(/[^a-zA-Z0-9]/g, "")
            return out.slice(0, this._max)
          }

          this._caretEl = () => {
            const wrap = document.createElement("div")
            wrap.className = "pointer-events-none absolute inset-0 flex items-center justify-center"
            wrap.dataset.polarisInputOtpCaret = "true"
            const bar = document.createElement("div")
            bar.className = "h-4 w-px animate-caret-blink bg-content-primary duration-1000"
            wrap.appendChild(bar)
            return wrap
          }

          // Mirror input.value into the slots: chars, active ring, and
          // the fake caret in the active empty slot.
          this._render = () => {
            const input = this.el
            const value = input.value
            const focused = document.activeElement === input
            const sel = input.selectionStart
            const activeIndex = Math.min(
              sel == null ? value.length : sel,
              Math.max(value.length, 0),
              this._max - 1
            )
            slotsWrap.querySelectorAll("[data-polaris-input-otp-slot]").forEach((slot) => {
              const i = parseInt(slot.dataset.slotIndex, 10)
              const char = value[i] || ""
              if (slot.textContent !== char) slot.textContent = char
              const isActive = focused && i === activeIndex
              slot.dataset.active = isActive ? "true" : "false"
              const caret = slot.querySelector("[data-polaris-input-otp-caret]")
              if (isActive && !char && !caret) slot.appendChild(this._caretEl())
              if ((!isActive || char) && caret) caret.remove()
            })
          }

          // Sanitize on capture at the root, before LiveView's own input
          // listeners read the value; keep the caret at the end like the
          // library.
          this._onInput = (event) => {
            if (event.target !== this.el) return
            const clean = this._sanitize(this.el.value)
            if (clean !== this.el.value) this.el.value = clean
            const at = Math.min(clean.length, this._max)
            try { this.el.setSelectionRange(at, at) } catch (_) {}
            this._render()
          }
          root.addEventListener("input", this._onInput, true)

          this._onSelectionChange = () => {
            if (document.activeElement === this.el) this._render()
          }
          document.addEventListener("selectionchange", this._onSelectionChange)

          this.el.addEventListener("focus", this._render)
          this.el.addEventListener("blur", this._render)
          this.el.addEventListener("keyup", this._render)

          this._render()
        },
        updated() {
          // The input's value is server-controlled; re-sync the slots.
          this._render()
        },
        destroyed() {
          if (!this._root) return
          this._root.removeEventListener("input", this._onInput, true)
          document.removeEventListener("selectionchange", this._onSelectionChange)
          this.el.removeEventListener("focus", this._render)
          this.el.removeEventListener("blur", this._render)
          this.el.removeEventListener("keyup", this._render)
        }
      }
    </script>
    """
  end

  # Slot rows: groups of `group_size` chars (or one group), interleaved
  # with :separator markers — Enum.map_intersperse keeps groups and
  # separators siblings under the flex slots row, so the source's
  # first:/last: rounding restarts per group.
  defp slot_items(value, max_length, nil) do
    [slot_group(value, 0, max_length - 1)]
  end

  defp slot_items(value, max_length, group_size) do
    0..(max_length - 1)
    |> Enum.chunk_every(group_size)
    |> Enum.map(fn indices -> slot_group(value, List.first(indices), List.last(indices)) end)
    |> Enum.map_intersperse(:separator, & &1)
  end

  defp slot_group(value, first, last) do
    Enum.map(first..last//1, fn i -> {String.at(value, i) || "", i} end)
  end

  defp normalize_value(value, pattern, max_length) when is_binary(value) do
    value
    |> apply_pattern(pattern)
    |> String.slice(0, max_length)
  end

  defp normalize_value(nil, _, _), do: ""

  defp apply_pattern(value, "digits"), do: String.replace(value, ~r/[^0-9]/, "")
  defp apply_pattern(value, "alnum"), do: String.replace(value, ~r/[^a-zA-Z0-9]/, "")
  defp apply_pattern(value, "any"), do: value

  defp inputmode("digits"), do: "numeric"
  defp inputmode(_), do: "text"

  # Pops a key from a global-attrs map whether it arrived string- or
  # atom-keyed. Returns nil when absent.
  defp pop_key(rest, key) when is_binary(key) do
    alias_key = Map.get(@rest_key_aliases, key)

    cond do
      is_map_key(rest, key) ->
        {Map.get(rest, key), Map.delete(rest, key)}

      alias_key && is_map_key(rest, alias_key) ->
        {Map.get(rest, alias_key), Map.delete(rest, alias_key)}

      true ->
        nil
    end
  end

  # `attr values:` only warns at compile time; raise at render time too so
  # dynamic assigns fail with a clear error instead of a FunctionClauseError.
  defp validate_in!(name, value, allowed) do
    unless value in allowed do
      raise ArgumentError,
            "invalid value for :#{name}: #{inspect(value)} — expected one of #{inspect(allowed)}"
    end
  end
end
