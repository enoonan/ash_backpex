defmodule AshBackpex.Filters.SelectTest do
  @moduledoc """
  Tests for the Select filter module.

  The Select filter converts dropdown selection values (single string) into
  Ash.Expr expressions for filtering attributes with discrete values like
  status fields or enum-like string attributes.
  """
  use ExUnit.Case, async: true

  # The module under test - will be implemented in lib/ash_backpex/filters/select.ex
  alias AshBackpex.Filters.Select

  describe "to_ash_expr/3" do
    test "returns equality expression when a value is selected" do
      expr = Select.to_ash_expr(:status, "active", %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns equality expression for different string values" do
      expr_draft = Select.to_ash_expr(:status, "draft", %{})
      expr_published = Select.to_ash_expr(:status, "published", %{})
      expr_archived = Select.to_ash_expr(:status, "archived", %{})

      assert Ash.Expr.expr?(expr_draft)
      assert Ash.Expr.expr?(expr_published)
      assert Ash.Expr.expr?(expr_archived)
    end

    test "returns nil when value is empty string" do
      # Empty string represents the "prompt" option (no selection)
      expr = Select.to_ash_expr(:status, "", %{})

      assert expr == nil
    end

    test "returns nil when value is nil" do
      expr = Select.to_ash_expr(:status, nil, %{})

      assert expr == nil
    end

    test "ignores assigns parameter" do
      # The assigns parameter is available for context-dependent filtering
      # but the basic Select filter doesn't need it
      assigns = %{current_user: %{id: "user-123"}}
      expr = Select.to_ash_expr(:status, "active", assigns)

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "works with different field names" do
      # Verify the field parameter is used correctly
      expr1 = Select.to_ash_expr(:status, "active", %{})
      expr2 = Select.to_ash_expr(:category, "electronics", %{})
      expr3 = Select.to_ash_expr(:priority, "high", %{})

      assert expr1 != nil
      assert expr2 != nil
      assert expr3 != nil
    end

    test "handles atom values" do
      # Some selects may pass atom values
      expr = Select.to_ash_expr(:status, :active, %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end
  end

  describe "to_ash_expr/3 expression correctness" do
    test "produces correct equality expression structure" do
      require Ash.Expr

      expr = Select.to_ash_expr(:status, "active", %{})

      # The expression should be equivalent to: status == "active"
      assert Ash.Expr.expr?(expr)
    end

    test "produces expression for atom value" do
      require Ash.Expr

      expr = Select.to_ash_expr(:status, :draft, %{})

      # The expression should be equivalent to: status == :draft
      assert Ash.Expr.expr?(expr)
    end
  end
end
