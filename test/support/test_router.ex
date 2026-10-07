defmodule AshBackpex.TestRouter do
  @moduledoc false

  use Phoenix.Router

  import Backpex.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:fetch_session)
  end

  scope "/" do
    pipe_through(:browser)

    backpex_routes()

    live_session :backpex_admin,
      on_mount: [AshBackpex.TestRouter.CurrentUser, Backpex.InitAssigns] do
      live_resources("/assignments", TestAssignmentIndexEditLive)
    end
  end
end

defmodule AshBackpex.TestRouter.CurrentUser do
  @moduledoc false

  # Assigns the user whose id the test put into the session, as an
  # authentication hook would, so `can?/3` sees an Ash actor.
  def on_mount(:default, _params, session, socket) do
    current_user =
      case session do
        %{"current_user_id" => id} -> Ash.get!(AshBackpex.TestDomain.User, id)
        _session -> nil
      end

    {:cont, Phoenix.Component.assign(socket, :current_user, current_user)}
  end
end
