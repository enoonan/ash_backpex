defmodule AshBackpex.BasicSearchTest do
  use ExUnit.Case, async: true
  alias AshBackpex.BasicSearch
  alias AshBackpex.TestDomain.{Post, Item}

  describe "AshBackpex.BasicSearch :: it can" do
    test "skip if no search provided" do
      result = Ash.Query.for_read(Post, :read) |> BasicSearch.apply(%{}, TestPostLive)
      assert result.filter |> is_nil
    end

    test "adds single filter" do
      search = "foo bar"

      predicates =
        Ash.Query.for_read(Post, :read)
        |> BasicSearch.apply(%{"search" => search}, TestPostLive)
        |> then(fn %{filter: f} -> f |> Ash.Filter.list_predicates() end)

      assert predicates |> length == 1
      predicates |> Enum.at(0) |> predicate_has_key_val(:contains, :title, search)
    end

    test "adds multiple filters" do
      search = "baz buzz"

      predicates =
        Ash.Query.for_read(Item, :read)
        |> BasicSearch.apply(%{"search" => search}, TestItemLive)
        |> then(fn %{filter: f} -> f |> Ash.Filter.list_predicates() end)

      assert predicates |> length == 3
      [pred1, pred2, pred3] = predicates

      predicate_has_key_val(pred1, :contains, :content, search)
      predicate_has_key_val(pred2, :contains, :note, search)
      predicate_has_key_val(pred3, :contains, :name, search)
    end
  end

  defp predicate_has_key_val(predicate, :contains, key, val) do
    {_, _, keys} = predicate |> Macro.escape()
    assert Keyword.get(keys, :name) == :contains

    [{_, _, arg}, result_val] = Keyword.get(keys, :arguments)
    assert result_val == val

    {_, _, attribute} = Keyword.get(arg, :attribute)
    assert Keyword.get(attribute, :name) == key
    assert Keyword.get(attribute, :source) == key
  end
end
