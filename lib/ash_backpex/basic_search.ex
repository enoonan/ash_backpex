defmodule AshBackpex.BasicSearch do
  @moduledoc """
  Supports basic search operations using the Ash.Expr `contains` function.
  """
  require Ash.Query

  @type query :: Ash.Query.t()
  @type params :: map()
  @type live_resource :: module()

  @doc """
    Takes a query along, a map representing the `params` key of an `assigns` map, and a live_resource.
    Returns the query with search filters applied.
    If no search value is supplied, or the given `live_resource` doesn't contain any searchable fields, the query is returned unmodified.

    ```elixir
      AshBackpex.BasicSearch.apply(query, %{"search" => "foo"}, MyLiveResource)
    ```
  """
  @spec apply(query(), params(), live_resource()) :: query()
  def apply(query, %{"search" => search}, live_resource) do
    case live_resource.fields() |> Enum.filter(&Map.get(elem(&1, 1), :searchable)) do
      [] ->
        query

      [{field_name, _}] ->
        filter = Keyword.put([], field_name, contains: search)
        query |> Ash.Query.filter_input(filter)

      fields when is_list(fields) ->
        filter = fields |> build_filter(search)
        query |> Ash.Query.filter_input(filter)
    end
  end

  def apply(query, _, _), do: query

  defp build_filter(fields, search) do
    fields
    |> Enum.reduce(%{"or" => []}, fn {field_name, _}, acc ->
      new_or = Keyword.put([], field_name, contains: search)
      Map.update(acc, "or", [], fn ors -> [new_or | ors] end)
    end)
  end
end
