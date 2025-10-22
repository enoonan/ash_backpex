defmodule AshBackpex.BasicSearch do
  require Ash.Query

  @spec apply(Ash.Query.t(), map(), module()) :: Ash.Query.t()
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

  def apply(%Ash.Query{} = query, _, _), do: query

  defp build_filter(fields, search) do
    fields
    |> Enum.reduce(%{"or" => []}, fn {field_name, _}, acc ->
      new_or = Keyword.put([], field_name, contains: search)
      Map.update(acc, "or", [], fn ors -> [new_or | ors] end)
    end)
  end
end
