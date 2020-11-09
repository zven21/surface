defmodule Surface.Components.LinkTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Link, warn: false

  import ComponentTestHelper

  defmodule ComponentWithLink do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        <Link to="/users/1" click="my_click"/>
      </div>
      """
    end

    def handle_event(_, _, socket) do
      {:noreply, socket}
    end
  end

  describe "Without LiveView" do
    test "creates a link with label" do
      code =
        quote do
          ~H"""
          <Link label="user" to="/users/1" />
          """
        end

      assert render_live(code) =~ """
             <a href="/users/1">user</a>
             """
    end

    test "creates a link without label" do
      code =
        quote do
          ~H"""
          <Link to="/users/1" />
          """
        end

      assert render_live(code) =~ """
             <a href="/users/1"></a>
             """
    end

    test "creates a link with default slot" do
      code =
        quote do
          ~H"""
          <Link to="/users/1"><span>user</span></Link>
          """
        end

      assert render_live(code) =~ """
             <a href="/users/1"><span>user</span></a>
             """
    end

    test "setting the class" do
      code =
        quote do
          ~H"""
          <Link label="user" to="/users/1" class="link" />
          """
        end

      assert render_live(code) =~ """
             <a class="link" href="/users/1">user</a>
             """
    end

    test "setting multiple classes" do
      code =
        quote do
          ~H"""
          <Link label="user" to="/users/1" class="link primary" />
          """
        end

      assert render_live(code) =~ """
             <a class="link primary" href="/users/1">user</a>
             """
    end

    test "passing other options" do
      code =
        quote do
          ~H"""
          <Link label="user" to="/users/1" class="link" opts={{ method: :delete, data: [confirm: "Really?"], csrf_token: "token" }} />
          """
        end

      assert render_live(code) =~ """
             <a class="link" data-confirm="Really?" data-csrf="token" data-method="delete" data-to="/users/1" href="/users/1" rel="nofollow">user</a>
             """
    end

    test "click event with parent live view as target" do
      code =
        quote do
          ~H"""
          <Link to="/users/1" click="my_click" />
          """
        end

      assert render_live(code) =~ """
             <a href="/users/1" phx-click="my_click"></a>
             """
    end

    test "click event with @myself as target" do
      code =
        quote do
          ~H"""
          <ComponentWithLink id="comp"/>
          """
        end

      assert render_live(code) =~ """
             <div data-phx-component="1"><a href="/users/1" phx-click="my_click" phx-target="1"></a></div>
             """
    end
  end
end
