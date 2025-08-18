import Config

# Import environment specific config
if config_env() in [:test] do
  import_config "#{config_env()}.exs"
end
