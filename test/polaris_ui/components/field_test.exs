defmodule PolarisUI.Components.FieldTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Field` — the port of
  the Supabase design system Field: the presentational field anatomy
  (set, legend, group, field, label, content, title, description,
  separator, error).
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Field

  describe "field_set" do
    test "renders a semantic fieldset whose gap tightens for choice groups" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_set>
          <legend>Profile</legend>
        </.field_set>
        """)

      assert html =~ "data-polaris-field-set"
      assert html =~ "<fieldset"
      assert html =~ "flex flex-col gap-6"

      assert html =~
               "has-[&gt;[data-slot=checkbox-group]]:gap-3 has-[&gt;[data-slot=radio-group]]:gap-3"
    end
  end

  describe "field_legend" do
    test "renders a legend at base scale by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_legend>Profile</.field_legend>
        """)

      assert html =~ "data-polaris-field-legend"
      assert html =~ "<legend"
      assert html =~ "mb-3 font-medium"
      assert html =~ "data-[variant=legend]:text-base"
      assert html =~ ~s{data-variant="legend"}
    end

    test "variant=label drops to label scale" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_legend variant="label">Notification preferences</.field_legend>
        """)

      assert html =~ "data-[variant=label]:text-sm"
      assert html =~ ~s{data-variant="label"}
    end

    test "rejects an unknown variant" do
      assigns = %{}

      assert_raise ArgumentError, ~r/:variant/, fn ->
        rendered_to_string(~H"""
        <.field_legend variant="title">x</.field_legend>
        """)
      end
    end
  end

  describe "field_group" do
    test "establishes the named container query for responsive fields" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_group>
          <div>x</div>
        </.field_group>
        """)

      assert html =~ "data-polaris-field-group"
      assert html =~ "@container/field-group flex w-full flex-col gap-7"
      assert html =~ "group/field-group"
    end
  end

  describe "field" do
    test "renders a group with the vertical default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field>
          <.field_label for="name">Full name</.field_label>
        </.field>
        """)

      assert html =~ "data-polaris-field"
      assert html =~ ~s{role="group"}
      assert html =~ ~s{data-orientation="vertical"}
      assert html =~ "group/field data-[invalid=true]:text-danger flex w-full gap-3"
      assert html =~ "flex-col *:w-full"
    end

    test "horizontal aligns label and control on one row" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field orientation="horizontal">
          <.field_label for="newsletter">Subscribe</.field_label>
        </.field>
        """)

      assert html =~ ~s{data-orientation="horizontal"}
      assert html =~ "flex-row items-center"
      assert html =~ "*:data-[slot=field-label]:flex-auto"
    end

    test "responsive switches at the group's @md container width" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field orientation="responsive">
          <.field_label for="email">Email</.field_label>
        </.field>
        """)

      assert html =~ ~s{data-orientation="responsive"}

      assert html =~
               "@md/field-group:flex-row @md/field-group:items-center @md/field-group:*:w-auto flex-col *:w-full"
    end

    test "invalid sets data-invalid and turns the block danger" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field invalid>
          <.field_label for="username">Username</.field_label>
        </.field>
        """)

      assert html =~ ~s{data-invalid="true"}
      assert html =~ "data-[invalid=true]:text-danger"
    end

    test "invalid is omitted when false" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field>x</.field>
        """)

      refute html =~ "data-invalid"
    end

    test "disabled sets data-disabled for the label/title dimming" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field disabled>x</.field>
        """)

      assert html =~ ~s{data-disabled="true"}
    end

    test "rejects an unknown orientation" do
      assigns = %{}

      assert_raise ArgumentError, ~r/:orientation/, fn ->
        rendered_to_string(~H"""
        <.field orientation="diagonal">x</.field>
        """)
      end
    end
  end

  describe "field_content" do
    test "renders the label/description column" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_content>
          <.field_title>Enable Touch ID</.field_title>
        </.field_content>
        """)

      assert html =~ "data-polaris-field-content"
      assert html =~ ~s{data-slot="field-content"}
      assert html =~ "group/field-content flex flex-1 flex-col gap-1.5 leading-snug"
    end
  end

  describe "field_label" do
    test "renders a real label wired by for" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_label for="name">Full name</.field_label>
        """)

      assert html =~ "data-polaris-field-label"
      assert html =~ "<label"
      assert html =~ ~s{for="name"}
      assert html =~ "Full name"
      assert html =~ "group/field-label peer/field-label flex w-fit gap-2"
      assert html =~ "group-data-[disabled=true]/field:opacity-50"
    end

    test "wrapping a field builds the choice card treatment" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_label for="plan">
          <.field>
            <.field_title>Pro</.field_title>
          </.field>
        </.field_label>
        """)

      assert html =~ "has-[&gt;[data-slot=field]]:w-full has-[&gt;[data-slot=field]]:flex-col"
      assert html =~ "has-[&gt;[data-slot=field]]:rounded-md"
      assert html =~ "*:data-[slot=field]:p-4"
      assert html =~ "has-[:checked]:bg-brand-emerald-muted has-[:checked]:border-brand-border"
    end
  end

  describe "field_title" do
    test "renders label-styled text sharing the field-label slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_title>Enable Touch ID</.field_title>
        """)

      assert html =~ "data-polaris-field-title"
      assert html =~ ~s{data-slot="field-label"}
      assert html =~ "flex w-fit items-center gap-2 text-sm font-medium leading-snug"
      assert html =~ "Enable Touch ID"
    end
  end

  describe "field_description" do
    test "renders the muted hint with link styling" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_description>This appears on invoices and emails.</.field_description>
        """)

      assert html =~ "data-polaris-field-description"
      assert html =~ "<p"
      assert html =~ "text-content-secondary text-sm font-normal leading-normal"

      assert html =~
               "[&amp;&gt;a:hover]:text-brand-emerald [&amp;&gt;a]:underline [&amp;&gt;a]:underline-offset-4"

      assert html =~ "This appears on invoices and emails."
    end
  end

  describe "field_separator" do
    test "renders the bare hairline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_separator />
        """)

      assert html =~ "data-polaris-field-separator"
      assert html =~ "relative -my-2 h-5 text-sm"
      assert html =~ ~s{data-content="false"}
      assert html =~ "h-px w-full bg-surface-border"
      refute html =~ "data-polaris-field-separator-content"
    end

    test "carries the centered content chip when given one" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_separator>Or continue with</.field_separator>
        """)

      assert html =~ ~s{data-content="true"}
      assert html =~ "data-polaris-field-separator-content"
      assert html =~ "relative mx-auto block w-fit bg-surface-ground px-2 text-content-secondary"
      assert html =~ "Or continue with"
    end
  end

  describe "field_error" do
    test "renders nothing without content or errors" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <div><.field_error /></div>
        """)

      refute html =~ "data-polaris-field-error"
    end

    test "renders the inner block as a role=alert danger message" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_error>Choose another username.</.field_error>
        """)

      assert html =~ "data-polaris-field-error"
      assert html =~ ~s{role="alert"}
      assert html =~ "text-danger text-sm font-normal"
      assert html =~ "Choose another username."
    end

    test "a single error message renders as text" do
      assigns = %{errors: [%{message: "Enter a valid email address."}]}

      html =
        rendered_to_string(~H"""
        <.field_error errors={@errors} />
        """)

      assert html =~ "Enter a valid email address."
      refute html =~ "<ul"
    end

    test "multiple errors render as a disc list" do
      assigns = %{
        errors: [%{message: "Too short."}, %{message: "Already taken."}]
      }

      html =
        rendered_to_string(~H"""
        <.field_error errors={@errors} />
        """)

      assert html =~ "ml-4 flex list-disc flex-col gap-1"
      assert html =~ "Too short."
      assert html =~ "Already taken."
    end

    test "accepts binaries in the errors list" do
      assigns = %{errors: ["Bare message."]}

      html =
        rendered_to_string(~H"""
        <.field_error errors={@errors} />
        """)

      assert html =~ "Bare message."
    end

    test "the inner block wins over errors" do
      assigns = %{errors: [%{message: "From the list."}]}

      html =
        rendered_to_string(~H"""
        <.field_error errors={@errors}>From the block.</.field_error>
        """)

      assert html =~ "From the block."
      refute html =~ "From the list."
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.field_set>
          <.field_group>
            <.field>
              <.field_label for="x">x</.field_label>
              <.field_description>x</.field_description>
              <.field_error>x</.field_error>
            </.field>
            <.field_separator>x</.field_separator>
          </.field_group>
        </.field_set>
        """)

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
