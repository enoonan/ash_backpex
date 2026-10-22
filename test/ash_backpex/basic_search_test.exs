defmodule AshBackpex.BasicSearchTest do
  use ExUnit.Case, async: true
  alias AshBackpex.BasicSearch
  alias AshBackpex.TestDomain.{Item, Post}

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
      predicates |> Enum.at(0) |> assert_case_insensitive_contains(:title, search)
    end

    test "adds multiple filters" do
      search = "baz buzz"

      predicates =
        Ash.Query.for_read(Item, :read)
        |> BasicSearch.apply(%{"search" => search}, TestItemLive)
        |> then(fn %{filter: f} -> f |> Ash.Filter.list_predicates() end)

      assert predicates |> length == 3

      for field <- [:content, :note, :name] do
        predicates
        |> Enum.find(
          &match?(%{arguments: [%{arguments: [%{attribute: %{name: ^field}}]}, _]}, &1)
        )
        |> assert_case_insensitive_contains(field, search)
      end
    end

    test "downcases the search term" do
      [predicate] =
        Ash.Query.for_read(Post, :read)
        |> BasicSearch.apply(%{"search" => "FoO BaR"}, TestPostLive)
        |> then(fn %{filter: f} -> f |> Ash.Filter.list_predicates() end)

      assert_case_insensitive_contains(predicate, :title, "foo bar")
    end
  end

  # `contains(string_downcase(field), term)` compiles to `lower(field) LIKE`
  # on every SQL data layer. A bare `contains(field, term)` is a case-sensitive
  # `LIKE` on Postgres, and an `Ash.CiString` term is only `ILIKE` there.
  defp assert_case_insensitive_contains(predicate, field, term) do
    assert %Ash.Query.Function.Contains{arguments: [haystack, ^term]} = predicate

    assert %Ash.Query.Function.StringDowncase{
             arguments: [%Ash.Query.Ref{attribute: %{name: ^field}}]
           } = haystack
  end
end
