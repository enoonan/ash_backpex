Code.ensure_loaded(Phoenix.HTML.FormData.Ash.Changeset)

defmodule AshBackpex.Adapter do
  @config_schema [
    resource: [
      doc: "The `Ash.Resource` that will be used to perform CRUD operations.",
      type: :atom,
      required: true
    ],
    schema: [
      doc: "The `Ash.Resource` for the resource.",
      type: :atom,
      required: true
    ],
    repo: [
      doc: "The `Ecto.Repo` that will be used to perform CRUD operations for the given schema.",
      type: :atom,
      required: true
    ],
    create_action: [
      doc: """
      The resource action to use when creating new items in the admin. Defaults to the primary create action.
      """,
      type: :atom
    ],
    read_action: [
      doc: """
      The resource action to use when reading items in the admin. Defaults to the primary read action.
      """,
      type: :atom
    ],
    update_action: [
      doc: """
      The resource action to use when updating items in the admin. Defaults to the primary update action.
      """,
      type: :atom
    ],
    destroy_action: [
      doc: """
      The resource action to use when destroying items in the admin. Defaults to the primary destroy action.
      """,
      type: :atom
    ],
    create_changeset: [
      doc: """
      Changeset to use when creating items. Additional metadata is passed as a keyword list via the third parameter:
      - `:assigns` - the assigns
      - `:target` - the name of the `form` target that triggered the changeset call. Default to `nil` if the call was not triggered by a form field.
      """,
      type: {:fun, 3},
      default: &__MODULE__.create_changeset/3
    ],
    update_changeset: [
      doc: """
      Changeset to use when updating items. Additional metadata is passed as a keyword list via the third parameter:
      - `:assigns` - the assigns
      - `:target` - the name of the `form` target that triggered the changeset call. Default to `nil` if the call was not triggered by a form field.
      """,
      type: {:fun, 3},
      required: true,
      default: &__MODULE__.update_changeset/3
    ],
    load: [
      doc: """
      Relationships, calculations and aggregates that Ash should load
      - `[comments: [:author]]`
      """,
      type: {:fun, 3},
      default: &__MODULE__.load/3
    ]
  ]
  use Backpex.Adapter, config_schema: @config_schema

  @moduledoc """
    The `Backpex.Adapter` to connect your `Backpex.LiveResource` to an `Ash.Resource`.

    Typically, you should not need to reference this Adapter directly. Sensible defaults will be provided when using AshBackpex.LiveResource
  ```elixir
  defmodule MyAppWeb.Live.PostLive do
    use AshBackpex.Live

    backpex do
      resource MyApp.Blog.Post
      load [:author, :comments]
      fields do
        field :title, Backpex.Fields.Text
        field :author, Backpex.Fields.BelongsTo
        field :comments, Backpex.Fields.HasMany, only: [:show]
      end
      singular_label "Post"
      plural_label "Posts"
    end
  end
  ```

    ## `adapter_config`

    #{NimbleOptions.docs(@config_schema)}
  """

  require Ash.Query
  require Ash.Sort
  alias Ash.Resource.Info, as: Info

  def load(_, _, _), do: []

  def create_changeset(item, params, assigns) do
    live_resource = Keyword.get(assigns, :assigns).live_resource

    create_action = live_resource |> primary_action(:create)

    Ash.Changeset.for_create(item.__struct__, create_action, params,
      actor: Keyword.get(assigns, :assigns).current_user
    )
  end

  def update_changeset(item, params, assigns) do
    live_resource = Keyword.get(assigns, :assigns).live_resource

    update_action = live_resource |> primary_action(:update)

    Ash.Changeset.for_update(item, update_action, params,
      actor: Keyword.get(assigns, :assigns).current_user
    )
  end

  @doc """
  Gets a database record with the given primary key value.

  Returns `nil` if no result was found.
  """
  @impl Backpex.Adapter
  def get(primary_value, assigns, live_resource) do
    config = live_resource.config(:adapter_config)
    primary_key = live_resource.config(:primary_key)
    load_fn = Keyword.get(config, :load)

    load =
      case load_fn.(primary_value, assigns, live_resource) do
        l when is_list(l) -> l
        _ -> []
      end

    config[:resource]
    |> Ash.Query.filter(^Ash.Expr.ref(primary_key) == ^primary_value)
    |> Ash.read_one(actor: assigns.current_user, load: load)
  end

  @doc """
  Returns a list of items by given criteria.
  """
  @impl Backpex.Adapter
  @spec list(keyword(), map(), module()) :: {:ok, list(map())} | {:error, term()}
  def list(criteria, assigns, live_resource) do
    config = live_resource.config(:adapter_config)
    load_fn = Keyword.get(config, :load)

    load =
      case load_fn.(criteria, assigns, live_resource) do
        l when is_list(l) -> l
        _ -> []
      end

    %{size: page_size, page: page_num} = Keyword.get(criteria, :pagination, %{size: 15, page: 1})

    resource = config[:resource]

    query =
      resource
      |> Ash.Query.new()
      |> apply_filters(Keyword.get(criteria, :filters))
      |> apply_search(resource, Keyword.get(criteria, :search, {"", []}))
      |> apply_order(resource, Keyword.get(criteria, :order))
      |> Ash.Query.page(limit: page_size, offset: (page_num - 1) * page_size)

    with {:ok, %{results: results}} <- query |> Ash.read(load: load, actor: assigns.current_user) do
      {:ok, results}
    end
  end

  @doc """
  Returns the number of items matching the given criteria.
  """
  @impl Backpex.Adapter
  def count(criteria, assigns, live_resource) do
    config = live_resource.config(:adapter_config)

    resource = config[:resource]

    resource
    |> Ash.Query.new()
    |> apply_filters(Keyword.get(criteria, :filters))
    |> apply_search(resource, Keyword.get(criteria, :search, {"", []}))
    |> Ash.count(actor: assigns.current_user)
  end

  @doc """
  Deletes multiple items.
  """
  @impl Backpex.Adapter
  def delete_all(items, live_resource) do
    config = live_resource.config(:adapter_config)
    primary_key = live_resource.config(:primary_key)

    ids = Enum.map(items, &Map.fetch!(&1, primary_key))

    result =
      config[:resource]
      |> Ash.Query.filter(^Ash.Expr.ref(primary_key) in ^ids)
      |> Ash.bulk_destroy(:destroy, %{},
        strategy: :stream,
        return_records?: true,
        authorize?: false
      )

    {:ok, result.records}
  end

  @doc """
  Inserts given item.
  """
  @impl Backpex.Adapter
  def insert(changeset, _live_resource) do
    if changeset.valid? do
      case changeset |> Ash.create(authorize?: false) do
        {:ok, item} -> {:ok, item}
        {:error, error} -> {:error, changeset |> Ash.Changeset.add_error(error)}
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Updates given item.
  """
  @impl Backpex.Adapter
  def update(changeset, _live_resource) do
    if changeset.valid? do
      case changeset |> Ash.update(authorize?: false) do
        {:ok, item} -> {:ok, item}
        {:error, error} -> {:error, changeset |> Ash.Changeset.add_error(error)}
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Updates given items.
  """
  @impl Backpex.Adapter
  def update_all(_items, _updates, _live_resource) do
    raise "not implemented yet"
  end

  @doc """
  Applies a change to a given item.
  """
  @impl Backpex.Adapter
  def change(item, attrs, _fields, assigns, _live_resource, _opts) do
    action = assigns.form.source.action

    case assigns.form.source do
      %{action_type: :create} ->
        Ash.Changeset.for_create(item.__struct__, action, attrs)

      %{type: :create} ->
        Ash.Changeset.for_create(item.__struct__, action, attrs)

      %{action_type: :update} ->
        Ash.Changeset.for_update(item, action, attrs)

      %{type: :update} ->
        Ash.Changeset.for_update(item, action, attrs)
    end
  end

  defp apply_filters(query, nil), do: query

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn filter, query ->
      case filter do
        {k, v} ->
          Ash.Query.filter(query, ^Ash.Expr.ref(k) == ^v)

        %{field: :empty_filter} ->
          query

        %{field: f, value: v} when is_list(v) ->
          Ash.Query.filter(query, ^Ash.Expr.ref(f) in ^v)

        %{field: f, value: v} ->
          Ash.Query.filter(query, ^Ash.Expr.ref(f) == ^v)

        filter ->
          if Ash.Expr.expr?(filter), do: Ash.Query.filter(query, ^filter), else: query
      end
    end)
  end

  defp primary_action(live_resource, action_type) do
    config = live_resource.config(:adapter_config)
    resource = live_resource.config(:resource)

    config_val =
      case action_type do
        :create -> :create_action
        :update -> :update_action
      end

    case Keyword.get(config, config_val) do
      nil ->
        primary_action =
          resource
          |> Ash.Resource.Info.actions()
          |> Enum.find(&(&1.type == action_type && &1.primary?))

        primary_action.name

      action ->
        action
    end
  end

  defp classify_sort_field(resource, field) when is_atom(field) do
    cond do
      Info.attribute(resource, field) != nil ->
        {:attribute, Info.attribute(resource, field)}

      Info.calculation(resource, field) != nil ->
        {:calculation, Info.calculation(resource, field)}

      Info.aggregate(resource, field) != nil ->
        {:aggregate, Info.aggregate(resource, field)}

      true ->
        :unknown
    end
  end

  defp apply_order(query, resource, %{by: field, direction: dir}) do
    case classify_sort_field(resource, field) do
      {:attribute, _attr} ->
        query |> Ash.Query.sort([{field, dir}])

      {:aggregate, _agg} ->
        query |> Ash.Query.sort([{field, dir}])

      {:calculation, _calc} ->
        query
        |> Ash.Query.load([field])
        |> Ash.Query.sort([{field, dir}])

      :unknown ->
        # Fallback: try the parser (handles public attrs/aggs/calcs), or ignore
        case Ash.Sort.parse_input(resource, ["#{field}:#{dir}"]) do
          {:ok, sorts} -> Ash.Query.sort(query, sorts)
          _ -> query
        end
    end
  end

  defp apply_order(query, _resource, _other) do
    query
  end

  import Ash.Expr, only: [expr: 1]
  alias Ash.Resource.Info, as: Info

  defp apply_search(query, _resource, {term, _}) when term in [nil, ""], do: query

  defp apply_search(query, resource, {raw_term, fields}) when is_list(fields) do
    term = raw_term |> to_string() |> String.trim()

    if term == "" do
      query
    else
      attrs =
        for {field_key, cfg} <- fields,
            Map.get(cfg, :module) == Backpex.Fields.Text,
            Map.get(cfg, :searchable, false) == true,
            Map.get(cfg, :queryable, resource) == resource,
            attr = to_existing_atom(field_key),
            not is_nil(attr)
            # FIXME: I'm not sure why do we need the info attribute
            # Info.attribute(resource, attr) != nil
        do
          attr
        end

      search_expr =
        Enum.reduce(attrs, nil, fn attr, acc ->
          clause = expr(contains(^Ash.Expr.ref(attr), ^term))

          if acc == nil,
            do: clause,
            else: Ash.Expr.expr(^acc or ^clause)
        end)

      case search_expr do
        nil -> query
        expr_or -> Ash.Query.filter(query, Ash.Expr.expr(^expr_or))
      end
    end
  end

  defp to_existing_atom(a) when is_atom(a), do: a

  defp to_existing_atom(s) when is_binary(s) do
    try do
      String.to_existing_atom(s)
    rescue
      _ -> nil
    end
  end
end
