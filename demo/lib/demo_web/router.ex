defmodule DemoWeb.Router do
  use DemoWeb, :router
  import Backpex.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {DemoWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  def assign_user(conn, _opts) do
    assign(conn, :current_user, %{"name" => "John Doe"})
  end

  scope "/", DemoWeb do
    pipe_through([:browser, Backpex.ThemeSelectorPlug, :assign_user])

    get("/", PageController, :redirect_to_posts)

    backpex_routes()

    live_session :backpex_admin,
      on_mount: [{DemoWeb.LiveUserAuth, :live_user_demo}, Backpex.InitAssigns] do
      live_resources("/posts", PostLive)
    end
  end
end
