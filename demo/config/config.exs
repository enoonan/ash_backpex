# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

import Config

config :demo,
  ecto_repos: [Demo.Repo],
  generators: [timestamp_type: :utc_datetime]

config :esbuild,
  version: "0.17.11",
  demo: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  demo: [
    args: ~w(
        --input=assets/css/app.css
        --output=priv/static/assets/css/app.css
      ),
    cd: Path.expand("..", __DIR__)
  ]

config :backpex,
  translator_function: {DemoWeb.CoreComponents, :translate_backpex},
  error_translator_function: {DemoWeb.CoreComponents, :translate_error}

config :backpex, :pubsub_server, Demo.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :demo,
  ecto_repos: [Demo.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [Demo.Blog]

# Configure your database
config :demo, Demo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "demo_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :demo, DemoWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DemoWeb.ErrorHTML, json: DemoWeb.ErrorJSON],
    layout: false
  ],
  live_view: [signing_salt: "n3YLtKq8"],
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  pubsub_server: Demo.PubSub,
  secret_key_base: "NT2lp5iAtjjNDlSMJs1W7zgqtspJF/TnpBW6PQ4WrHGyPZMXFvK3erBM9Lm0bVBz",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:demo, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:demo, ~w(--watch)]}
  ],
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/demo_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
