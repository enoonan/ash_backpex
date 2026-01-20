defmodule AshBackpex.Filters.Select do
  @moduledoc """
  A Select filter for AshBackpex that renders a dropdown for single-value filtering.

  This module provides both the UI rendering (via `Backpex.Filters.Select`) and
  the Ash.Expr generation (via `AshBackpex.Filters.Filter` behavior) for filtering
  attributes with discrete values like status fields or enum-like string attributes.

  ## Usage

  The Select filter is automatically derived for string attributes with `one_of`
  constraints when using `AshBackpex.LiveResource`. You can also use it directly:

      defmodule MyApp.Filters.Status do
        use AshBackpex.Filters.Select

        @impl Backpex.Filter
        def label, do: "Status"

        @impl Backpex.Filters.Select
        def prompt, do: "Select status..."

        @impl Backpex.Filters.Select
        def options(_assigns) do
          [
            {"Draft", "draft"},
            {"Published", "published"},
            {"Archived", "archived"}
          ]
        end
      end

  ## Filter Values

  The filter receives values as a single string:
  - `"active"` - Filter for records where the field equals "active"
  - `""` (empty string) - No filter applied (prompt selected)
  - `nil` - No filter applied

  ## Options

  You must implement the `options/1` and `prompt/0` callbacks to define the
  available options and the default prompt text:

      @impl Backpex.Filters.Select
      def prompt, do: "Select..."

      @impl Backpex.Filters.Select
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
      use Backpex.Filters.Select

      @behaviour AshBackpex.Filters.Filter

      @impl AshBackpex.Filters.Filter
      defdelegate to_ash_expr(field, value, assigns), to: AshBackpex.Filters.Select

      defoverridable to_ash_expr: 3
    end
  end

  @doc """
  Converts a select filter value to an Ash.Expr expression.

  ## Parameters

  - `field` - The atom name of the attribute being filtered
  - `value` - The filter value (string or atom from the dropdown selection)
  - `assigns` - The LiveView assigns (unused by this filter)

  ## Returns

  - `Ash.Expr.t()` - When a value is selected
  - `nil` - When no filter should be applied (empty string, nil)

  ## Examples

      iex> Select.to_ash_expr(:status, "active", %{})
      #Ash.Expr<status == "active">

      iex> Select.to_ash_expr(:status, :draft, %{})
      #Ash.Expr<status == :draft>

      iex> Select.to_ash_expr(:status, "", %{})
      nil

      iex> Select.to_ash_expr(:status, nil, %{})
      nil
  """
  @impl AshBackpex.Filters.Filter
  def to_ash_expr(_field, nil, _assigns), do: nil
  def to_ash_expr(_field, "", _assigns), do: nil

  def to_ash_expr(field, value, _assigns) when is_binary(value) or is_atom(value) do
    require Ash.Expr
    Ash.Expr.expr(^Ash.Expr.ref(field) == ^value)
  end

  def to_ash_expr(_field, _value, _assigns), do: nil
end
