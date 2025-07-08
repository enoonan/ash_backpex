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
    ```
    use Backpex.LiveResource,
      adapter: InsiWeb.BackpexAshAdapter,
      adapter_config: [
        resource: User,
        schema: User,
        repo: Insi.Repo,
        create_action: :create_with_plaintext_pwd,
        create_changeset: &InsiWeb.BackpexAshAdapter.create_changeset/3,
        update_changeset: &InsiWeb.BackpexAshAdapter.update_changeset/3,
        load: &InsiWeb.BackpexAshAdapter.load/3
      ],
      layout: {InsiWeb.Layouts, :admin}
    ```

    You can specify a default create_action or update_action, which must refer to an action on the resource.

    You must specify the create_changeset, update_changeset, and load functions because for some reason Backpex is not respecting the provided default Nimble values.
    Override them in your resource if necessary.


    The `Backpex.Adapter` to connect your `Backpex.LiveResource` to an `Ash.Resource`.

    ## `adapter_config`

    #{NimbleOptions.docs(@config_schema)}

    > ### Work in progress {: .error}
    >
    > The `Backpex.Adapters.Ash` is currently not usable! It can barely list and show items. We will work on this as we continue to implement  the `Backpex.Adapter` pattern throughout the codebase.

  """

  require Ash.Query

  def load(_, _, _), do: []

  def create_changeset(item, _params, assigns) do
    live_resource = Keyword.get(assigns, :assigns).live_resource
    config = live_resource.config(:adapter_config)

    create_action =
      case Keyword.get(config, :create_action) do
        nil ->
          primary_action =
            item.__struct__
            |> Ash.Resource.Info.actions()
            |> Enum.find(&(&1.type == :create && &1.primary?))

          primary_action.name

        action ->
          action
      end

    Ash.Changeset.for_create(item.__struct__, create_action, %{},
      actor: Keyword.get(assigns, :assigns).current_user
    )
  end

  def update_changeset(item, params, assigns) do
    live_resource = Keyword.get(assigns, :assigns).live_resource
    config = live_resource.config(:adapter_config)

    update_action =
      case Keyword.get(config, :update_action) do
        nil ->
          primary_action =
            item.__struct__
            |> Ash.Resource.Info.actions()
            |> Enum.find(&(&1.type == :update && &1.primary?))

          primary_action.name

        action ->
          action
      end

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
  def list(criteria, assigns, live_resource) do
    config = live_resource.config(:adapter_config)
    load_fn = Keyword.get(config, :load)

    load =
      case load_fn.(criteria, assigns, live_resource) do
        l when is_list(l) -> l
        _ -> []
      end

    query = config[:resource] |> Ash.Query.new()

    query =
      case Keyword.get(criteria, :filters) do
        nil ->
          query

        filters ->
          filters
          |> Enum.reduce(query, fn filter, acc ->
            cond do
              filter.field == :empty_filter ->
                acc

              is_list(filter.value) ->
                acc |> Ash.Query.filter(^Ash.Expr.ref(filter[:field]) in ^filter[:value])

              true ->
                acc |> Ash.Query.filter(^Ash.Expr.ref(filter[:field]) == ^filter[:value])
            end
          end)
      end

    %{size: page_size, page: page_num} = Keyword.get(criteria, :pagination)

    query =
      query
      |> Ash.Query.page(
        limit: page_size,
        offset: (page_num - 1) * page_size
      )

    with {:ok, results} <- query |> Ash.read(load: load, actor: assigns.current_user) do
      {:ok, results.results}
    end
  end

  @doc """
  Returns the number of items matching the given criteria.
  """
  @impl Backpex.Adapter
  def count(_criteria, assigns, live_resource) do
    config = live_resource.config(:adapter_config)

    config[:resource]
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
      |> Ash.bulk_destroy(:destroy, %{}, return_records?: true, authorize?: false)

    {:ok, result.records}
  end

  @doc """
  Inserts given item.
  """
  @impl Backpex.Adapter
  def insert(changeset, live_resource) do
    changeset |> Ash.create(authorize?: false)
  end

  @doc """
  Updates given item.
  """
  @impl Backpex.Adapter
  def update(changeset, live_resource) do
    changeset |> Ash.update(authorize?: false)
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

    case assigns.form.source.action_type do
      :create ->
        Ash.Changeset.for_create(item.__struct__, action, attrs)

      :update ->
        Ash.Changeset.for_update(item, action, attrs)
    end
  end
end
