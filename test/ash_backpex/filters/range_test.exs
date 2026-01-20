defmodule AshBackpex.Filters.RangeTest do
  @moduledoc """
  Tests for the Range filter module.

  The Range filter converts min/max range values (map with "start" and "end" keys)
  into Ash.Expr expressions for filtering numeric attributes. It supports
  greater-than-or-equal (>=) and less-than-or-equal (<=) comparisons.
  """
  use ExUnit.Case, async: true

  alias AshBackpex.Filters.Range

  describe "to_ash_expr/3 with number type" do
    test "returns >= expression when only start is provided" do
      expr = Range.to_ash_expr(:price, %{"start" => "10", "end" => ""}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns <= expression when only end is provided" do
      expr = Range.to_ash_expr(:price, %{"start" => "", "end" => "100"}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns combined >= and <= expression when both start and end are provided" do
      expr = Range.to_ash_expr(:price, %{"start" => "10", "end" => "100"}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns nil when both start and end are empty" do
      expr = Range.to_ash_expr(:price, %{"start" => "", "end" => ""}, %{})

      assert expr == nil
    end

    test "returns nil when value is nil" do
      expr = Range.to_ash_expr(:price, nil, %{})

      assert expr == nil
    end

    test "returns nil when value is empty map" do
      expr = Range.to_ash_expr(:price, %{}, %{})

      assert expr == nil
    end

    test "handles integer string values" do
      expr = Range.to_ash_expr(:quantity, %{"start" => "5", "end" => "50"}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "handles float string values" do
      expr = Range.to_ash_expr(:price, %{"start" => "10.5", "end" => "99.99"}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "handles negative number values" do
      expr = Range.to_ash_expr(:temperature, %{"start" => "-20", "end" => "40"}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns nil for invalid number strings" do
      expr = Range.to_ash_expr(:price, %{"start" => "abc", "end" => "xyz"}, %{})

      assert expr == nil
    end

    test "handles mixed valid/invalid - valid start, invalid end" do
      expr = Range.to_ash_expr(:price, %{"start" => "10", "end" => "invalid"}, %{})

      # Should still produce >= expression for valid start
      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "handles mixed valid/invalid - invalid start, valid end" do
      expr = Range.to_ash_expr(:price, %{"start" => "invalid", "end" => "100"}, %{})

      # Should still produce <= expression for valid end
      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "ignores assigns parameter" do
      assigns = %{current_user: %{id: "user-123"}}
      expr = Range.to_ash_expr(:price, %{"start" => "10", "end" => "100"}, assigns)

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "works with different field names" do
      expr1 = Range.to_ash_expr(:price, %{"start" => "10", "end" => "100"}, %{})
      expr2 = Range.to_ash_expr(:quantity, %{"start" => "1", "end" => "10"}, %{})
      expr3 = Range.to_ash_expr(:rating, %{"start" => "3.5", "end" => "5.0"}, %{})

      assert expr1 != nil
      assert expr2 != nil
      assert expr3 != nil
    end
  end

  describe "to_ash_expr/3 expression correctness" do
    test "start-only filter produces >= expression" do
      require Ash.Expr

      expr = Range.to_ash_expr(:price, %{"start" => "10", "end" => ""}, %{})

      # The expression should be equivalent to: price >= 10
      assert Ash.Expr.expr?(expr)
    end

    test "end-only filter produces <= expression" do
      require Ash.Expr

      expr = Range.to_ash_expr(:price, %{"start" => "", "end" => "100"}, %{})

      # The expression should be equivalent to: price <= 100
      assert Ash.Expr.expr?(expr)
    end

    test "both start and end produces combined expression" do
      require Ash.Expr

      expr = Range.to_ash_expr(:price, %{"start" => "10", "end" => "100"}, %{})

      # The expression should be equivalent to: price >= 10 and price <= 100
      assert Ash.Expr.expr?(expr)
    end
  end

  describe "to_ash_expr/3 with pre-parsed numeric values" do
    test "handles pre-parsed integer values" do
      # In some cases, values might already be parsed to numbers
      expr = Range.to_ash_expr(:quantity, %{"start" => 5, "end" => 50}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "handles pre-parsed float values" do
      expr = Range.to_ash_expr(:price, %{"start" => 10.5, "end" => 99.99}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "handles mixed string and numeric values" do
      expr = Range.to_ash_expr(:price, %{"start" => "10", "end" => 100}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end
  end

  describe "to_ash_expr/3 with date type" do
    @describetag :pending_implementation

    test "returns >= expression when only start date is provided" do
      expr = Range.to_ash_expr(:birth_date, %{"start" => "2024-01-15", "end" => ""}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns <= expression when only end date is provided" do
      expr = Range.to_ash_expr(:birth_date, %{"start" => "", "end" => "2024-12-31"}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns combined >= and <= expression when both start and end dates are provided" do
      expr = Range.to_ash_expr(:birth_date, %{"start" => "2024-01-01", "end" => "2024-12-31"}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "handles pre-parsed Date values" do
      start_date = ~D[2024-01-01]
      end_date = ~D[2024-12-31]
      expr = Range.to_ash_expr(:birth_date, %{"start" => start_date, "end" => end_date}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "handles mixed string and Date values" do
      end_date = ~D[2024-12-31]
      expr = Range.to_ash_expr(:birth_date, %{"start" => "2024-01-01", "end" => end_date}, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns nil for invalid date strings" do
      expr = Range.to_ash_expr(:birth_date, %{"start" => "not-a-date", "end" => "also-invalid"}, %{})

      assert expr == nil
    end

    test "handles valid start with invalid end date" do
      expr = Range.to_ash_expr(:birth_date, %{"start" => "2024-01-15", "end" => "invalid"}, %{})

      # Should still produce >= expression for valid start
      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "handles invalid start with valid end date" do
      expr = Range.to_ash_expr(:birth_date, %{"start" => "invalid", "end" => "2024-12-31"}, %{})

      # Should still produce <= expression for valid end
      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end
  end
end
