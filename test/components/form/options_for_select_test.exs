defmodule Surface.Components.Form.OptionsForSelectTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.OptionsForSelect, warn: false

  import ComponentTestHelper

  test "empty options" do
    code =
      quote do
        ~H"""
        <OptionsForSelect />
        """
      end

    assert render_live(code) == "\n"
  end

  test "setting the options" do
    code =
      quote do
        ~H"""
        <OptionsForSelect options={{ ["Admin": "admin", "User": "user"] }} />
        """
      end

    assert render_live(code) =~ """
           <option value="admin">Admin</option>\
           <option value="user">User</option>
           """
  end

  test "passing selected value" do
    code =
      quote do
        ~H"""
        <OptionsForSelect options={{ ["Admin": "admin", "User": "user"] }} selected={{ "admin" }} />
        """
      end

    assert render_live(code) =~ """
           <option value="admin" selected="selected">Admin</option>\
           <option value="user">User</option>
           """
  end

  test "passing multiple selected values" do
    code =
      quote do
        ~H"""
        <OptionsForSelect options={{ ["Admin": "admin", "User": "user"] }} selected={{ ["admin", "user"] }} />
        """
      end

    assert render_live(code) =~ """
           <option value="admin" selected="selected">Admin</option>\
           <option value="user" selected="selected">User</option>
           """
  end
end
