defmodule AshBackpex.Config do
  @moduledoc """
  Configuration helpers for AshBackpex.

  This module provides functions to read AshBackpex configuration from the application
  environment. Configuration can be set at two levels with the following precedence:

  1. **App-scoped config** (highest priority):
     ```elixir
     config :my_app, AshBackpex,
       field_type_mappings: %{...}
     ```

  2. **Global config** (fallback):
     ```elixir
     config :ash_backpex,
       field_type_mappings: %{...}
     ```

  ## Example

  In your `config/config.exs`:

      # Global config (applies to all apps using AshBackpex)
      config :ash_backpex,
        field_type_mappings: %{
          MyApp.Types.Money => Backpex.Fields.Currency
        }

      # App-specific config (overrides global for this app)
      config :my_app, AshBackpex,
        field_type_mappings: %{
          MyApp.Types.Money => MyApp.Fields.MoneyField
        }

  """

  @doc """
  Reads the field type mappings configuration.

  Checks app-scoped config first (e.g., `config :my_app, AshBackpex, field_type_mappings: ...`),
  then falls back to global config (`config :ash_backpex, field_type_mappings: ...`).

  Returns `nil` if no configuration is found.

  ## Parameters

  - `otp_app` - The OTP application name to check for app-scoped config.
    If `nil`, only checks global config.

  ## Examples

      # With app-scoped config
      iex> AshBackpex.Config.field_type_mappings(:my_app)
      %{MyApp.Types.Money => Backpex.Fields.Currency}

      # No config set
      iex> AshBackpex.Config.field_type_mappings(:my_app)
      nil

  """
  @spec field_type_mappings(atom() | nil) :: map() | function() | nil
  def field_type_mappings(otp_app \\ nil) do
    # Try app-scoped config first
    app_scoped =
      if otp_app do
        otp_app
        |> Application.get_env(AshBackpex, [])
        |> Keyword.get(:field_type_mappings)
      end

    result = app_scoped || Application.get_env(:ash_backpex, :field_type_mappings)

    # Validate and return
    case result do
      nil -> nil
      value -> validate_field_type_mappings!(value)
    end
  end

  @doc """
  Validates that a field_type_mappings config value has the correct format.

  Valid formats:
  - A map where keys are Ash type modules (atoms) or tuple types like `{:array, Ash.Type.String}`
  - A function with arity 2 that takes `(type, constraints)` and returns a Backpex field module or nil

  Raises a clear error message if the config format is invalid.

  ## Examples

      # Valid map
      iex> AshBackpex.Config.validate_field_type_mappings!(%{Ash.Type.String => Backpex.Fields.Textarea})
      %{Ash.Type.String => Backpex.Fields.Textarea}

      # Valid function
      iex> fun = fn _type, _constraints -> nil end
      iex> AshBackpex.Config.validate_field_type_mappings!(fun)
      fun

      # Invalid: not a map or function
      iex> AshBackpex.Config.validate_field_type_mappings!("invalid")
      ** (ArgumentError) Invalid field_type_mappings configuration...

  """
  @spec validate_field_type_mappings!(term()) :: map() | function()
  def validate_field_type_mappings!(value) when is_map(value) do
    validate_map_keys!(value)
    value
  end

  def validate_field_type_mappings!(value) when is_function(value, 2) do
    value
  end

  def validate_field_type_mappings!(value) when is_function(value) do
    raise ArgumentError, """
    Invalid field_type_mappings configuration.

    Expected a function with arity 2 (type, constraints), but got a function with arity #{:erlang.fun_info(value)[:arity]}.

    The function should have the signature:

        fn type, constraints -> Backpex.Fields.SomeField | nil end

    Example:

        config :ash_backpex,
          field_type_mappings: fn
            MyApp.Types.Money, _constraints -> MyApp.Fields.MoneyField
            _type, _constraints -> nil
          end
    """
  end

  def validate_field_type_mappings!(value) do
    raise ArgumentError, """
    Invalid field_type_mappings configuration.

    Expected a map or a function with arity 2, but got: #{inspect(value)}

    Valid configurations:

    1. A map of Ash types to Backpex field modules:

        config :ash_backpex,
          field_type_mappings: %{
            MyApp.Types.Money => Backpex.Fields.Currency,
            Ash.Type.String => Backpex.Fields.Textarea
          }

    2. A function that takes (type, constraints) and returns a Backpex field module or nil:

        config :ash_backpex,
          field_type_mappings: fn
            MyApp.Types.Money, _constraints -> MyApp.Fields.MoneyField
            {:array, Ash.Type.String}, _constraints -> Backpex.Fields.MultiSelect
            _type, _constraints -> nil
          end
    """
  end

  # Validates that all keys in the map are valid Ash type atoms or tuple types
  defp validate_map_keys!(map) do
    Enum.each(map, fn {key, _value} ->
      validate_type_key!(key)
    end)
  end

  defp validate_type_key!(key) when is_atom(key), do: :ok

  defp validate_type_key!({:array, inner}) when is_atom(inner), do: :ok

  defp validate_type_key!({:array, {:array, _} = nested}), do: validate_type_key!(nested)

  defp validate_type_key!(key) do
    raise ArgumentError, """
    Invalid key in field_type_mappings configuration.

    Expected an Ash type module (atom) or a tuple type like {:array, Ash.Type.String}, but got: #{inspect(key)}

    Valid key examples:
    - Ash.Type.String
    - MyApp.Types.Money
    - {:array, Ash.Type.String}
    - {:array, Ash.Type.Integer}

    Check your config:

        config :ash_backpex,
          field_type_mappings: %{
            Ash.Type.String => Backpex.Fields.Textarea,  # atom key - valid
            {:array, Ash.Type.String} => Backpex.Fields.MultiSelect  # tuple key - valid
          }
    """
  end
end
