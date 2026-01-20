defmodule AshBackpex.Filters.Range do
  @moduledoc """
  A Range filter for AshBackpex that renders min/max input fields for numeric filtering.

  This module provides both the UI rendering (via `Backpex.Filters.Range`) and
  the Ash.Expr generation (via `AshBackpex.Filters.Filter` behavior) for filtering
  numeric attributes with greater-than-or-equal and less-than-or-equal comparisons.

  ## Usage

  The Range filter is automatically derived for `:integer`, `:float`, and `:decimal`
  type attributes when using `AshBackpex.LiveResource`. You can also use it directly:

      defmodule MyApp.Filters.PriceRange do
        use AshBackpex.Filters.Range

        @impl Backpex.Filter
        def label, do: "Price"

        @impl Backpex.Filters.Range
        def type, do: :number
      end

  ## Filter Values

  The filter receives values as a map with "start" and "end" keys:
  - `%{"start" => "10", "end" => "100"}` - Filter for field >= 10 AND field <= 100
  - `%{"start" => "10", "end" => ""}` - Filter for field >= 10
  - `%{"start" => "", "end" => "100"}` - Filter for field <= 100
  - `%{"start" => "", "end" => ""}` - No filter applied
  - `nil` or `%{}` - No filter applied

  ## Types

  The Range filter supports three types via the `type/0` callback:
  - `:number` - For integer and float attributes (default)
  - `:date` - For date attributes
  - `:datetime` - For datetime attributes

  Note: Date and datetime filtering uses the same Ash expressions but with
  date/datetime values instead of numbers.

  ## Options

  You must implement the `type/0` callback to specify the input type:

      @impl Backpex.Filters.Range
      def type, do: :number

  Note: Unlike Backpex's Ecto-based filtering which uses the `query/3` callback,
  AshBackpex uses `to_ash_expr/3` to generate Ash expressions for filtering.
  """

  @behaviour AshBackpex.Filters.Filter

  defmacro __using__(_opts) do
    quote do
      use Backpex.Filters.Range

      @behaviour AshBackpex.Filters.Filter

      @impl AshBackpex.Filters.Filter
      defdelegate to_ash_expr(field, value, assigns), to: AshBackpex.Filters.Range

      defoverridable to_ash_expr: 3
    end
  end

  @doc """
  Converts a range filter value to an Ash.Expr expression.

  ## Parameters

  - `field` - The atom name of the attribute being filtered
  - `value` - The filter value (map with "start" and "end" keys)
  - `assigns` - The LiveView assigns (unused by this filter)

  ## Returns

  - `Ash.Expr.t()` - When at least one of start or end is a valid value
  - `nil` - When no filter should be applied (both empty, nil, or invalid)

  ## Examples

      iex> Range.to_ash_expr(:price, %{"start" => "10", "end" => "100"}, %{})
      #Ash.Expr<price >= 10 and price <= 100>

      iex> Range.to_ash_expr(:price, %{"start" => "10", "end" => ""}, %{})
      #Ash.Expr<price >= 10>

      iex> Range.to_ash_expr(:price, %{"start" => "", "end" => "100"}, %{})
      #Ash.Expr<price <= 100>

      iex> Range.to_ash_expr(:price, %{"start" => "", "end" => ""}, %{})
      nil

      iex> Range.to_ash_expr(:price, nil, %{})
      nil
  """
  @impl AshBackpex.Filters.Filter
  def to_ash_expr(_field, nil, _assigns), do: nil
  def to_ash_expr(_field, value, _assigns) when value == %{}, do: nil

  def to_ash_expr(field, %{"start" => start_val, "end" => end_val}, _assigns) do
    start_parsed = parse_value(start_val)
    end_parsed = parse_value(end_val)

    build_expr(field, start_parsed, end_parsed)
  end

  def to_ash_expr(_field, _value, _assigns), do: nil

  # Already a number - pass through
  defp parse_value(value) when is_number(value), do: value

  # Empty string - no value
  defp parse_value(""), do: nil
  defp parse_value(nil), do: nil

  # String value - try to parse as number
  defp parse_value(value) when is_binary(value) do
    case {Integer.parse(value), Float.parse(value)} do
      {{int_val, ""}, _} -> int_val
      {_, {float_val, ""}} -> float_val
      _ -> nil
    end
  end

  defp parse_value(_), do: nil

  # No valid values - no filter
  defp build_expr(_field, nil, nil), do: nil

  # Only start value - greater than or equal
  defp build_expr(field, start_val, nil) when not is_nil(start_val) do
    require Ash.Expr
    Ash.Expr.expr(^Ash.Expr.ref(field) >= ^start_val)
  end

  # Only end value - less than or equal
  defp build_expr(field, nil, end_val) when not is_nil(end_val) do
    require Ash.Expr
    Ash.Expr.expr(^Ash.Expr.ref(field) <= ^end_val)
  end

  # Both values - combined range
  defp build_expr(field, start_val, end_val) do
    require Ash.Expr
    Ash.Expr.expr(^Ash.Expr.ref(field) >= ^start_val and ^Ash.Expr.ref(field) <= ^end_val)
  end
end
