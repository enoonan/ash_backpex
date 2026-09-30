defmodule DemoWeb.DashboardLive do
  @moduledoc """
  An admin page that is not a LiveResource.

  It renders the same admin layout as the resources, so it has to pass the
  assigns that `Backpex.InitAssigns` provides (`socket`, `current_theme`,
  `sidebar_open`, `sidebar_section_states`, `preferences_manifest`) itself.
  """

  use DemoWeb, :live_view

  alias Demo.Blog

  @counts [
    {"Authors", Blog.Author, "/authors"},
    {"Posts", Blog.Post, "/posts"},
    {"Tags", Blog.Tag, "/tags"},
    {"Comments", Blog.Comment, "/comments"}
  ]

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    counts =
      for {label, resource, path} <- @counts do
        {label, Ash.count!(resource, actor: socket.assigns.current_user), path}
      end

    {:ok, assign(socket, page_title: "Dashboard", counts: counts)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.admin
      socket={@socket}
      flash={@flash}
      current_url={@current_url}
      current_theme={@current_theme}
      sidebar_open={@sidebar_open}
      sidebar_section_states={@sidebar_section_states}
      preferences_manifest={@preferences_manifest}
    >
      <Backpex.HTML.Layout.main_title>Dashboard</Backpex.HTML.Layout.main_title>
      <div class="stats stats-vertical sm:stats-horizontal bg-base-100 shadow">
        <.link :for={{label, count, path} <- @counts} navigate={path} class="stat">
          <div class="stat-title">{label}</div>
          <div class="stat-value">{count}</div>
        </.link>
      </div>
    </Layouts.admin>
    """
  end
end
