import Config

# Configure Ash domains for test environment
config :ash_backpex, ash_domains: [AshBackpex.TestDomain]

# Configure the test repo
config :ash_backpex, ecto_repos: [AshBackpex.TestRepo]

config :ash_backpex, AshBackpex.TestRepo,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1,
  log: false
