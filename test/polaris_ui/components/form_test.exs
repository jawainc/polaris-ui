defmodule PolarisUI.Components.FormTest do
  @moduledoc """
  Isolated render tests for `PolarisUI.Components.Form` — the port of
  the Supabase design system Form (react-hook-form): the
  changeset-driven form family with the id/aria contract
  (`<id>-form-item[-description|-message]`) shared by label, control,
  description, and message.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2, assign: 2]
  import Phoenix.LiveViewTest
  import PolarisUI.Components.Form

  # A %Phoenix.HTML.FormField{} stand-in with the same shape — the
  # components read id/name/value/errors.
  defp field(id, name, value \\ "", errors \\ []) do
    %{id: id, name: name, value: value, errors: errors}
  end

  describe "form" do
    test "renders a real form and let-binds the Phoenix form data" do
      assigns = %{
        form_data: Phoenix.HTML.FormData.to_form(%{"username" => "supabase"}, as: "user")
      }

      html =
        rendered_to_string(~H"""
        <.form :let={f} for={@form_data}>
          <input name={f[:username].name} value={f[:username].value} />
        </.form>
        """)

      assert html =~ "<form"
      assert html =~ ~s{name="user[username]"}
      assert html =~ ~s{value="supabase"}
    end

    test "forwards phx-change and phx-submit to the form element" do
      assigns = %{form_data: Phoenix.HTML.FormData.to_form(%{}, as: "user")}

      html =
        rendered_to_string(~H"""
        <.form for={@form_data} phx-change="validate" phx-submit="save"></.form>
        """)

      assert html =~ ~s{phx-change="validate"}
      assert html =~ ~s{phx-submit="save"}
    end
  end

  describe "form_item" do
    test "renders the structural group for one field" do
      assigns = %{field: field("user_username", "user[username]")}

      html =
        rendered_to_string(~H"""
        <.form_item field={@field}>content</.form_item>
        """)

      assert html =~ "data-polaris-form-item"
      assert html =~ "content"
    end
  end

  describe "form_label" do
    test "wires for to the control id" do
      assigns = %{field: field("user_username", "user[username]")}

      html =
        rendered_to_string(~H"""
        <.form_label field={@field}>Username</.form_label>
        """)

      assert html =~ "data-polaris-form-label"
      assert html =~ ~s{for="user_username-form-item"}
      assert html =~ "text-sm text-content-secondary leading-normal transition-colors"
      assert html =~ "Username"
    end

    test "the label forces danger while errored, over caller classes" do
      assigns = %{field: field("user_username", "user[username]", "", [{"is invalid", []}])}

      html =
        rendered_to_string(~H"""
        <.form_label field={@field} class="text-content-primary">Username</.form_label>
        """)

      # The danger class replaces every earlier text color in the merge —
      # the source's `!text-destructive` important semantics.
      assert html =~ "text-danger"
      refute html =~ "text-content-primary"
      refute html =~ "text-content-secondary"
    end
  end

  describe "form_control" do
    test "renders the input wired with name, value, and the id contract" do
      assigns = %{field: field("user_username", "user[username]", "supabase")}

      html =
        rendered_to_string(~H"""
        <.form_control field={@field} placeholder="supabase" />
        """)

      assert html =~ "data-polaris-form-control"
      assert html =~ ~s{id="user_username-form-item"}
      assert html =~ ~s{name="user[username]"}
      assert html =~ ~s{value="supabase"}
      assert html =~ ~s{type="text"}
      assert html =~ ~s{placeholder="supabase"}
    end

    test "valid fields describe by the description id only" do
      assigns = %{field: field("user_username", "user[username]")}

      html =
        rendered_to_string(~H"""
        <.form_control field={@field} />
        """)

      assert html =~ ~s{aria-describedby="user_username-form-item-description"}
      refute html =~ "aria-invalid"
    end

    test "errored fields add the message id and aria-invalid" do
      assigns = %{field: field("user_username", "user[username]", "", [{"is invalid", []}])}

      html =
        rendered_to_string(~H"""
        <.form_control field={@field} />
        """)

      assert html =~
               ~s{aria-describedby="user_username-form-item-description user_username-form-item-message"}

      assert html =~ ~s{aria-invalid="true"}
    end

    test "type=textarea renders the multi-line variant with its value" do
      assigns = %{field: field("user_bio", "user[bio]", "Hello")}

      html =
        rendered_to_string(~H"""
        <.form_control field={@field} type="textarea" />
        """)

      assert html =~ "<textarea"
      assert html =~ ~s{id="user_bio-form-item"}
      assert html =~ "Hello"
      assert html =~ "min-h-[80px]"
      refute html =~ ~s{type="textarea"}
    end

    test "the input carries the bordered surface and emerald focus ring" do
      assigns = %{field: field("user_username", "user[username]")}

      html =
        rendered_to_string(~H"""
        <.form_control field={@field} />
        """)

      assert html =~ "flex h-10 w-full rounded-md border border-surface-border"
      assert html =~ "focus:ring-2 focus:ring-brand-emerald"

      assert html =~
               "aria-[invalid=true]:border-danger-border aria-[invalid=true]:bg-danger-muted"
    end

    test "caller classes merge onto the control" do
      assigns = %{field: field("user_username", "user[username]")}

      html =
        rendered_to_string(~H"""
        <.form_control field={@field} class="max-w-sm" />
        """)

      assert html =~ "max-w-sm"
    end
  end

  describe "form_description" do
    test "carries the description id" do
      assigns = %{field: field("user_username", "user[username]")}

      html =
        rendered_to_string(~H"""
        <.form_description field={@field}>This is your public display name.</.form_description>
        """)

      assert html =~ "data-polaris-form-description"
      assert html =~ ~s{id="user_username-form-item-description"}
      assert html =~ "text-sm text-content-secondary"
      assert html =~ "This is your public display name."
    end
  end

  describe "form_message" do
    test "renders nothing without errors or fallback content" do
      assigns = %{field: field("user_username", "user[username]")}

      html =
        rendered_to_string(~H"""
        <div><.form_message field={@field} /></div>
        """)

      refute html =~ "data-polaris-form-message"
    end

    test "renders the first error message with the message id" do
      assigns = %{
        field:
          field("user_username", "user[username]", "", [
            {"must be at least %{count} characters", count: 2}
          ])
      }

      html =
        rendered_to_string(~H"""
        <.form_message field={@field} />
        """)

      assert html =~ "data-polaris-form-message"
      assert html =~ ~s{id="user_username-form-item-message"}
      assert html =~ "text-sm text-danger"
      assert html =~ "must be at least 2 characters"
    end

    test "binary errors render directly" do
      assigns = %{field: field("user_username", "user[username]", "", ["Already taken"])}

      html =
        rendered_to_string(~H"""
        <.form_message field={@field} />
        """)

      assert html =~ "Already taken"
    end

    test "the inner block is the fallback when no errors exist" do
      assigns = %{field: field("user_username", "user[username]")}

      html =
        rendered_to_string(~H"""
        <.form_message field={@field}>Fallback message.</.form_message>
        """)

      assert html =~ "Fallback message."
    end

    test "errors win over the fallback" do
      assigns = %{field: field("user_username", "user[username]", "", ["From errors"])}

      html =
        rendered_to_string(~H"""
        <.form_message field={@field}>From the block.</.form_message>
        """)

      assert html =~ "From errors"
      refute html =~ "From the block."
    end
  end

  describe "composition" do
    test "the whole family wired together around a Phoenix form" do
      assigns = %{
        form_data: Phoenix.HTML.FormData.to_form(%{"username" => ""}, as: "user")
      }

      html =
        rendered_to_string(~H"""
        <.form :let={f} for={@form_data} phx-change="validate" phx-submit="save">
          <.form_item field={f[:username]}>
            <.form_label field={f[:username]}>Username</.form_label>
            <.form_control field={f[:username]} placeholder="supabase" />
            <.form_description field={f[:username]}>
              This is your public display name.
            </.form_description>
            <.form_message field={f[:username]} />
          </.form_item>
        </.form>
        """)

      assert html =~ ~s{for="user_username-form-item"}
      assert html =~ ~s{id="user_username-form-item"}
      assert html =~ ~s{aria-describedby="user_username-form-item-description"}
      assert html =~ ~s{name="user[username]"}
      refute html =~ "data-polaris-form-message"
    end
  end

  describe "design rules" do
    test "uses only token utilities — no raw hex arbitrary values" do
      assigns = %{field: field("user_username", "user[username]")}

      html =
        rendered_to_string(~H"""
        <.form_item field={@field}>
          <.form_label field={@field}>x</.form_label>
          <.form_control field={@field} />
          <.form_description field={@field}>x</.form_description>
          <.form_message field={@field}>x</.form_message>
        </.form_item>
        """)

      refute html =~ "#[", "arbitrary-value class leaked"
    end
  end
end
