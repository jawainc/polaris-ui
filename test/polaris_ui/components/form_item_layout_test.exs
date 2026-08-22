defmodule PolarisUI.Components.FormItemLayoutTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.FormItemLayout` — the
  four layout variants, label/description/error wiring, sizes, alignment,
  and accessibility, mirroring the Supabase design system fragment
  `ui-patterns/form/FormItemLayout` (label column, control, validation
  message, hint text).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.FormItemLayout

  describe "anatomy" do
    test "renders label, control, and data container with fragment ids" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="username" label="Username">
          <input id="username" />
        </.form_item_layout>
        """)

      assert html =~ ~s{data-polaris-form-item-layout}
      assert html =~ ~s{data-formlayout-id="labelContainer"}
      assert html =~ ~s{data-formlayout-id="dataContainer"}
      assert html =~ ~s{data-formlayout-id="label"}
      assert html =~ ~s{data-formlayout-id="nonBoxInputContainer"}
      assert html =~ "Username"
      assert html =~ ~s{<input id="username"}
    end

    test "the label is a real label wired for= to name or id" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="username" label="Username">
          <input />
        </.form_item_layout>
        """)

      assert html =~ ~s{<label for="username"}

      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="ignored" name="user_name" label="Username">
          <input />
        </.form_item_layout>
        """)

      assert html =~ ~s{<label for="user_name"}
    end

    test "label_optional renders beside the label on vertical" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="Username" label_optional="optional">
          <input />
        </.form_item_layout>
        """)

      assert html =~ "optional"
      assert html =~ ~s{id="f-optional"}
      assert html =~ ~s{data-formlayout-id="labelOptional"}
      assert html =~ "justify-between"
    end

    test "before_label and after_label slots render inside the label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="fn" label="Function name">
          <:before_label><span data-testid="before">Hint</span></:before_label>
          <:after_label><span data-testid="after">Beta</span></:after_label>
          <input />
        </.form_item_layout>
        """)

      assert html =~ ~s{id="fn-before"}
      assert html =~ ~s{id="fn-after"}
      assert html =~ ~s{data-formlayout-id="beforeLabel"}
      assert html =~ ~s{data-formlayout-id="afterLabel"}
      assert html =~ ~s{data-testid="before"}
      assert html =~ ~s{data-testid="after"}
    end

    test "description and error derive wiring ids from id" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" description="Must be unique" error="Already taken">
          <input />
        </.form_item_layout>
        """)

      assert html =~ ~s{id="f-description"}
      assert html =~ ~s{id="f-message"}
      assert html =~ "Must be unique"
      assert html =~ "Already taken"
    end

    test "error renders before description, like the fragment" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" description="Must be unique" error="Already taken">
          <input />
        </.form_item_layout>
        """)

      msg_index = html |> :binary.match("data-formlayout-id=\"message\"") |> elem(0)
      desc_index = html |> :binary.match("data-formlayout-id=\"description\"") |> elem(0)
      assert msg_index < desc_index
    end
  end

  describe "layout variants" do
    test "vertical is the default: stacked rows, label row justify-between" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L">
          <input />
        </.form_item_layout>
        """)

      container = container_class(html)

      assert container =~ "flex"
      assert container =~ "flex-col"
      assert container =~ "gap-2"
      label_container = label_container_class(html)
      assert label_container =~ "justify-between"
      data_container = data_container_class(html)
      assert data_container =~ "col-span-12"
    end

    test "horizontal: 12-col grid at md with 4/8 split" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" layout="horizontal">
          <input />
        </.form_item_layout>
        """)

      container = container_class(html)

      assert container =~ "md:grid"
      assert container =~ "md:grid-cols-12"
      label_container = label_container_class(html)
      assert label_container =~ "col-span-4"
      data_container = data_container_class(html)
      assert data_container =~ "col-span-8"
    end

    test "horizontal container_responsive swaps md for @xl container queries" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" layout="horizontal" container_responsive>
          <input />
        </.form_item_layout>
        """)

      container = container_class(html)

      assert container =~ "@xl:grid"
      assert container =~ "@xl:grid-cols-12"
      refute container =~ "md:grid-cols-12"
    end

    test "horizontal always renders the label column even without a label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout layout="horizontal">
          <input />
        </.form_item_layout>
        """)

      assert html =~ ~s{data-formlayout-id="labelContainer"}
    end

    test "vertical without any label content hides the label section" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout>
          <input />
        </.form_item_layout>
        """)

      refute html =~ ~s{data-formlayout-id="labelContainer"}
      assert html =~ ~s{data-formlayout-id="dataContainer"}
    end

    test "flex: control and label share a row, description and error under the label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="Use consistent settings" description="Why" layout="flex">
          <input type="checkbox" />
        </.form_item_layout>
        """)

      container = container_class(html)

      assert container =~ "flex-row"
      assert container =~ "gap-3"
      label_container = label_container_class(html)
      assert label_container =~ "order-2"

      # The control (dataContainer) precedes the label in the DOM.
      data_index = html |> :binary.match("data-formlayout-id=\"dataContainer\"") |> elem(0)
      label_index = html |> :binary.match("data-formlayout-id=\"labelContainer\"") |> elem(0)
      assert data_index < label_index

      # Description renders inside the label container.
      label_block = binary_window(html, label_index, 800)
      assert label_block =~ ~s{data-formlayout-id="description"}
    end

    test "flex with align=right pushes the label first and content last" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" layout="flex" align="right">
          <input />
        </.form_item_layout>
        """)

      container = container_class(html)
      assert container =~ "justify-between"
      label_container = label_container_class(html)
      assert label_container =~ "order-1"
    end

    test "flex-row-reverse: reversed stacking, half-width right-aligned content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" layout="flex-row-reverse">
          <input />
        </.form_item_layout>
        """)

      container = container_class(html)

      assert container =~ "flex-col-reverse"
      assert container =~ "md:flex-row-reverse"
      assert container =~ "md:gap-6"

      data_container = data_container_class(html)
      assert data_container =~ "md:w-1/2"
      assert data_container =~ "xl:w-2/5"
      assert data_container =~ "md:items-end"
    end
  end

  describe "error and message" do
    test "the message is danger red and animated" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" error="Already taken">
          <input />
        </.form_item_layout>
        """)

      assert html =~ "text-danger"
      assert html =~ "duration-300"
    end

    test "an error tints the label like FormLabel" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" error="Bad">
          <input />
        </.form_item_layout>
        """)

      label = label_class(html)
      assert label =~ "text-danger"
    end

    test "hide_message suppresses the error but keeps the label untinted" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" error="Bad" hide_message>
          <input />
        </.form_item_layout>
        """)

      refute html =~ ~s{data-formlayout-id="message"}
      refute label_class(html) =~ "text-danger"
    end

    test "no error renders no message node" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L">
          <input />
        </.form_item_layout>
        """)

      refute html =~ ~s{data-formlayout-id="message"}
    end
  end

  describe "sizes, non-box inputs, and overrides" do
    test "maps every Supabase text size" do
      sizes = %{
        "tiny" => "text-xs",
        "small" => "md:text-sm",
        "medium" => "md:text-sm",
        "large" => "text-base",
        "xlarge" => "text-base"
      }

      for {size, text_class} <- sizes do
        assigns = %{size: size}

        html =
          rendered_to_string(~H"""
          <.form_item_layout id="f" label="L" size={@size}>
            <input />
          </.form_item_layout>
          """)

        assert container_class(html) =~ text_class, "missing #{text_class} for size #{size}"
      end
    end

    test "invalid layout, align, or size raises a clear error" do
      assigns = %{}

      assert_raise ArgumentError, ~r/invalid value for :layout/, fn ->
        rendered_to_string(~H"""
        <.form_item_layout layout="diagonal">
          <input />
        </.form_item_layout>
        """)
      end

      assert_raise ArgumentError, ~r/invalid value for :align/, fn ->
        rendered_to_string(~H"""
        <.form_item_layout align="center">
          <input />
        </.form_item_layout>
        """)
      end

      assert_raise ArgumentError, ~r/invalid value for :size/, fn ->
        rendered_to_string(~H"""
        <.form_item_layout size="giant">
          <input />
        </.form_item_layout>
        """)
      end
    end

    test "non_box_input with a label adds breathing room per layout" do
      assigns = %{}

      vertical =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" non_box_input>
          <input type="checkbox" />
        </.form_item_layout>
        """)

      assert non_box_class(vertical) =~ "my-3"

      horizontal =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" layout="horizontal" non_box_input>
          <input type="checkbox" />
        </.form_item_layout>
        """)

      assert non_box_class(horizontal) =~ "md:mt-0"
    end

    test "non_box_input defaults to no-label and an explicit false wins" do
      assigns = %{}

      default =
        rendered_to_string(~H"""
        <.form_item_layout id="f">
          <input type="checkbox" />
        </.form_item_layout>
        """)

      # Derived true, but without a label the spacing class is inert
      # (the fragment only applies it when a label exists).
      refute non_box_class(default) =~ "my-3"

      explicit =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" non_box_input={false}>
          <input type="checkbox" />
        </.form_item_layout>
        """)

      refute non_box_class(explicit) =~ "my-3"
    end

    test "caller classes merge onto the root and globals pass through" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.form_item_layout id="f" label="L" class="w-full" data-test="x">
          <input />
        </.form_item_layout>
        """)

      container = container_class(html)

      assert container =~ "w-full"
      assert html =~ ~s{data-test="x"}
    end
  end

  defp container_class(html) do
    ~r{class="([^"]*)"[^>]*data-polaris-form-item-layout}
    |> Regex.run(html, capture: :all_but_first)
    |> List.first()
  end

  defp binary_window(html, start, len) do
    :binary.part(html, start, min(len, byte_size(html) - start))
  end

  defp label_container_class(html) do
    class_after(html, "data-formlayout-id=\"labelContainer\"")
  end

  defp data_container_class(html) do
    class_after(html, "data-formlayout-id=\"dataContainer\"")
  end

  defp label_class(html) do
    class_after(html, "data-formlayout-id=\"label\"")
  end

  defp non_box_class(html) do
    class_after(html, "data-formlayout-id=\"nonBoxInputContainer\"")
  end

  # class="..." directly precedes the data attribute in rendered markup;
  # returns "" when the element carries no class at all.
  defp class_after(html, marker) do
    idx = html |> :binary.match(marker) |> elem(0)
    before = :binary.part(html, 0, idx)

    case Regex.run(~r{class="([^"]*)"\s*$}, before, capture: :all_but_first) do
      [class] -> class
      nil -> ""
    end
  end
end
