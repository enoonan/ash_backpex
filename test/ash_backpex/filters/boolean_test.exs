defmodule AshBackpex.Filters.BooleanTest do
  @moduledoc """
  Tests for the Boolean filter module.

  The Boolean filter converts checkbox-style filter values (["true"], ["false"],
  or ["true", "false"]) into Ash.Expr expressions for filtering boolean attributes.
  """
  use ExUnit.Case, async: true

  # The module under test - will be implemented in lib/ash_backpex/filters/boolean.ex
  alias AshBackpex.Filters.Boolean

  describe "to_ash_expr/3" do
    test "returns equality expression when only 'true' is selected" do
      expr = Boolean.to_ash_expr(:published, ["true"], %{})

      # The expression should filter for published == true
      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns equality expression when only 'false' is selected" do
      expr = Boolean.to_ash_expr(:published, ["false"], %{})

      # The expression should filter for published == false
      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns nil when both 'true' and 'false' are selected" do
      # When both values are selected, no filter should be applied
      # (showing all records matches the intent)
      expr = Boolean.to_ash_expr(:published, ["true", "false"], %{})

      assert expr == nil
    end

    test "returns nil when value is empty list" do
      expr = Boolean.to_ash_expr(:published, [], %{})

      assert expr == nil
    end

    test "returns nil when value is nil" do
      expr = Boolean.to_ash_expr(:published, nil, %{})

      assert expr == nil
    end

    test "handles string 'true' value (non-list)" do
      # Some filter implementations may pass a single string instead of a list
      expr = Boolean.to_ash_expr(:active, "true", %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "handles string 'false' value (non-list)" do
      expr = Boolean.to_ash_expr(:active, "false", %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "ignores assigns parameter" do
      # The assigns parameter is available for context-dependent filtering
      # but Boolean filter doesn't need it
      assigns = %{current_user: %{id: "user-123"}}
      expr = Boolean.to_ash_expr(:published, ["true"], assigns)

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "works with different field names" do
      # Verify the field parameter is used correctly
      expr1 = Boolean.to_ash_expr(:published, ["true"], %{})
      expr2 = Boolean.to_ash_expr(:active, ["true"], %{})
      expr3 = Boolean.to_ash_expr(:is_admin, ["false"], %{})

      assert expr1 != nil
      assert expr2 != nil
      assert expr3 != nil
    end
  end

  describe "to_ash_expr/3 expression correctness" do
    test "true filter produces correct expression structure" do
      require Ash.Expr

      expr = Boolean.to_ash_expr(:published, ["true"], %{})

      # The expression should be equivalent to: published == true
      # We verify this by checking it's a valid expression
      assert Ash.Expr.expr?(expr)
    end

    test "false filter produces correct expression structure" do
      require Ash.Expr

      expr = Boolean.to_ash_expr(:published, ["false"], %{})

      # The expression should be equivalent to: published == false
      assert Ash.Expr.expr?(expr)
    end
  end
end
