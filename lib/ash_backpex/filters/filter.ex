defmodule AshBackpex.Filters.Filter do
  @moduledoc """
  Defines the behavior for AshBackpex filter modules.

  Filter modules implement the logic to convert user-provided filter values
  into Ash.Expr expressions for safe, validated query filtering.

  ## Creating a Filter Module

  Filter modules should:
  1. `use` a Backpex filter module for UI rendering (e.g., `Backpex.Filters.Boolean`)
  2. Implement the `AshBackpex.Filters.Filter` behavior for query generation

  ## Example

      defmodule MyApp.Filters.CustomStatus do
        use Backpex.Filters.Select
        @behaviour AshBackpex.Filters.Filter

        @impl AshBackpex.Filters.Filter
        def to_ash_expr(field, value, _assigns) do
          require Ash.Expr
          Ash.Expr.expr(^Ash.Expr.ref(field) == ^value)
        end
      end

  ## Built-in Filters

  AshBackpex provides these filter modules that implement this behavior:

  - `AshBackpex.Filters.Boolean` - True/false checkbox filter
  - `AshBackpex.Filters.Select` - Single-value dropdown/select filter
  - `AshBackpex.Filters.MultiSelect` - Multi-value checkbox filter
  - `AshBackpex.Filters.Range` - Min/max range filter for numbers, dates, datetimes

  ## Automatic Derivation

  When using `AshBackpex.LiveResource`, filter modules are automatically derived
  from Ash attribute types if not explicitly specified. See the type derivation
  rules in `AshBackpex.LiveResource.Dsl`.
  """

  @doc """
  Converts a filter value to an Ash.Expr expression.

  This callback is invoked by the adapter when applying filters to a query.
  It should return an `Ash.Expr.t()` expression that can be passed to
  `Ash.Query.filter/2`, or `nil` if no filter should be applied.

  ## Parameters

  - `field` - The atom name of the attribute being filtered
  - `value` - The filter value from the UI (format varies by filter type)
  - `assigns` - The LiveView assigns map, useful for context-dependent filtering

  ## Return Values

  - `Ash.Expr.t()` - An expression to apply to the query
  - `nil` - No filter should be applied (e.g., empty/invalid value)

  ## Value Formats by Filter Type

  | Filter Type | Value Format | Example |
  |-------------|--------------|---------|
  | Boolean | `list(String.t())` | `["true"]`, `["false"]`, `["true", "false"]` |
  | Select | `String.t()` | `"draft"`, `"published"` |
  | MultiSelect | `list(String.t())` | `["tag1", "tag2"]` |
  | Range | `map()` | `%{"start" => "10", "end" => "20"}` |

  ## Example Implementation

      @impl AshBackpex.Filters.Filter
      def to_ash_expr(field, value, _assigns) when is_binary(value) do
        require Ash.Expr
        Ash.Expr.expr(^Ash.Expr.ref(field) == ^String.to_existing_atom(value))
      end

      def to_ash_expr(_field, _value, _assigns), do: nil
  """
  @callback to_ash_expr(field :: atom(), value :: any(), assigns :: map()) ::
              Ash.Expr.t() | nil

  @doc """
  Validates and optionally transforms a filter value before it's used.

  This is an optional callback. If implemented, it's called before `to_ash_expr/3`
  to validate the incoming value. This is useful for parsing strings into typed
  values or rejecting invalid input.

  ## Parameters

  - `value` - The raw filter value from the UI
  - `opts` - Options from the filter configuration (e.g., `type: :number`)

  ## Return Values

  - `{:ok, transformed_value}` - Value is valid, optionally transformed
  - `{:error, message}` - Value is invalid, with a human-readable error message

  ## Example Implementation

      @impl AshBackpex.Filters.Filter
      def validate_value(%{"start" => start, "end" => end_val}, type: :number) do
        with {:ok, start_num} <- parse_number(start),
             {:ok, end_num} <- parse_number(end_val) do
          {:ok, %{"start" => start_num, "end" => end_num}}
        end
      end
  """
  @callback validate_value(value :: any(), opts :: keyword()) ::
              {:ok, any()} | {:error, String.t()}

  @optional_callbacks [validate_value: 2]
end
