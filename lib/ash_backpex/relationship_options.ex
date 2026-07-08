defmodule AshBackpex.RelationshipOptions do
  @moduledoc false

  @relationship_types [:belongs_to, :has_one, :has_many, :many_to_many]

  @doc false
  def options_query?(resource, relationship_name) do
    resource
    |> Ash.Resource.Info.relationship(relationship_name)
    |> relationship_has_options_query?()
  end

  @doc false
  def apply_options_query(resource, relationship_name, query, assigns) do
    relationship = Ash.Resource.Info.relationship(resource, relationship_name)
    apply_options_query(query, relationship, assigns)
  end

  defp relationship_has_options_query?(%{type: type} = relationship)
       when type in @relationship_types do
    !!relationship.filter || List.wrap(relationship.sort) != [] ||
      List.wrap(relationship.default_sort) != []
  end

  defp relationship_has_options_query?(_), do: false

  defp apply_options_query(query, %{type: type} = relationship, assigns)
       when type in @relationship_types do
    with {:ok, query} <-
           relationship
           |> relationship_query(assigns)
           |> Ash.Query.data_layer_query(initial_query: remove_root_alias(query)),
         {:ok, query} <- finalize_query(query, relationship.destination) do
      Map.delete(query, :__ash_bindings__)
    else
      {:error, error} -> raise ArgumentError, Exception.message(Ash.Error.to_error_class(error))
    end
  end

  defp relationship_query(relationship, assigns) do
    read_action =
      relationship.read_action ||
        Ash.Resource.Info.primary_action!(relationship.destination, :read).name

    relationship.destination
    |> Ash.Query.for_read(read_action, %{},
      actor: actor(assigns),
      authorize?: false,
      context: relationship.context || %{},
      domain: relationship.domain,
      tenant: tenant(assigns)
    )
    |> Ash.Query.do_filter(relationship.filter, parent_stack: [relationship.source])
    |> Ash.Query.sort(relationship.sort)
    |> Ash.Query.default_sort(relationship.default_sort)
  end

  defp actor(assigns), do: assign(assigns, :actor) || assign(assigns, :current_user)

  defp tenant(assigns), do: assign(assigns, :tenant)

  defp assign(assigns, key) when is_map(assigns), do: Map.get(assigns, key)
  defp assign(_, _), do: nil

  defp remove_root_alias(%Ecto.Query{from: %{as: nil}} = query), do: query

  defp remove_root_alias(%Ecto.Query{from: %{as: alias}} = query) do
    %{
      query
      | aliases: Map.delete(query.aliases, alias),
        from: %{query.from | as: nil}
    }
  end

  defp finalize_query(%{__ash_bindings__: _} = query, destination) do
    case Ash.DataLayer.return_query(query, destination) do
      {:ok, query} -> maybe_finalize_ash_sql_query(query, destination)
      {:error, error} -> {:error, error}
    end
  end

  defp finalize_query(query, _destination), do: {:ok, query}

  defp maybe_finalize_ash_sql_query(
         %{__ash_bindings__: %{sort_applied?: true}} = query,
         _destination
       ) do
    {:ok, query}
  end

  defp maybe_finalize_ash_sql_query(%{__ash_bindings__: %{sort: sort}} = query, destination)
       when sort not in [nil, []] do
    ash_sql_query = Module.concat(AshSql, Query)

    if Code.ensure_loaded?(ash_sql_query) && function_exported?(ash_sql_query, :return_query, 2) do
      ash_sql_query
      |> Function.capture(:return_query, 2)
      |> then(& &1.(query, destination))
    else
      {:ok, query}
    end
  end

  defp maybe_finalize_ash_sql_query(query, _destination), do: {:ok, query}
end
