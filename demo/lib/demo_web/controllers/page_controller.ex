defmodule DemoWeb.PageController do
  use Phoenix.Controller

  def redirect_to_posts(conn, _params) do
    redirect(conn, to: "/posts")
  end
end