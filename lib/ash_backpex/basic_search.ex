defmodule AshBackpex.BasicSearch do
  @moduledoc """
  Provides basic text search functionality for AshBackpex LiveResources.

  This module implements search by applying case-insensitive `contains`
  filters on fields marked as `searchable: true` in the field configuration. When multiple fields are
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
  either the title OR content contains "hello", ignoring case on every data
  layer (`lower(title) LIKE '%hello%'` in SQL).

  ## How It Works

  1. The Backpex UI sends search terms via the `search` query parameter
  2. The adapter passes params to `BasicSearch.apply/3`
  3. This module finds all searchable fields from the LiveResource
  4. It builds an Ash filter of `contains(string_downcase(field), term)`
     expressions, with the term downcased, joined by OR
  5. The filter is applied to the query via `Ash.Query.filter/2`

  ## Direct Usage

  While normally called automatically by the adapter, you can use this
  module directly if needed:

  ```elixir
  query = MyApp.Blog.Post |> Ash.Query.new()
  params = %{"search" => "hello"}

  filtered_query = AshBackpex.BasicSearch.apply(query, params, MyAppWeb.Admin.PostLive)
  ```
  """
  import Ash.Expr
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

      fields ->
        Ash.Query.filter(query, ^build_filter(fields, search))
    end
  end

  def apply(query, _, _), do: query

  # Searches `lower(field)` for the downcased term. A plain `contains` compiles
  # to a case-sensitive `LIKE` on Postgres, and an `Ash.CiString` needle only
  # becomes `ILIKE` there, so both sides are lowered to match on every data layer.
  defp build_filter(fields, search) do
    term = String.downcase(search)

    fields
    |> Enum.map(fn {field_name, _} ->
      expr(contains(string_downcase(^ref(field_name)), ^term))
    end)
    |> Enum.reduce(fn predicate, acc -> expr(^acc or ^predicate) end)
  end
end
