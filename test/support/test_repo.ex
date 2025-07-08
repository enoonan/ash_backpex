defmodule TestRepo do
  use AshSqlite.Repo,
    otp_app: :ash_backpex
end
