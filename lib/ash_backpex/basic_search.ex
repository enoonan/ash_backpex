defmodule AshBackpex.BasicSearch do
  @moduledoc """
  Provides basic text search functionality for AshBackpex LiveResources.

  This module implements search by applying `contains` filters on fields marked
  as `searchable: true` in the field configuration. When multiple fields are
  searchable, they are combined with OR logic so a search term matches if it
  appears in any searchable field.

  ## Usage

  Search is automatically integrated when you mark fields as searchable:

  ```elixir
  defmodule MyAppWeb.Admin.PostLive do
    use AshBackpex.LiveResource

    backpex do
      resource MyApp.Blog.Post
      layout {MyAppWeb.Layouts, :admin}

      fields do
        field :title do
          searchable true
        end
        field :content do
          searchable true
        end
        field :author_name  # Not searchable
      end
    end
  end
  ```

  With this configuration, searching for "hello" will find posts where
  either the title OR content contains "hello" (case-insensitive).

  ## How It Works

  1. The Backpex UI sends search terms via the `search` query parameter
  2. The adapter passes params to `BasicSearch.apply/3`
  3. This module finds all searchable fields from the LiveResource
  4. It builds an Ash filter with `contains` expressions joined by OR
  5. The filter is applied to the query via `Ash.Query.filter_input/2`

  ## Direct Usage

  While normally called automatically by the adapter, you can use this
  module directly if needed:

  ```elixir
  query = MyApp.Blog.Post |> Ash.Query.new()
  params = %{"search" => "hello"}

  filtered_query = AshBackpex.BasicSearch.apply(query, params, MyAppWeb.Admin.PostLive)
  ```
  """
  require Ash.Query

  @type query :: Ash.Query.t()
  @type params :: map()
  @type live_resource :: module()

  @doc """
  Applies search filters to an Ash query based on searchable fields.

  Takes a query, a params map (typically from `assigns.params`), and a
  LiveResource module. Returns the query with search filters applied.

  If no search value is supplied in params, or the LiveResource has no
  searchable fields, the query is returned unmodified.

  ## Parameters

  - `query` - An `Ash.Query.t()` to filter
  - `params` - Map with optional `"search"` key containing the search term
  - `live_resource` - Module that `use`s `AshBackpex.LiveResource`

  ## Examples

      iex> query = MyApp.Post |> Ash.Query.new()
      iex> AshBackpex.BasicSearch.apply(query, %{"search" => "elixir"}, MyPostLive)
      #Ash.Query<...>

      iex> # No search term - query unchanged
      iex> AshBackpex.BasicSearch.apply(query, %{}, MyPostLive)
      #Ash.Query<...>
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
