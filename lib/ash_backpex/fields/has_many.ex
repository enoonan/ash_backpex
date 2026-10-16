defmodule AshBackpex.Fields.HasMany do
  @moduledoc """
  A field for `has_many` and `many_to_many` relationships whose option search
  works on every SQL data layer.

  AshBackpex derives this field for `has_many` and `many_to_many`
  relationships. It accepts the same options as `Backpex.Fields.HasMany` and
  delegates rendering, initial option loading, selection and saving to it.

  Backpex searches the options with `ILIKE`, which only Postgres supports.
  This field searches with `lower(display_field) LIKE lower(pattern)` instead,
  which also works on SQLite and MySQL. A custom `select` expression is
  searched the same way.

  Set `module Backpex.Fields.HasMany` on a field to keep Backpex's field.
  """

  use Backpex.Field, config_schema: Backpex.Fields.HasMany.config_schema()

  import Ecto.Query

  alias Backpex.Adapters.Ecto, as: EctoAdapter

  @impl Phoenix.LiveComponent
  defdelegate update(assigns, socket), to: Backpex.Fields.HasMany

  @impl Backpex.Field
  defdelegate render_value(assigns), to: Backpex.Fields.HasMany

  @impl Backpex.Field
  defdelegate render_form(assigns), to: Backpex.Fields.HasMany

  @impl Backpex.Field
  defdelegate display_field(field), to: Backpex.Fields.HasMany

  @impl Backpex.Field
  defdelegate association?(field), to: Backpex.Fields.HasMany

  @impl Backpex.Field
  defdelegate schema(field, schema), to: Backpex.Fields.HasMany

  @impl Backpex.Field
  defdelegate before_changeset(changeset, attrs, metadata, repo, field, assigns),
    to: Backpex.Fields.HasMany

  # Backpex's own handlers below search with `ilike`. These replace them and
  # keep the assigns Backpex's `update/2` and `render_form/1` read.
  @impl Phoenix.LiveComponent
  def handle_event("search", params, socket) do
    search_input = Map.get(params, to_string(socket.assigns.name) <> "_search", "")

    socket
    |> assign(:offset, 0)
    |> assign(:search_input, search_input)
    |> assign_options()
    |> noreply()
  end

  def handle_event("show-more", _params, socket) do
    %{assigns: %{field_options: field_options, offset: offset, options: options}} = socket

    socket
    |> assign(:offset, field_options[:query_limit] + offset)
    |> assign_options(options)
    |> noreply()
  end

  defp assign_options(socket, previous_options \\ []) do
    %{assigns: %{field_options: field_options, search_input: search_input, offset: offset}} =
      socket

    options =
      previous_options ++
        options(socket.assigns, search_input, offset, field_options[:query_limit])

    show_more = count_options(socket.assigns, search_input) > length(options)

    socket
    |> assign(:options, options)
    |> assign(:options_ids, Enum.map(options, fn {_label, value} -> value end))
    |> assign(:show_more, show_more)
  end

  defp options(assigns, search_input, offset, limit) do
    %{field: {_name, field_options} = field} = assigns
    display_field_form = Map.get(field_options, :display_field_form, display_field(field))

    assigns
    |> search_query(search_input)
    |> maybe_paginate(offset, limit)
    |> assigns.live_resource.adapter_config(:repo).all()
    |> Enum.map(fn item -> {Map.get(item, display_field_form), item.id} end)
  end

  defp count_options(assigns, search_input) do
    assigns
    |> search_query(search_input)
    |> subquery()
    |> assigns.live_resource.adapter_config(:repo).aggregate(:count)
  end

  # The root keeps the alias Backpex gives it, which `options_query` and
  # `select` expressions may refer to. The display field is matched by position.
  defp search_query(assigns, search_input) do
    %{field: field, field_options: field_options, name: name} = assigns
    schema = assigns.live_resource.adapter_config(:schema)
    %{queryable: queryable} = schema.__schema__(:association, name)

    queryable
    |> from(as: ^EctoAdapter.name_by_schema(queryable))
    |> maybe_options_query(field_options, assigns)
    |> maybe_search(field_options, display_field(field), String.trim(search_input))
  end

  defp maybe_options_query(query, %{options_query: options_query}, assigns),
    do: options_query.(query, assigns)

  defp maybe_options_query(query, _field_options, _assigns), do: query

  defp maybe_search(query, _field_options, _display_field, ""), do: query

  defp maybe_search(query, field_options, display_field, search_input) do
    pattern = "%#{String.downcase(search_input)}%"

    case Map.get(field_options, :select) do
      nil ->
        where(
          query,
          [record],
          like(fragment("lower(?)", field(record, ^display_field)), ^pattern)
        )

      select ->
        where(query, ^dynamic(like(fragment("lower(?)", ^select), ^pattern)))
    end
  end

  # Without a `query_limit` every option is loaded at once. SQLite rejects an
  # `OFFSET` without a `LIMIT`.
  defp maybe_paginate(query, _offset, nil), do: query
  defp maybe_paginate(query, offset, limit), do: query |> limit(^limit) |> offset(^offset)
end
