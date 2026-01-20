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
      You can configure the ordering of the resource index page. By default, the resources are ordered by the primary key field in ascending order.
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
  The Backpex adapter implementation for Ash resources.

  This module implements the `Backpex.Adapter` behaviour to bridge Backpex's admin
  interface operations with Ash Framework's resource system. It handles all CRUD
  operations, search, filtering, sorting, and pagination by translating Backpex
  requests into Ash queries and actions.

  ## Automatic Usage

  When you use `AshBackpex.LiveResource`, this adapter is automatically configured
  for you. You typically don't need to reference it directly:

  ```elixir
  defmodule MyAppWeb.Admin.PostLive do
    use AshBackpex.LiveResource

    backpex do
      resource MyApp.Blog.Post
      layout {MyAppWeb.Layouts, :admin}

      fields do
        field :title
        field :author
      end
    end
  end
  ```

  ## Key Features

  ### CRUD Operations

  The adapter translates Backpex operations to Ash actions:

  - `get/4` - Fetches a single record using `Ash.read_one/2`
  - `list/4` - Lists records with pagination using `Ash.read/2`
  - `count/4` - Counts matching records using `Ash.count/2`
  - `insert/2` - Creates records using `Ash.create/2`
  - `update/2` - Updates records using `Ash.update/2`
  - `delete_all/2` - Bulk deletes using `Ash.bulk_destroy/4`

  ### Authorization

  The adapter respects Ash authorization by passing the `actor` option
  (from `assigns.current_user`) to all Ash operations. This integrates
  with your Ash policies automatically.

  ### Custom Actions

  You can specify which Ash actions to use via the DSL or adapter config:

  ```elixir
  backpex do
    resource MyApp.Blog.Post
    layout {MyAppWeb.Layouts, :admin}

    create_action :admin_create
    read_action :admin_read
    update_action :admin_update
    destroy_action :soft_delete
  end
  ```

  If not specified, the primary action for each type is used.

  ### Custom Changesets

  For advanced control over creates and updates, provide custom changeset functions:

  ```elixir
  backpex do
    resource MyApp.Blog.Post
    layout {MyAppWeb.Layouts, :admin}

    create_changeset fn item, params, metadata ->
      assigns = Keyword.get(metadata, :assigns)
      target = Keyword.get(metadata, :target)

      Ash.Changeset.for_create(item.__struct__, :create, params,
        actor: assigns.current_user
      )
    end
  end
  ```

  The changeset function receives:
  - `item` - The struct being created/updated
  - `params` - The form parameters
  - `metadata` - Keyword list with `:assigns` and `:target` keys

  ### Loads

  Relationships, calculations, and aggregates are loaded automatically based on
  the fields you configure. Additional loads can be specified:

  ```elixir
  backpex do
    resource MyApp.Blog.Post
    layout {MyAppWeb.Layouts, :admin}
    load [:author, :comments, nested: [:author]]
  end
  ```

  ### Search and Filtering

  Search is handled by `AshBackpex.BasicSearch` which applies `contains` filters
  on searchable fields. Filters from the Backpex UI are translated to Ash query
  filters automatically.

  ### Sorting

  Initial sorting is configurable via `init_order`:

  ```elixir
  backpex do
    resource MyApp.Blog.Post
    layout {MyAppWeb.Layouts, :admin}
    init_order %{by: :inserted_at, direction: :desc}
  end
  ```

  User-requested sorting from the UI is handled via query parameters.

  ## Configuration Schema

  #{NimbleOptions.docs(@config_schema)}
  """

  require Ash.Query

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
      |> apply_filters(Keyword.get(criteria, :filters), assigns)
      |> BasicSearch.apply(Map.get(assigns, :params), live_resource)
      |> Ash.Query.sort(resolve_sort(assigns, live_resource.config(:init_order)))
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
    |> apply_filters(Keyword.get(criteria, :filters), assigns)
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

  defp apply_filters(query, nil, _assigns), do: query

  defp apply_filters(query, filters, assigns) do
    Enum.reduce(filters, query, fn filter, query ->
      case filter do
        {k, v} ->
          Ash.Query.filter(query, ^Ash.Expr.ref(k) == ^v)

        %{field: :empty_filter} ->
          query

        %{field: f, value: v, module: module} when not is_nil(module) ->
          apply_filter_with_module(query, f, v, module, assigns)

        %{field: f, value: v} when is_list(v) ->
          Ash.Query.filter(query, ^Ash.Expr.ref(f) in ^v)

        %{field: f, value: v} ->
          Ash.Query.filter(query, ^Ash.Expr.ref(f) == ^v)

        filter ->
          if Ash.Expr.expr?(filter), do: Ash.Query.filter(query, ^filter), else: query
      end
    end)
  end

  @doc """
  Applies a filter to the query using a filter module's `to_ash_expr/3` callback.

  This helper function is used when filters have an associated module that implements
  the `AshBackpex.Filters.Filter` behavior. The module's `to_ash_expr/3` callback
  is invoked to generate an `Ash.Expr` expression, which is then applied to the query.

  ## Parameters

  - `query` - The `Ash.Query` to apply the filter to
  - `field` - The atom name of the attribute being filtered
  - `value` - The filter value from the UI
  - `module` - The filter module implementing `AshBackpex.Filters.Filter`
  - `assigns` - The LiveView assigns map

  ## Returns

  The query with the filter applied, or the unchanged query if the filter module
  returns `nil` from `to_ash_expr/3`.

  ## Example

      iex> query = Ash.Query.new(MyResource)
      iex> apply_filter_with_module(query, :published, ["true"], AshBackpex.Filters.Boolean, %{})
      # Returns query with filter: published == true
  """
  @spec apply_filter_with_module(Ash.Query.t(), atom(), any(), module(), map()) :: Ash.Query.t()
  def apply_filter_with_module(query, field, value, module, assigns) do
    case module.to_ash_expr(field, value, assigns) do
      nil -> query
      expr -> Ash.Query.filter(query, ^expr)
    end
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
