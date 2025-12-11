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
    ],
    init_order: [
      doc: """
      You can configure the ordering of the resource index page. By default, the resources are ordered by the id field in ascending order.
      - %{by: :inserted_at, direction: :desc}
      """,
      type: {
        :or,
        [
          {:fun, 1},
          map: [
            by: [
              doc: "The column used for ordering.",
              type: :atom
            ],
            direction: [
              doc: "The order direction",
              type: :atom
            ]
          ]
        ]
      },
      default: %{by: :id, direction: :asc}
    ]
  ]
  use Backpex.Adapter, config_schema: @config_schema
  require Ash.Expr
  alias AshBackpex.{BasicSearch, LoadSelectResolver}

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

  def load(_, _, _), do: []

  def create_changeset(item, params, assigns) do
    live_resource = Keyword.get(assigns, :assigns).live_resource
    current_user = Keyword.get(assigns, :assigns).current_user
    create_action = live_resource |> primary_action(:create)

    Ash.Changeset.for_create(item.__struct__, create_action, params,
      actor: current_user
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
  @spec get(String.t(), keyword(), map(), module()) :: {:ok, list(map())} | {:error, term()}
  def get(primary_value, fields, assigns, live_resource) do
    config = live_resource.config(:adapter_config)
    primary_key = live_resource.config(:primary_key)
    load_fn = Keyword.get(config, :load)

    default_loads =
      case load_fn.([], assigns, live_resource) do
        l when is_list(l) -> l
        _ -> []
      end

    {load, select} = LoadSelectResolver.resolve(config[:resource], fields)

    config[:resource]
    |> Ash.Query.filter(^Ash.Expr.ref(primary_key) == ^primary_value)
    |> Ash.Query.select(select)
    |> Ash.Query.load(default_loads ++ load)
    |> Ash.read_one(actor: assigns.current_user)
    |> case do
      {:ok, %Ash.Error.Query.NotFound{}} -> {:ok, nil}
      {:ok, item} -> {:ok, item}
      err -> err
    end
  end

  @doc """
  Returns a list of items by given criteria.
  """
  @impl Backpex.Adapter
  @spec list(keyword(), keyword(), map(), module()) :: {:ok, list(map())} | {:error, term()}
  def list(criteria, fields, assigns, live_resource) do
    config = live_resource.config(:adapter_config)
    load_fn = Keyword.get(config, :load)

    default_loads =
      case load_fn.([], assigns, live_resource) do
        l when is_list(l) -> l
        _ -> []
      end

    {load, select} = LoadSelectResolver.resolve(config[:resource], fields)

    %{size: page_size, page: page_num} = Keyword.get(criteria, :pagination, %{size: 15, page: 1})

    query =
      config[:resource]
      |> Ash.Query.new()
      |> apply_filters(Keyword.get(criteria, :filters))
      |> BasicSearch.apply(Map.get(assigns, :params), live_resource)
      |> Ash.Query.sort(resolve_sort(assigns, config[:init_order]))
      |> Ash.Query.page(limit: page_size, offset: (page_num - 1) * page_size)
      |> Ash.Query.select(select)
      |> Ash.Query.load(default_loads ++ load)

    with {:ok, %{results: results}} <- query |> Ash.read(actor: assigns.current_user) do
      {:ok, results}
    end
  end

  @doc """
  Returns the number of items matching the given criteria.
  """
  @impl Backpex.Adapter
  @spec count(keyword(), keyword(), map(), module()) :: {:ok, list(map())} | {:error, term()}
  def count(criteria, _fields, assigns, live_resource) do
    config = live_resource.config(:adapter_config)

    config[:resource]
    |> Ash.Query.new()
    |> apply_filters(Keyword.get(criteria, :filters))
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
    # Get actor from assigns for proper authorization during form validation
    actor = Map.get(assigns, :current_user)

    case assigns.form.source do
      %{action_type: :create} ->
        Ash.Changeset.for_create(item.__struct__, action, attrs, actor: actor)

      %{type: :create} ->
        Ash.Changeset.for_create(item.__struct__, action, attrs, actor: actor)

      %{action_type: :update} ->
        Ash.Changeset.for_update(item, action, attrs, actor: actor)

      %{type: :update} ->
        Ash.Changeset.for_update(item, action, attrs, actor: actor)
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

  defp resolve_sort(%{params: %{"order_by" => field, "order_direction" => dir}}, _init) do
    Keyword.put([], String.to_existing_atom(field), String.to_existing_atom(dir))
  end

  defp resolve_sort(assigns, fun) when is_function(fun, 1) do
    fun.(assigns)
  end

  defp resolve_sort(_assigns, %{by: field, direction: :asc}),
    do: Keyword.put([], field, :asc)

  defp resolve_sort(_assigns, %{by: field, direction: :desc}),
    do: Keyword.put([], field, :desc)

  defp resolve_sort(_assigns, _), do: [id: :asc]
end
