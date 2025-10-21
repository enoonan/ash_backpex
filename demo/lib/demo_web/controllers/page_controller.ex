defmodule DemoWeb.PageController do
  use Phoenix.Controller, formats: [html: "View"]

  def redirect_to_posts(conn, _params) do
    redirect(conn, to: "/posts")
  end
end
