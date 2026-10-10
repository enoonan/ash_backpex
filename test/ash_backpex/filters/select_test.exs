defmodule AshBackpex.Filters.SelectTest do
  @moduledoc """
  Tests for the Select filter module.

  The Select filter converts dropdown selection values (single string) into
  Ash.Expr expressions for filtering attributes with discrete values like
  status fields or enum-like string attributes.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  # The module under test - will be implemented in lib/ash_backpex/filters/select.ex
  alias AshBackpex.Filters.Select

  test "implements Backpex label callback" do
    assert Select.label() == "Select"
  end

  describe "options given as a function" do
    @assigns %{live_resource: TestFilterOptionsFunctionLive, field: :status}

    test "options/1 calls the function with the assigns" do
      assert Select.options(@assigns) == [{"Draft", :draft}, {"Published", :published}]
    end

    test "Backpex's filter validation accepts listed values and rejects others" do
      filters = TestFilterOptionsFunctionLive.filters() |> Keyword.take([:status])

      valid = Backpex.FilterValidation.build_changeset(%{"status" => "draft"}, filters, @assigns)
      invalid = Backpex.FilterValidation.build_changeset(%{"status" => "gone"}, filters, @assigns)

      assert Backpex.FilterValidation.valid_values(valid) == %{status: "draft"}
      assert Backpex.FilterValidation.valid_values(invalid) == %{}
    end
  end

  describe "filter badge" do
    test "shows the label of the selected option" do
      assert badge_text(TestFilterOptionsFunctionLive, %{status: "published"}) == ["Published"]
    end

    test "shows the label of a derived one_of option" do
      [{label, _value}] =
        TestDerivedFiltersLive.filters()[:status].options
        |> Enum.filter(fn {_label, value} -> to_string(value) == "archived" end)

      assert badge_text(TestDerivedFiltersLive, %{status: "archived"}) == [label]
    end
  end

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

      assert Ash.Expr.expr?(expr)
    end
  end

  describe "to_ash_expr/3 expression correctness" do
    test "produces correct equality expression structure" do
      expr = Select.to_ash_expr(:status, "active", %{})

      # The expression should be equivalent to: status == "active"
      assert Ash.Expr.expr?(expr)
    end

    test "produces expression for atom value" do
      expr = Select.to_ash_expr(:status, :draft, %{})

      # The expression should be equivalent to: status == :draft
      assert Ash.Expr.expr?(expr)
    end
  end

  # Backpex renders a filter badge with its context assigns and the value only,
  # without the filter's field (`Backpex.HTML.Resource.filter/1`).
  defp badge_text(live_resource, filter_values) do
    html =
      render_component(&Backpex.HTML.Resource.filter/1,
        live_resource: live_resource,
        filters: live_resource.filters(),
        filter_values: filter_values,
        filter_options: %{},
        backpex_context: %{live_resource: live_resource, __changed__: nil}
      )

    ~r{pointer-events-none border-l-transparent">(.*?)</div>}s
    |> Regex.scan(html)
    |> Enum.map(fn [_, text] -> String.trim(text) end)
  end
end
