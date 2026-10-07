defmodule AshBackpex.TestEndpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :ash_backpex

  socket("/live", Phoenix.LiveView.Socket)

  plug(
    Plug.Session,
    store: :cookie,
    key: "_ash_backpex_test_key",
    signing_salt: "ash-backpex-test"
  )

  plug(AshBackpex.TestRouter)
end
