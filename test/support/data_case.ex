defmodule AshBackpex.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      alias AshBackpex.TestRepo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import AshBackpex.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(AshBackpex.TestRepo, shared: not tags[:async])

    # Create tables directly for in-memory database
    create_test_tables()

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  defp create_test_tables do
    Ecto.Adapters.SQL.query!(AshBackpex.TestRepo, """
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      active BOOLEAN NOT NULL DEFAULT 1,
      inserted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    """)

    Ecto.Adapters.SQL.query!(AshBackpex.TestRepo, """
    CREATE TABLE IF NOT EXISTS posts (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT,
      published BOOLEAN NOT NULL DEFAULT 0,
      published_at DATETIME,
      view_count INTEGER NOT NULL DEFAULT 0,
      rating REAL,
      tags TEXT,
      metadata TEXT,
      status TEXT,
      author_id TEXT REFERENCES users(id),
      inserted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    """)

    Ecto.Adapters.SQL.query!(AshBackpex.TestRepo, """
    CREATE TABLE IF NOT EXISTS comments (
      id TEXT PRIMARY KEY,
      body TEXT NOT NULL,
      post_id TEXT REFERENCES posts(id),
      author_id TEXT REFERENCES users(id),
      inserted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    """)
  end
end
