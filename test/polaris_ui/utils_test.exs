defmodule PolarisUI.UtilsTest do
  use ExUnit.Case, async: true

  import PolarisUI.Utils
  doctest PolarisUI.Utils

  alias PolarisUI.Utils

  describe "cn/1 conflict resolution" do
    test "parent spacing utilities replace per-side ones" do
      assert Utils.cn("p-4 px-2") == "p-4 px-2"
      assert Utils.cn("px-2 p-4") == "p-4"
      assert Utils.cn("mx-2 my-4 mx-6") == "my-4 mx-6"
    end

    test "per-side utilities replace their own side only" do
      assert Utils.cn("pl-2 pl-4") == "pl-4"
      assert Utils.cn("pl-2 pr-4") == "pl-2 pr-4"
      assert Utils.cn("px-2 pl-4") == "px-2 pl-4"
      assert Utils.cn("pl-2 px-4") == "px-4"
    end

    test "border width, style, and color are independent groups" do
      assert Utils.cn("border-2 border-4") == "border-4"
      assert Utils.cn("border-2 border-dashed") == "border-2 border-dashed"
      assert Utils.cn("border-surface-border border-red-500") == "border-red-500"
      # all-sides width replaces side widths when it comes later
      assert Utils.cn("border-t-2 border-4") == "border-4"
      assert Utils.cn("border-4 border-t-2") == "border-4 border-t-2"
      # all-sides color replaces side colors when it comes later
      assert Utils.cn("border-t-emerald-500 border-brand-emerald") == "border-brand-emerald"
    end

    test "text size, color, and alignment do not conflict" do
      assert Utils.cn("text-xs text-sm") == "text-sm"
      assert Utils.cn("text-brand-emerald text-content-secondary") == "text-content-secondary"

      assert Utils.cn("text-xs text-center text-brand-emerald text-lg") ==
               "text-center text-brand-emerald text-lg"
    end

    test "font family and weight are independent" do
      assert Utils.cn("font-sans font-mono") == "font-mono"
      assert Utils.cn("font-medium font-semibold") == "font-semibold"
      assert Utils.cn("font-mono font-semibold") == "font-mono font-semibold"
    end

    test "variants only conflict within the same variant" do
      assert Utils.cn("md:px-2 px-4") == "md:px-2 px-4"
      assert Utils.cn("md:px-2 md:px-4") == "md:px-4"
      assert Utils.cn("md:hover:bg-a md:hover:bg-b") == "md:hover:bg-b"

      assert Utils.cn("hover:border-surface-border hover:border-surface-border-hover") ==
               "hover:border-surface-border-hover"
    end

    test "variant detection ignores colons inside arbitrary values" do
      assert Utils.cn("bg-[url(data:image/png;base64,AAA)] bg-surface-base") == "bg-surface-base"
    end

    test "display utilities replace each other" do
      assert Utils.cn("flex hidden") == "hidden"
      assert Utils.cn(["flex", nil, ["hidden"]]) == "hidden"
      assert Utils.cn("inline-flex grid") == "grid"
    end

    test "important modifiers are treated as the same utility" do
      assert Utils.cn("px-2! px-4") == "px-4"
      assert Utils.cn("!px-2 px-4") == "px-4"
    end

    test "negative utilities conflict with their positive counterparts" do
      assert Utils.cn("-ml-2 ml-4") == "ml-4"
      assert Utils.cn("-ml-2 -ml-4") == "-ml-4"
    end

    test "arbitrary lengths resolve as widths/sizes, not colors" do
      assert Utils.cn("border-2 border-[3px]") == "border-[3px]"
      assert Utils.cn("border-red-500 border-[#fff]") == "border-[#fff]"
      # width and color are independent utilities
      assert Utils.cn("ring-2 ring-brand-emerald") == "ring-2 ring-brand-emerald"
      assert Utils.cn("ring-2 ring-4") == "ring-4"
      assert Utils.cn("ring-red-500 ring-brand-emerald") == "ring-brand-emerald"
    end

    test "gap and space utilities" do
      assert Utils.cn("gap-2 gap-4") == "gap-4"
      assert Utils.cn("gap-2 gap-x-4") == "gap-2 gap-x-4"
      assert Utils.cn("gap-x-2 gap-4") == "gap-4"
      assert Utils.cn("space-x-2 space-y-4") == "space-x-2 space-y-4"
    end

    test "inset utilities" do
      assert Utils.cn("top-2 top-4") == "top-4"
      assert Utils.cn("top-2 right-4 inset-0") == "inset-0"
    end
  end

  describe "cn/1 input handling" do
    test "unknown classes are deduplicated on exact match only" do
      assert Utils.cn("i-made-this-up i-made-this-up") == "i-made-this-up"
      assert Utils.cn("i-made-this-up another-unknown") == "i-made-this-up another-unknown"
    end

    test "flattens arbitrarily nested lists with nils and whitespace" do
      assert Utils.cn(["a  b", nil, ["c", [" d "]]]) == "a b c d"
      assert Utils.cn([]) == ""
      assert Utils.cn("") == ""
    end

    test "accepts atoms" do
      assert Utils.cn(:flex) == "flex"
      assert Utils.cn([:font_mono, "text-xs"]) == "font_mono text-xs"
      assert Utils.cn([:flex, "hidden"]) == "hidden"
    end

    test "raises on unsupported input" do
      assert_raise ArgumentError, ~r/expected a class string/, fn ->
        Utils.cn([123])
      end
    end
  end

  describe "slot_content?/2" do
    test "an empty slot list is no content" do
      refute Utils.slot_content?([], %{})
    end

    test "detects content behind closure inner blocks (dynamic templates)" do
      content = %{inner_block: fn _assigns, _arg -> ["Create table"] end}
      assert Utils.slot_content?([content], %{})
    end

    test "whitespace-only closures are blank" do
      blank = %{inner_block: fn _assigns, _arg -> [" \n "] end}
      refute Utils.slot_content?([blank], %{})
    end

    test "detects content behind inlined Rendered inner blocks (static templates)" do
      rendered = %Phoenix.LiveView.Rendered{
        static: ["Create table"],
        dynamic: fn _changed -> [] end,
        fingerprint: 1,
        root: nil
      }

      assert Utils.slot_content?([%{inner_block: rendered}], %{})
    end

    test "closures render against the component assigns, like render_slot" do
      assigns = %{label: "Deploy project"}

      entry = %{inner_block: fn assigns, _arg -> [assigns.label] end}

      assert Utils.slot_content?([entry], assigns)
    end

    test "a nil inner block is blank, not a crash" do
      refute Utils.slot_content?([%{inner_block: nil}], %{})
    end
  end
end
