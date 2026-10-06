import Config

# Configure Ash domains for test environment
config :ash_backpex, ash_domains: [AshBackpex.TestDomain]

config :backpex,
  translator_function: {AshBackpex.TestTranslator, :translate},
  error_translator_function: {AshBackpex.TestTranslator, :translate}

# Configure the test repo
config :ash_backpex, ecto_repos: [AshBackpex.TestRepo]

config :ash_backpex, AshBackpex.TestRepo,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1,
  log: false

config :ash_backpex, AshBackpex.TestEndpoint,
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  secret_key_base: String.duplicate("ash-backpex-test-secret-", 4),
  live_view: [signing_salt: "ash-backpex-live"],
  server: false,
  url: [host: "localhost"]
