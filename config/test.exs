import Config

# Configure Ash domains for test environment
config :ash_backpex, ash_domains: [TestDomain]

# Configure the test repo
config :ash_backpex, ecto_repos: [TestRepo]

config :ash_backpex, TestRepo,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox