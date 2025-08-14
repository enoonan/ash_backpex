defmodule DemoWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use DemoWeb, :verified_routes

  def on_mount(:live_user_demo, _params, _session, socket) do
    {:cont,
     socket
     |> assign_new(:current_user, fn -> %{name: "John Doe"} end)}
  end
end
