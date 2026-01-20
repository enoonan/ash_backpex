defmodule AshBackpex.Filters.MultiSelect do
  @moduledoc """
  A MultiSelect filter for AshBackpex that renders checkboxes for multi-value filtering.

  This module provides both the UI rendering (via `Backpex.Filters.MultiSelect`) and
  the Ash.Expr generation (via `AshBackpex.Filters.Filter` behavior) for filtering
  attributes where the field value should match any of the selected values.

  ## Usage

  The MultiSelect filter is automatically derived for array-type attributes with `one_of`
  constraints when using `AshBackpex.LiveResource`. You can also use it directly:

      defmodule MyApp.Filters.Tags do
        use AshBackpex.Filters.MultiSelect

        @impl Backpex.Filter
        def label, do: "Tags"

        @impl Backpex.Filters.MultiSelect
        def prompt, do: "Select tags..."

        @impl Backpex.Filters.MultiSelect
        def options(_assigns) do
          [
            {"Bug", "bug"},
            {"Feature", "feature"},
            {"Enhancement", "enhancement"}
          ]
        end
      end

  ## Filter Values

  The filter receives values as a list of strings:
  - `["value1", "value2"]` - Filter for records where field IN ("value1", "value2")
  - `[]` - No filter applied (none selected)
  - `nil` - No filter applied

  ## Options

  You must implement the `options/1` and `prompt/0` callbacks to define the
  available options and the default prompt text:

      @impl Backpex.Filters.MultiSelect
      def prompt, do: "Select..."

      @impl Backpex.Filters.MultiSelect
      def options(_assigns) do
        [
          {"Label 1", "value1"},
          {"Label 2", "value2"}
        ]
      end

  Note: Unlike Backpex's Ecto-based filtering which uses the `query/3` callback,
  AshBackpex uses `to_ash_expr/3` to generate Ash expressions for filtering.
  """

  @behaviour AshBackpex.Filters.Filter

  defmacro __using__(_opts) do
    quote do
      use Backpex.Filters.MultiSelect

      @behaviour AshBackpex.Filters.Filter

      @impl AshBackpex.Filters.Filter
      defdelegate to_ash_expr(field, value, assigns), to: AshBackpex.Filters.MultiSelect

      defoverridable to_ash_expr: 3
    end
  end

  @doc """
  Converts a multi-select filter value to an Ash.Expr expression.

  ## Parameters

  - `field` - The atom name of the attribute being filtered
  - `value` - The filter value (list of strings from checkbox selections)
  - `assigns` - The LiveView assigns (unused by this filter)

  ## Returns

  - `Ash.Expr.t()` - When one or more values are selected (field IN [...])
  - `nil` - When no filter should be applied (empty list, nil)

  ## Examples

      iex> MultiSelect.to_ash_expr(:status, ["active", "pending"], %{})
      #Ash.Expr<status in ["active", "pending"]>

      iex> MultiSelect.to_ash_expr(:status, ["active"], %{})
      #Ash.Expr<status in ["active"]>

      iex> MultiSelect.to_ash_expr(:status, [], %{})
      nil

      iex> MultiSelect.to_ash_expr(:status, nil, %{})
      nil
  """
  @impl AshBackpex.Filters.Filter
  def to_ash_expr(_field, nil, _assigns), do: nil
  def to_ash_expr(_field, [], _assigns), do: nil

  def to_ash_expr(field, values, _assigns) when is_list(values) do
    require Ash.Expr
    Ash.Expr.expr(^Ash.Expr.ref(field) in ^values)
  end

  def to_ash_expr(_field, _value, _assigns), do: nil
end
