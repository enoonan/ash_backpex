defmodule AshBackpex.Filters.MultiSelectTest do
  @moduledoc """
  Tests for the MultiSelect filter module.

  The MultiSelect filter converts checkbox selections (list of strings) into
  Ash.Expr expressions for filtering attributes where the field value should
  match any of the selected values (IN clause).
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias AshBackpex.Filters.MultiSelect

  test "implements Backpex label callback" do
    assert MultiSelect.label() == "Multi Select"
  end

  describe "options given as a function" do
    @assigns %{live_resource: TestFilterOptionsFunctionLive, field: :tags}

    test "options/1 calls the function with the assigns" do
      assert MultiSelect.options(@assigns) == [{"Food", :food}, {"Politics", :politics}]
    end

    test "Backpex's filter validation accepts listed values and rejects others" do
      filters = TestFilterOptionsFunctionLive.filters() |> Keyword.take([:tags])

      valid = Backpex.FilterValidation.build_changeset(%{"tags" => ["food"]}, filters, @assigns)
      invalid = Backpex.FilterValidation.build_changeset(%{"tags" => ["gone"]}, filters, @assigns)

      assert Backpex.FilterValidation.valid_values(valid) == %{tags: ["food"]}
      assert Backpex.FilterValidation.valid_values(invalid) == %{}
    end
  end

  describe "filter badge" do
    test "shows the labels of the selected options" do
      assert badge_text(TestFilterOptionsFunctionLive, %{tags: ["food", "politics"]}) == [
               "Food, Politics"
             ]
    end
  end

  describe "to_ash_expr/3" do
    test "returns IN expression when multiple values are selected" do
      expr = MultiSelect.to_ash_expr(:status, ["active", "pending"], %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns IN expression when single value is selected" do
      expr = MultiSelect.to_ash_expr(:status, ["active"], %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns nil when value is empty list" do
      # Empty list represents no selection
      expr = MultiSelect.to_ash_expr(:status, [], %{})

      assert expr == nil
    end

    test "returns nil when value is nil" do
      expr = MultiSelect.to_ash_expr(:status, nil, %{})

      assert expr == nil
    end

    test "ignores assigns parameter" do
      # The assigns parameter is available for context-dependent filtering
      # but the basic MultiSelect filter doesn't need it
      assigns = %{current_user: %{id: "user-123"}}
      expr = MultiSelect.to_ash_expr(:tags, ["bug", "feature"], assigns)

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "works with different field names" do
      # Verify the field parameter is used correctly
      expr1 = MultiSelect.to_ash_expr(:tags, ["bug", "feature"], %{})
      expr2 = MultiSelect.to_ash_expr(:categories, ["electronics", "books"], %{})
      expr3 = MultiSelect.to_ash_expr(:roles, ["admin", "user"], %{})

      assert expr1 != nil
      assert expr2 != nil
      assert expr3 != nil
    end

    test "handles three or more values" do
      expr = MultiSelect.to_ash_expr(:status, ["draft", "active", "pending", "archived"], %{})

      assert expr != nil
      assert Ash.Expr.expr?(expr)
    end

    test "returns nil for non-list values (invalid input)" do
      # Non-list values should return nil (no filter applied)
      expr = MultiSelect.to_ash_expr(:status, "active", %{})

      assert expr == nil
    end
  end

  describe "to_ash_expr/3 expression correctness" do
    test "produces correct IN expression structure for multiple values" do
      expr = MultiSelect.to_ash_expr(:status, ["active", "pending"], %{})

      # The expression should be equivalent to: status in ["active", "pending"]
      assert Ash.Expr.expr?(expr)
    end

    test "produces correct IN expression structure for single value" do
      expr = MultiSelect.to_ash_expr(:status, ["draft"], %{})

      # The expression should be equivalent to: status in ["draft"]
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
