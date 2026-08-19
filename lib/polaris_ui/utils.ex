defmodule PolarisUI.Utils do
  @moduledoc """
  Shared helpers for Polaris UI components.

  The primary utility is `cn/1`, a Tailwind-aware CSS class merger. Every
  Polaris component accepts a `class` attribute (and often `rest` globals) and
  uses `cn/1` to merge its default utility classes with the caller's, so
  overrides work the way developers expect:

      <.button class="px-6 bg-surface-panel">Create table</.button>

  `cn/1` implements the conflict semantics of
  [tailwind-merge](https://github.com/dcastil/tailwind-merge) for the common
  Tailwind v4 utility families: when two classes target the same CSS property,
  the **later** one wins (earlier conflicting classes are dropped). Classes it
  does not recognize are passed through untouched and only deduplicated on
  exact match.

  Polaris components must never hardcode raw hex colors; all color utilities
  come from the `PolarisUI.Tokens` theme (`bg-surface-base`,
  `text-brand-emerald`, `border-surface-border`, ...).
  """

  @typedoc "Accepts nested lists, binaries, atoms, and nil values."
  @type class_input :: binary() | atom() | nil | [class_input()]

  @doc """
  Merges class lists into a single string, resolving Tailwind utility
  conflicts so that later classes win.

  ## Examples

      iex> cn("px-2 py-1 px-4")
      "py-1 px-4"

      iex> cn(["p-2", "px-4"])
      "p-2 px-4"

      iex> cn(["px-4", "p-2"])
      "p-2"

      iex> cn("text-sm text-xs text-center")
      "text-xs text-center"

      iex> cn("bg-surface-panel bg-surface-base")
      "bg-surface-base"

      iex> cn("border border-surface-border border-2")
      "border-surface-border border-2"

      iex> cn("hover:bg-emerald-500 bg-surface-base")
      "hover:bg-emerald-500 bg-surface-base"

      iex> cn("hover:bg-emerald-500 hover:bg-brand-emerald")
      "hover:bg-brand-emerald"

      iex> cn(["font-mono text-xs", nil, "font-mono", ["tracking-wide"]])
      "text-xs font-mono tracking-wide"

      iex> cn(nil)
      ""

  """
  @spec cn(class_input()) :: String.t()
  def cn(input) do
    input
    |> to_classes()
    |> resolve_conflicts()
    |> Enum.join(" ")
  end

  ## Normalization

  defp to_classes(input) do
    input
    |> flatten()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp flatten(list) when is_list(list), do: Enum.flat_map(list, &flatten/1)
  defp flatten(nil), do: []

  defp flatten(binary) when is_binary(binary),
    do: binary |> String.split(" ") |> Enum.map(&String.trim/1)

  defp flatten(atom) when is_atom(atom), do: [Atom.to_string(atom)]

  defp flatten(other),
    do:
      raise(
        ArgumentError,
        "expected a class string, atom, nil, or nested list, got: #{inspect(other)}"
      )

  ## Conflict resolution

  defp resolve_conflicts(classes) do
    classes
    |> Enum.map(&entry/1)
    |> Enum.reduce([], fn entry, acc ->
      [entry | Enum.reject(acc, fn earlier -> conflicts?(earlier, entry) end)]
    end)
    |> Enum.reverse()
    |> Enum.map(& &1.class)
  end

  defp entry(class) do
    {variant, base} = split_variant(class)
    {family, sub} = classify(base)

    %{class: class, variant: variant, family: family, sub: sub}
  end

  # An earlier entry is dropped when the later entry resolves the same CSS
  # property: identical group, or the later group is a parent (e.g. `p-2`
  # replaces an earlier `px-4`; `border-red-500` replaces `border-t-red-500`).
  defp conflicts?(earlier, later) do
    earlier.variant == later.variant and earlier.family == later.family and
      (earlier.sub == later.sub or earlier.sub in children(later.family, later.sub))
  end

  # Utilities with variant prefixes (`hover:`, `md:`, `group-hover:`,
  # `data-[state=open]:`, ...) only conflict within the same variant. The
  # split must ignore colons inside arbitrary values, e.g. `bg-[url(a:b)]`.
  defp split_variant(class) do
    case scan_variant(class, 0, 0, nil) do
      nil ->
        {"", class}

      idx ->
        size = byte_size(class)
        {binary_part(class, 0, idx), binary_part(class, idx + 1, size - idx - 1)}
    end
  end

  defp scan_variant(<<>>, _index, _depth, last), do: last

  defp scan_variant(<<char, rest::binary>>, index, depth, last) do
    case char do
      ?[ -> scan_variant(rest, index + 1, depth + 1, last)
      ?] -> scan_variant(rest, index + 1, depth - 1, last)
      ?: when depth == 0 -> scan_variant(rest, index + 1, depth, index)
      _ -> scan_variant(rest, index + 1, depth, last)
    end
  end

  ## Classification into conflict groups

  @exact_groups %{
    # display
    "block" => {:display, ""},
    "inline-block" => {:display, ""},
    "inline" => {:display, ""},
    "flex" => {:display, ""},
    "inline-flex" => {:display, ""},
    "grid" => {:display, ""},
    "inline-grid" => {:display, ""},
    "table" => {:display, ""},
    "inline-table" => {:display, ""},
    "flow-root" => {:display, ""},
    "contents" => {:display, ""},
    "list-item" => {:display, ""},
    "hidden" => {:display, ""},
    # position
    "static" => {:position, ""},
    "fixed" => {:position, ""},
    "absolute" => {:position, ""},
    "relative" => {:position, ""},
    "sticky" => {:position, ""},
    # visibility
    "visible" => {:visibility, ""},
    "invisible" => {:visibility, ""},
    "collapse" => {:visibility, ""},
    # font style / decoration / transform / overflow
    "italic" => {:font_style, ""},
    "not-italic" => {:font_style, ""},
    "underline" => {:text_decoration, ""},
    "overline" => {:text_decoration, ""},
    "line-through" => {:text_decoration, ""},
    "no-underline" => {:text_decoration, ""},
    "uppercase" => {:text_transform, ""},
    "lowercase" => {:text_transform, ""},
    "capitalize" => {:text_transform, ""},
    "normal-case" => {:text_transform, ""},
    "truncate" => {:text_overflow, ""},
    "text-ellipsis" => {:text_overflow, ""},
    "text-clip" => {:text_overflow, ""},
    "sr-only" => {:sr, ""},
    "not-sr-only" => {:sr, ""},
    "isolate" => {:isolation, ""},
    "isolation-auto" => {:isolation, ""},
    "filter" => {:filter, ""},
    "filter-none" => {:filter, ""},
    # bare `border` / `ring` are widths (1px / 1px)
    "border" => {:border_width, ""},
    "ring" => {:ring_width, ""}
  }

  @multi_groups [
                  {"border-x", :border_x},
                  {"border-y", :border_y},
                  {"border-t", :border_t},
                  {"border-r", :border_r},
                  {"border-b", :border_b},
                  {"border-l", :border_l},
                  {"border-s", :border_s},
                  {"border-e", :border_e},
                  {"ring-offset", :ring_offset},
                  {"divide-x", :divide_x},
                  {"divide-y", :divide_y},
                  {"space-x", {:space_x, ""}},
                  {"space-y", {:space_y, ""}},
                  {"min-w", {:min_w, ""}},
                  {"max-w", {:max_w, ""}},
                  {"min-h", {:min_h, ""}},
                  {"max-h", {:max_h, ""}},
                  {"gap-x", {:gap, "x"}},
                  {"gap-y", {:gap, "y"}},
                  {"grid-cols", {:grid_cols, ""}},
                  {"grid-rows", {:grid_rows, ""}},
                  {"col-span", {:col_span, ""}},
                  {"row-span", {:row_span, ""}},
                  {"col-start", {:col_start, ""}},
                  {"col-end", {:col_end, ""}},
                  {"row-start", {:row_start, ""}},
                  {"row-end", {:row_end, ""}},
                  {"overflow-x", {:overflow, "x"}},
                  {"overflow-y", {:overflow, "y"}},
                  {"overscroll-x", {:overscroll, "x"}},
                  {"overscroll-y", {:overscroll, "y"}},
                  {"flex-grow", {:flex_grow, ""}},
                  {"flex-shrink", {:flex_shrink, ""}},
                  {"underline-offset", {:underline_offset, ""}},
                  {"justify-items", {:justify_items, ""}},
                  {"justify-self", {:justify_self, ""}},
                  {"pointer-events", {:pointer_events, ""}},
                  {"scale-x", {:scale, "x"}},
                  {"scale-y", {:scale, "y"}},
                  {"translate-x", {:translate, "x"}},
                  {"translate-y", {:translate, "y"}},
                  {"skew-x", {:skew, "x"}},
                  {"skew-y", {:skew, "y"}},
                  {"mix-blend", {:mix_blend, ""}},
                  {"bg-blend", {:bg_blend, ""}}
                ]
                # Ensure longest stems match first ("border-t" before a hypothetical "border-tl")
                |> Enum.sort_by(fn {stem, _} -> byte_size(stem) end, :desc)
                |> Map.new()

  @stem_groups %{
    "p" => {:padding, ""},
    "px" => {:padding, "x"},
    "py" => {:padding, "y"},
    "pt" => {:padding, "t"},
    "pr" => {:padding, "r"},
    "pb" => {:padding, "b"},
    "pl" => {:padding, "l"},
    "ps" => {:padding, "s"},
    "pe" => {:padding, "e"},
    "m" => {:margin, ""},
    "mx" => {:margin, "x"},
    "my" => {:margin, "y"},
    "mt" => {:margin, "t"},
    "mr" => {:margin, "r"},
    "mb" => {:margin, "b"},
    "ml" => {:margin, "l"},
    "ms" => {:margin, "s"},
    "me" => {:margin, "e"},
    "gap" => {:gap, ""},
    "inset" => {:inset, ""},
    "top" => {:inset, "top"},
    "right" => {:inset, "right"},
    "bottom" => {:inset, "bottom"},
    "left" => {:inset, "left"},
    "start" => {:inset, "start"},
    "end" => {:inset, "end"},
    "w" => {:w, ""},
    "h" => {:h, ""},
    "size" => {:size, ""},
    "basis" => {:flex_basis, ""},
    "rounded" => {:rounded, ""},
    "shadow" => {:shadow, ""},
    "opacity" => {:opacity, ""},
    "z" => {:z, ""},
    "cursor" => {:cursor, ""},
    "aspect" => {:aspect, ""},
    "order" => {:order, ""},
    "columns" => {:columns, ""},
    "overflow" => {:overflow, ""},
    "overscroll" => {:overscroll, ""},
    "whitespace" => {:whitespace, ""},
    "leading" => {:leading, ""},
    "tracking" => {:tracking, ""},
    "duration" => {:duration, ""},
    "delay" => {:delay, ""},
    "ease" => {:ease, ""},
    "animate" => {:animate, ""},
    "accent" => {:accent, ""},
    "caret" => {:caret, ""},
    "fill" => {:fill, ""},
    "decoration" => {:decoration, ""},
    "outline" => {:outline, ""},
    "bg" => {:bg, ""},
    "select" => {:select, ""},
    "items" => {:items, ""},
    "justify" => {:justify, ""},
    "self" => {:self, ""},
    "box" => {:box_sizing, ""},
    "align" => {:vertical_align, ""},
    "clear" => {:clear, ""},
    "float" => {:float, ""},
    "resize" => {:resize, ""},
    "appearance" => {:appearance, ""},
    "origin" => {:origin, ""},
    "rotate" => {:rotate, ""},
    "scale" => {:scale, ""},
    "translate" => {:translate, ""},
    "skew" => {:skew, ""},
    "transition" => {:transition, ""},
    "line-clamp" => {:line_clamp, ""},
    "indent" => {:indent, ""}
  }

  @text_sizes ~w(xs sm base lg xl 2xl 3xl 4xl 5xl 6xl 7xl 8xl 9xl)
  @text_aligns ~w(left center right justify start end)
  @text_wraps ~w(wrap nowrap balance pretty)
  @font_families ~w(sans serif mono)
  @font_weights ~w(thin extralight light normal medium semibold bold extrabold black)
  @border_styles ~w(solid dashed dotted double none hidden)
  @flex_directions ~w(row row-reverse col col-reverse)
  @flex_wraps ~w(wrap wrap-reverse nowrap)
  @flex_grow_shrink ~w(1 auto none initial)
  @list_types ~w(none disc decimal)
  @list_positions ~w(inside outside)

  defp classify(base) do
    base = base |> strip_important() |> strip_negative()

    cond do
      group = Map.get(@exact_groups, base) -> group
      group = multi_group(base) -> group
      true -> stem_group(base)
    end
  end

  defp strip_important("!" <> rest), do: strip_important(rest)
  defp strip_important(base), do: String.trim_trailing(base, "!")
  defp strip_negative("-" <> rest), do: rest
  defp strip_negative(base), do: base

  defp multi_group(base) do
    Enum.find_value(@multi_groups, fn {stem, group} ->
      suffix = stem <> "-"

      if String.starts_with?(base, suffix) do
        value = binary_part(base, byte_size(suffix), byte_size(base) - byte_size(suffix))
        multi_group(group, value)
      end
    end)
  end

  defp multi_group(:border_x, value), do: border_group("x", value)
  defp multi_group(:border_y, value), do: border_group("y", value)
  defp multi_group(:border_t, value), do: border_group("t", value)
  defp multi_group(:border_r, value), do: border_group("r", value)
  defp multi_group(:border_b, value), do: border_group("b", value)
  defp multi_group(:border_l, value), do: border_group("l", value)
  defp multi_group(:border_s, value), do: border_group("s", value)
  defp multi_group(:border_e, value), do: border_group("e", value)

  defp multi_group(:ring_offset, value) do
    if width_value?(value), do: {:ring_offset_width, ""}, else: {:ring_offset_color, ""}
  end

  defp multi_group(:divide_x, _value), do: {:divide_width, "x"}
  defp multi_group(:divide_y, _value), do: {:divide_width, "y"}
  defp multi_group({family, sub}, _value), do: {family, sub}

  # `border-{side}-{value}`: width / style / color are decided by the value.
  defp border_group(side, value) do
    cond do
      value in @border_styles -> {:border_style, side}
      width_value?(value) -> {:border_width, side}
      true -> {:border_color, side}
    end
  end

  defp stem_group(base) do
    [stem | rest] = String.split(base, "-", parts: 2)
    value = List.first(rest, "")
    stem_group(stem, value)
  end

  defp stem_group("text", value) do
    cond do
      value in @text_aligns -> {:text_align, ""}
      value in @text_wraps -> {:text_wrap, ""}
      value in @text_sizes -> {:text_size, ""}
      length_value?(value) -> {:text_size, ""}
      true -> {:text_color, ""}
    end
  end

  defp stem_group("font", value) do
    cond do
      value in @font_families -> {:font_family, ""}
      value in @font_weights -> {:font_weight, ""}
      value =~ ~r/^\d/ -> {:font_weight, ""}
      true -> {:unknown, base_key("font", value)}
    end
  end

  defp stem_group("ring", value) do
    cond do
      value == "inset" -> {:ring_style, ""}
      width_value?(value) -> {:ring_width, ""}
      true -> {:ring_color, ""}
    end
  end

  defp stem_group("border", value), do: border_group("", value)

  defp stem_group("flex", value) do
    cond do
      value == "" -> {:display, ""}
      value in @flex_directions -> {:flex_direction, ""}
      value in @flex_wraps -> {:flex_wrap, ""}
      value in @flex_grow_shrink -> {:flex_grow_shrink, ""}
      true -> {:unknown, base_key("flex", value)}
    end
  end

  defp stem_group("grid", value) do
    if value == "", do: {:display, ""}, else: {:unknown, base_key("grid", value)}
  end

  defp stem_group("stroke", value) do
    if value =~ ~r/^[\d.]/, do: {:stroke_width, ""}, else: {:stroke_color, ""}
  end

  defp stem_group("backdrop", value) do
    {:backdrop, value |> String.split("-", parts: 2) |> List.first()}
  end

  defp stem_group("divide", _value), do: {:divide_color, ""}

  defp stem_group("object", value) when value in ~w(contain cover fill none scale-down),
    do: {:object_fit, ""}

  defp stem_group("object", _value), do: {:object_position, ""}

  defp stem_group("list", value) when value in @list_positions, do: {:list_position, ""}
  defp stem_group("list", value) when value in @list_types, do: {:list_type, ""}

  defp stem_group(stem, value) do
    case Map.get(@stem_groups, stem) do
      nil -> {:unknown, base_key(stem, value)}
      group -> group
    end
  end

  defp base_key(stem, ""), do: stem
  defp base_key(stem, value), do: stem <> "-" <> value

  # Later parent utilities override earlier per-side ones (px-4 p-2 -> p-2,
  # inset-x-2 top-4 -> ..., border-red-500 border-t-red-500 -> ...).
  defp children(:padding, ""), do: ~w(x y t r b l s e)
  defp children(:padding, "x"), do: ~w(l r)
  defp children(:padding, "y"), do: ~w(t b)

  defp children(:margin, sub), do: children(:padding, sub)
  defp children(:inset, ""), do: ~w(top right bottom left start end)
  defp children(:gap, ""), do: ~w(x y)

  defp children(family, "") when family in [:border_width, :border_color, :border_style],
    do: ~w(x y t r b l s e)

  defp children(family, "x") when family in [:border_width, :border_color, :border_style],
    do: ~w(l r)

  defp children(family, "y") when family in [:border_width, :border_color, :border_style],
    do: ~w(t b)

  defp children(_, _), do: []

  ## Value classification

  # Width-ish values: plain numbers (2, 2.5, 0) or arbitrary lengths ([3px]).
  defp width_value?(value) do
    value =~ ~r/^\d+(\.\d+)?$/ or length_value?(value)
  end

  defp length_value?("[" <> _ = value) do
    String.ends_with?(value, "]") and
      (String.contains?(value, ["px", "rem", "em", "%", "vw", "vh", "ch"]) or
         String.starts_with?(value, "[length:"))
  end

  defp length_value?(""), do: true
  defp length_value?(_), do: false
end
