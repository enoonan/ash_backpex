defmodule AshBackpex.RelationshipOptions do
  @moduledoc false

  import Ecto.Query

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
    ash_query = relationship_query(relationship, assigns)

    root_alias = root_alias(query)

    with {:ok, authorized_query, restrict?} <- authorize(ash_query, assigns),
         {:ok, query} <-
           Ash.Query.data_layer_query(authorized_query, initial_query: remove_root_alias(query)),
         {:ok, query} <- finalize_query(query, relationship.destination),
         {:ok, query} <- maybe_restrict_to_authorized_records(query, ash_query, restrict?) do
      query
      |> Map.delete(:__ash_bindings__)
      |> restore_root_alias(root_alias)
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
      context: relationship.context || %{},
      domain: relationship.domain,
      tenant: tenant(assigns)
    )
    |> Ash.Query.do_filter(relationship.filter, parent_stack: [relationship.source])
    |> Ash.Query.sort(relationship.sort)
    |> Ash.Query.default_sort(relationship.default_sort)
  end

  # Policies that resolve to filters are added to the query, so the options read stays one
  # bounded query however large the destination table is. Policies that must check the results
  # at runtime add `authorize_results` hooks a raw data layer query would skip, so those fall
  # back to reading the authorized records and restricting the options to their ids.
  defp authorize(ash_query, assigns) do
    if Ash.Resource.Info.authorizers(ash_query.resource) == [] do
      {:ok, ash_query, false}
    else
      case Ash.can(ash_query, actor(assigns),
             tenant: tenant(assigns),
             alter_source?: true,
             run_queries?: false,
             return_forbidden_error?: true
           ) do
        {:ok, true, %{authorize_results: []} = authorized_query} ->
          {:ok, authorized_query, false}

        {:ok, true, _query_with_runtime_checks} ->
          {:ok, ash_query, true}

        {:ok, false, error} ->
          {:error, error}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp maybe_restrict_to_authorized_records(query, _ash_query, false), do: {:ok, query}

  defp maybe_restrict_to_authorized_records(query, ash_query, true) do
    with {:ok, records} <- Ash.read(ash_query, page: false) do
      case Ash.Resource.Info.primary_key(ash_query.resource) do
        [primary_key] ->
          ids = Enum.map(records, &Map.fetch!(&1, primary_key))
          {:ok, where(query, [record], field(record, ^primary_key) in ^ids)}

        primary_key ->
          {:error,
           ArgumentError.exception(
             "Backpex relationship fields require a single primary key, got: #{inspect(primary_key)}"
           )}
      end
    end
  end

  defp actor(assigns), do: assign(assigns, :actor) || assign(assigns, :current_user)

  defp tenant(assigns), do: assign(assigns, :tenant)

  defp assign(assigns, key) when is_map(assigns), do: Map.get(assigns, key)
  defp assign(_, _), do: nil

  defp root_alias(%Ecto.Query{from: %{as: alias}}), do: alias
  defp root_alias(_query), do: nil

  defp remove_root_alias(%Ecto.Query{from: %{as: nil}} = query), do: query

  defp remove_root_alias(%Ecto.Query{from: %{as: alias}} = query) do
    %{
      query
      | aliases: Map.delete(query.aliases, alias),
        from: %{query.from | as: nil}
    }
  end

  # AshSql data layers rename the root binding to `0`, which Ash filters
  # reference, so the caller's alias is mapped back to the root alongside it.
  # Backpex filters option searches through that alias.
  defp restore_root_alias(query, nil), do: query

  defp restore_root_alias(%Ecto.Query{} = query, alias) do
    %{query | aliases: Map.put(query.aliases, alias, 0)}
  end

  defp restore_root_alias(query, _alias), do: query

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
