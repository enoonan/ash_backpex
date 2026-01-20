defmodule AshBackpex.LiveResource.Transformers.GenerateBackpex do
  @moduledoc """
  Spark DSL transformer that generates Backpex LiveResource code at compile time.

  This transformer is the core of AshBackpex - it reads your `backpex` DSL configuration
  and generates all the necessary code to create a fully functional Backpex LiveResource
  backed by your Ash resource.

  ## What Gets Generated

  When you `use AshBackpex.LiveResource` with a `backpex` block, this transformer
  generates:

  ### Backpex Configuration

  - `use Backpex.LiveResource` with the `AshBackpex.Adapter`
  - Adapter configuration with resource, repo, and action settings
  - Layout, pagination, sorting, and other Backpex options

  ### Callback Implementations

  - `fields/0` - Returns the field configurations with auto-derived modules
  - `filters/0` - Returns the filter configurations
  - `item_actions/1` - Returns item actions (with default stripping support)
  - `singular_name/0` - Returns the singular display name
  - `plural_name/0` - Returns the plural display name
  - `panels/0` - Returns panel configurations

  ### Authorization

  - `can?/3` - Checks Ash authorization for each action type:
    - `:new` checks create action authorization
    - `:index` / `:show` check read action authorization
    - `:edit` checks update action authorization
    - `:delete` checks destroy action authorization
    - Custom actions check for matching Ash actions

  ### Helper Functions

  - `load/3` - Returns configured loads for the adapter
  - `maybe_default_options/1` - Derives select options from `one_of` constraints

  ## Field Type Derivation

  The transformer automatically maps Ash types to Backpex field modules:

  | Ash Type | Backpex Field |
  |----------|---------------|
  | `Ash.Type.String` | `Backpex.Fields.Text` |
  | `Ash.Type.Atom` | `Backpex.Fields.Text` (or `Select` with `one_of`) |
  | `Ash.Type.Boolean` | `Backpex.Fields.Boolean` |
  | `Ash.Type.Integer` | `Backpex.Fields.Number` |
  | `Ash.Type.Float` | `Backpex.Fields.Number` |
  | `Ash.Type.Date` | `Backpex.Fields.Date` |
  | `Ash.Type.Time` | `Backpex.Fields.Time` |
  | `Ash.Type.DateTime` | `Backpex.Fields.DateTime` |
  | `:belongs_to` | `Backpex.Fields.BelongsTo` |
  | `:has_many` | `Backpex.Fields.HasMany` |
  | `{:array, _}` | `Backpex.Fields.MultiSelect` |
  | Aggregates (`:count`, `:sum`, etc.) | `Backpex.Fields.Number` or `Boolean` |

  ## Constraint Handling

  - Attributes with `one_of` constraints automatically use `Backpex.Fields.Select`
  - Array attributes with `one_of` constraints use `Backpex.Fields.MultiSelect`
  - Options are auto-derived from constraint values with title-cased labels

  ## Error Handling

  The transformer raises helpful errors when:

  - A field doesn't exist on the Ash resource
  - A field type can't be derived (suggests using `module` option)
  - The resource lacks a primary key

  ## Internal Use

  This module is invoked automatically by Spark during compilation. You don't
  need to call it directly - just define your `backpex` block and the transformer
  handles the rest.
  """

  use Spark.Dsl.Transformer
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
  def transform(dsl_state) do
    backpex =
      quote do
        @resource Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :resource)

        @domain Ash.Resource.Info.domain(@resource)

        @data_layer_info_module ((@resource |> Ash.Resource.Info.data_layer() |> Atom.to_string()) <>
                                   ".Info")
                                |> String.to_existing_atom()
        @repo @resource |> @data_layer_info_module.repo()

        @panels Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :panels) || []

        @singular_name Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :singular_name) ||
                         @resource |> Atom.to_string() |> String.split(".") |> List.last()

        @plural_name Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :plural_name) ||
                       (@resource |> Atom.to_string() |> String.split(".") |> List.last()) <> "s"

        get_action_name = fn resource, action_type, dsl_opt_path ->
          case Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], dsl_opt_path) do
            nil ->
              case Ash.Resource.Info.primary_action(resource, action_type) do
                nil -> nil
                action -> action.name
              end

            action_name ->
              action_name
          end
        end

        primary_key = fn ->
          case(Ash.Resource.Info.primary_key(@resource)) do
            nil ->
              raise """
              Unable to derive Backpex configuration for #{@resource} because it lacks a primary key.
              """

            [key | _] ->
              key
          end
        end

        @create_action get_action_name.(@resource, :create, :create_action)
        @read_action get_action_name.(@resource, :read, :read_action)
        @update_action get_action_name.(@resource, :update, :update_action)
        @destroy_action get_action_name.(@resource, :destroy, :destroy_action)

        atom_to_title_case = fn atom ->
          atom
          |> Atom.to_string()
          |> String.split("_")
          |> Enum.map_join(" ", &String.capitalize/1)
        end

        get_one_of_constraint = fn attribute_name ->
          case Ash.Resource.Info.attribute(@resource, attribute_name) do
            %{constraints: constraints} ->
              case Keyword.get(constraints, :items) do
                items when is_list(items) -> Keyword.get(items, :one_of, nil)
                _ -> Keyword.get(constraints, :one_of, nil)
              end

            _ ->
              nil
          end
        end

        has_one_of_constraint = fn attribute_name ->
          get_one_of_constraint.(attribute_name) |> is_list
        end

        select_or = fn attribute_name, default ->
          if attribute_name |> has_one_of_constraint.() do
            Backpex.Fields.Select
          else
            default
          end
        end

        derive_type = fn attribute_name ->
          cond do
            !is_nil(Ash.Resource.Info.attribute(@resource, attribute_name)) ->
              Ash.Resource.Info.attribute(@resource, attribute_name).type

            !is_nil(Ash.Resource.Info.relationship(@resource, attribute_name)) ->
              Ash.Resource.Info.relationship(@resource, attribute_name).type

            !is_nil(Ash.Resource.Info.calculation(@resource, attribute_name)) ->
              Ash.Resource.Info.calculation(@resource, attribute_name).type

            !is_nil(Ash.Resource.Info.aggregate(@resource, attribute_name)) ->
              Ash.Resource.Info.aggregate(@resource, attribute_name).kind

            true ->
              att = inspect(attribute_name)

              module_shortname =
                __MODULE__ |> Atom.to_string() |> String.split(".") |> List.last()

              raise """

              Unable to derive the `Backpex.Field` module for the #{att} field in #{module_shortname}.

              To debug:

                * Ensure #{att} is spelled correctly, and is a valid attribute, relation,
                  calculation, aggregate or other loadable entity on the #{module_shortname} resource.

                * If a default field module still cannot be derived, specify it manually by using the `module` macro. E.g.:

                  fields do
                    field #{att} do
                      module Backpex.Fields.Text
                    end
                  end
              """
          end
        end

        multiselect_or = fn attribute_name, default ->
          case derive_type.(attribute_name) do
            {:array, Ash.Type.Atom} ->
              if attribute_name |> has_one_of_constraint.() do
                Backpex.Fields.MultiSelect
              else
                default
              end

            {:array, _} ->
              Backpex.Fields.MultiSelect

            _ ->
              default
          end
        end

        # Get custom field type mappings from config
        custom_mappings = AshBackpex.Config.field_type_mappings(nil)

        lookup_custom_mapping = fn type, constraints, field_name ->
          result =
            case custom_mappings do
              %{} = mappings when map_size(mappings) > 0 ->
                Map.get(mappings, type)

              fun when is_function(fun, 2) ->
                try do
                  fun.(type, constraints)
                rescue
                  e ->
                    module_shortname =
                      __MODULE__ |> Atom.to_string() |> String.split(".") |> List.last()

                    reraise """
                            Error in custom field_type_mappings function while deriving field type.

                            Field: #{inspect(field_name)}
                            Ash type: #{inspect(type)}
                            Constraints: #{inspect(constraints)}
                            Module: #{module_shortname}

                            Original error: #{Exception.message(e)}
                            """,
                            __STACKTRACE__
                end

              _ ->
                nil
            end

          # Validate the return value is a module or nil
          case result do
            nil ->
              nil

            module when is_atom(module) ->
              # Validate module exists and implements Backpex.Field behavior
              module_shortname =
                __MODULE__ |> Atom.to_string() |> String.split(".") |> List.last()

              case Code.ensure_loaded(module) do
                {:module, ^module} ->
                  # Check if module implements Backpex.Field behavior
                  behaviors =
                    module.module_info(:attributes)
                    |> Keyword.get(:behaviour, [])

                  if Backpex.Field in behaviors do
                    module
                  else
                    raise """
                    Invalid field module in custom field_type_mappings.

                    Field: #{inspect(field_name)}
                    Ash type: #{inspect(type)}
                    Module: #{inspect(module)}
                    LiveResource: #{module_shortname}

                    The module #{inspect(module)} does not implement the Backpex.Field behavior.

                    Ensure your custom field module uses `use Backpex.Field` or implements
                    the required callbacks from the Backpex.Field behavior.
                    """
                  end

                {:error, reason} ->
                  raise """
                  Invalid field module in custom field_type_mappings.

                  Field: #{inspect(field_name)}
                  Ash type: #{inspect(type)}
                  Module: #{inspect(module)}
                  LiveResource: #{module_shortname}
                  Error: #{inspect(reason)}

                  The module #{inspect(module)} could not be loaded. Ensure the module exists
                  and is compiled before this LiveResource module.
                  """
              end

            invalid ->
              module_shortname =
                __MODULE__ |> Atom.to_string() |> String.split(".") |> List.last()

              raise """
              Invalid return value from custom field_type_mappings function.

              Field: #{inspect(field_name)}
              Ash type: #{inspect(type)}
              Expected: a module atom or nil
              Got: #{inspect(invalid)}
              Module: #{module_shortname}

              The field_type_mappings function must return a Backpex field module (atom) or nil.
              """
          end
        end

        get_constraints = fn attribute_name ->
          case Ash.Resource.Info.attribute(@resource, attribute_name) do
            %{constraints: constraints} -> constraints
            _ -> []
          end
        end

        try_derive_module = fn attribute_name ->
          type = derive_type.(attribute_name)
          constraints = get_constraints.(attribute_name)

          # Check custom mappings first, then fall back to defaults
          case lookup_custom_mapping.(type, constraints, attribute_name) do
            nil ->
              case type do
                Ash.Type.Boolean ->
                  Backpex.Fields.Boolean

                Ash.Type.String ->
                  attribute_name |> select_or.(Backpex.Fields.Text)

                Ash.Type.Atom ->
                  attribute_name |> select_or.(Backpex.Fields.Text)

                Ash.Type.CiString ->
                  attribute_name |> select_or.(Backpex.Fields.Text)

                Ash.Type.Time ->
                  Backpex.Fields.Time

                Ash.Type.Date ->
                  Backpex.Fields.Date

                Ash.Type.UtcDatetime ->
                  Backpex.Fields.DateTime

                Ash.Type.UtcDatetimeUsec ->
                  Backpex.Fields.DateTime

                Ash.Type.DateTime ->
                  Backpex.Fields.DateTime

                Ash.Type.NaiveDateTime ->
                  Backpex.Fields.DateTime

                Ash.Type.Integer ->
                  attribute_name |> select_or.(Backpex.Fields.Number)

                Ash.Type.Float ->
                  attribute_name |> select_or.(Backpex.Fields.Number)

                :belongs_to ->
                  Backpex.Fields.BelongsTo

                :has_many ->
                  Backpex.Fields.HasMany

                :count ->
                  Backpex.Fields.Number

                :exists ->
                  Backpex.Fields.Boolean

                :sum ->
                  Backpex.Fields.Number

                :max ->
                  Backpex.Fields.Number

                :min ->
                  Backpex.Fields.Number

                :avg ->
                  Backpex.Fields.Number

                {:array, Ash.Type.Atom} ->
                  attribute_name |> multiselect_or.(Backpex.Fields.Text)

                {:array, Ash.Type.String} ->
                  attribute_name |> multiselect_or.(Backpex.Fields.Text)

                {:array, Ash.Type.CiString} ->
                  attribute_name |> multiselect_or.(Backpex.Fields.Text)

                {:array, Ash.Type.Integer} ->
                  attribute_name |> multiselect_or.(Backpex.Fields.Number)

                {:array, Ash.Type.Float} ->
                  attribute_name |> multiselect_or.(Backpex.Fields.Number)
              end

            custom_module ->
              custom_module
          end
        end

        maybe_derive_options = fn attribute_name, module ->
          case module do
            Backpex.Fields.Select ->
              case attribute_name |> get_one_of_constraint.() do
                constraints when is_list(constraints) ->
                  constraints
                  |> Enum.map(fn val ->
                    {atom_to_title_case.(val), val}
                  end)

                _ ->
                  []
              end

            Backpex.Fields.MultiSelect ->
              case attribute_name |> get_one_of_constraint.() do
                [_ | _] -> &__MODULE__.maybe_default_options/1
                _ -> []
              end

            _ ->
              nil
          end
        end

        # Derive the appropriate AshBackpex filter module from an Ash attribute type
        derive_filter_module = fn attribute_name ->
          type = derive_type.(attribute_name)

          case type do
            Ash.Type.Boolean ->
              AshBackpex.Filters.Boolean

            Ash.Type.Atom ->
              if attribute_name |> has_one_of_constraint.() do
                AshBackpex.Filters.Select
              else
                nil
              end

            Ash.Type.String ->
              if attribute_name |> has_one_of_constraint.() do
                AshBackpex.Filters.Select
              else
                nil
              end

            Ash.Type.CiString ->
              if attribute_name |> has_one_of_constraint.() do
                AshBackpex.Filters.Select
              else
                nil
              end

            Ash.Type.Integer ->
              AshBackpex.Filters.Range

            Ash.Type.Float ->
              AshBackpex.Filters.Range

            Ash.Type.Decimal ->
              AshBackpex.Filters.Range

            Ash.Type.Date ->
              AshBackpex.Filters.Range

            Ash.Type.DateTime ->
              AshBackpex.Filters.Range

            Ash.Type.UtcDatetime ->
              AshBackpex.Filters.Range

            Ash.Type.UtcDatetimeUsec ->
              AshBackpex.Filters.Range

            Ash.Type.NaiveDateTime ->
              AshBackpex.Filters.Range

            {:array, Ash.Type.Atom} ->
              if attribute_name |> has_one_of_constraint.() do
                AshBackpex.Filters.MultiSelect
              else
                nil
              end

            {:array, Ash.Type.String} ->
              if attribute_name |> has_one_of_constraint.() do
                AshBackpex.Filters.MultiSelect
              else
                nil
              end

            _ ->
              nil
          end
        end

        # Derive the filter type for Range filters (used by Backpex.Filters.Range type/0 callback)
        # Returns :number for numeric types, :date for dates, :datetime for datetimes
        derive_filter_type = fn attribute_name ->
          type = derive_type.(attribute_name)

          case type do
            Ash.Type.Integer -> :number
            Ash.Type.Float -> :number
            Ash.Type.Decimal -> :number
            Ash.Type.Date -> :date
            Ash.Type.DateTime -> :datetime
            Ash.Type.UtcDatetime -> :datetime
            Ash.Type.UtcDatetimeUsec -> :datetime
            Ash.Type.NaiveDateTime -> :datetime
            _ -> nil
          end
        end

        # Derive filter options for Select and MultiSelect filters from one_of constraints
        # Returns a list of {label, value} tuples for use with Select/MultiSelect filter options/1 callback
        derive_filter_options = fn attribute_name, filter_module ->
          case filter_module do
            AshBackpex.Filters.Select ->
              case attribute_name |> get_one_of_constraint.() do
                constraints when is_list(constraints) ->
                  constraints
                  |> Enum.map(fn val ->
                    {atom_to_title_case.(val), val}
                  end)

                _ ->
                  []
              end

            AshBackpex.Filters.MultiSelect ->
              case attribute_name |> get_one_of_constraint.() do
                constraints when is_list(constraints) ->
                  constraints
                  |> Enum.map(fn val ->
                    {atom_to_title_case.(val), val}
                  end)

                _ ->
                  []
              end

            _ ->
              nil
          end
        end

        @fields Spark.Dsl.Extension.get_entities(__MODULE__, [:backpex, :fields])
                |> Enum.reverse()
                |> Enum.reduce([], fn field, acc ->
                  module = field.module || field.attribute |> try_derive_module.()

                  Keyword.put(
                    acc,
                    field.attribute,
                    %{
                      module: module,
                      label: field.label || field.attribute |> atom_to_title_case.(),
                      only: field.only,
                      except: field.except,
                      default: field.default,
                      options: field.options || field.attribute |> maybe_derive_options.(module),
                      display_field: field.display_field,
                      live_resource: field.live_resource,
                      panel: field.panel,
                      searchable: field.searchable,
                      link_assocs:
                        case {module, Map.get(field, :link_assocs)} do
                          {Backpex.Fields.HasMany, nil} -> true
                          {Backpex.Fields.HasMany, true} -> true
                          {Backpex.Fields.HasMany, false} -> false
                          _ -> nil
                        end
                    }
                    |> Map.to_list()
                    |> Enum.reject(fn {k, v} -> is_nil(v) end)
                    |> Map.new()
                  )
                end)

        @filters Spark.Dsl.Extension.get_entities(__MODULE__, [:backpex, :filters])
                 |> Enum.reduce([], fn filter, acc ->
                   derived_module = filter.attribute |> derive_filter_module.()
                   module = filter.module || derived_module

                   # Raise compile-time error if filter module cannot be derived
                   # and no explicit module was provided
                   if is_nil(module) do
                     att = inspect(filter.attribute)
                     type = derive_type.(filter.attribute)

                     module_shortname =
                       __MODULE__ |> Atom.to_string() |> String.split(".") |> List.last()

                     raise Spark.Error.DslError,
                       module: __MODULE__,
                       message: """
                       Unable to derive the filter module for the #{att} filter in #{module_shortname}.

                       The Ash type #{inspect(type)} cannot be automatically mapped to a filter module.

                       To fix this, specify an explicit filter module:

                         filters do
                           filter #{att} do
                             module AshBackpex.Filters.Text  # or another appropriate filter
                           end
                         end

                       Supported automatic derivations:
                         • Boolean types → AshBackpex.Filters.Boolean
                         • Atom/String with one_of constraints → AshBackpex.Filters.Select
                         • Integer/Float/Decimal → AshBackpex.Filters.Range
                         • Date/DateTime types → AshBackpex.Filters.Range
                       """
                   end

                   Keyword.put(
                     acc,
                     filter.attribute,
                     %{
                       module: module,
                       label: filter.label || filter.attribute |> atom_to_title_case.(),
                       type: filter.attribute |> derive_filter_type.(),
                       options: filter.attribute |> derive_filter_options.(module)
                     }
                     |> Map.to_list()
                     |> Enum.reject(fn {k, v} -> is_nil(v) end)
                     |> Map.new()
                   )
                 end)

        @item_actions Spark.Dsl.Extension.get_entities(__MODULE__, [:backpex, :item_actions])
                      |> Enum.reverse()
                      |> Enum.reduce([], fn field, acc ->
                        Keyword.put(
                          acc,
                          field.name,
                          %{
                            module: field.module,
                            only: field.only,
                            except: field.except
                          }
                          |> Map.to_list()
                          |> Enum.reject(fn {k, v} -> is_nil(v) end)
                          |> Map.new()
                        )
                      end)

        @item_action_strip_defaults Spark.Dsl.Extension.get_opt(
                                      __MODULE__,
                                      [:backpex, :item_actions],
                                      :strip_default
                                    ) || []

        use Backpex.LiveResource,
            [
              adapter: AshBackpex.Adapter,
              adapter_config:
                [
                  resource: @resource,
                  schema: @resource,
                  repo: @repo,
                  create_action: @create_action,
                  read_action: @read_action,
                  update_action: @update_action,
                  destroy_action: @destroy_action,
                  create_changeset:
                    Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :create_changeset) ||
                      (&AshBackpex.Adapter.create_changeset/3),
                  update_changeset:
                    Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :update_changeset) ||
                      (&AshBackpex.Adapter.update_changeset/3),
                  load:
                    case Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :load) do
                      nil -> &AshBackpex.Adapter.load/3
                      some_loads -> &__MODULE__.load/3
                    end
                ]
                |> Keyword.reject(&(&1 |> elem(1) |> is_nil)),
              primary_key: primary_key.(),
              init_order:
                case Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :init_order) do
                  nil -> %{by: primary_key.(), direction: :asc}
                  order -> order
                end,
              layout: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :layout),
              pubsub: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :pubsub),
              per_page_options:
                Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :per_page_options),
              per_page_default:
                Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :per_page_default),
              fluid?: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :fluid?),
              full_text_search:
                Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :full_text_search),
              save_and_continue_button?:
                Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :save_and_continue_button?),
              on_mount: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :on_mount)
            ]
            |> Keyword.reject(&(&1 |> elem(1) |> is_nil))

        @impl Backpex.LiveResource
        def fields, do: @fields

        @impl Backpex.LiveResource
        def filters, do: @filters

        @impl Backpex.LiveResource
        def item_actions(defaults) do
          defaults = Keyword.drop(defaults, @item_action_strip_defaults)

          @item_actions
          |> Enum.reduce(defaults, fn {k, v}, acc ->
            Keyword.put(acc, k, v)
          end)
        end

        @impl Backpex.LiveResource
        def singular_name, do: @singular_name

        @impl Backpex.LiveResource
        def plural_name, do: @plural_name

        @impl Backpex.LiveResource
        def panels, do: @panels

        def load(_, _, _), do: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :load)

        @impl Backpex.LiveResource
        def can?(assigns, action, item \\ %{})

        if @create_action do
          def can?(assigns, :new, _item) do
            Ash.can?({@resource, @create_action}, Map.get(assigns, :current_user))
          end
        else
          def can?(_assigns, :new, _item), do: false
        end

        if @read_action do
          def can?(assigns, :index, _item) do
            Ash.can?({@resource, @read_action}, Map.get(assigns, :current_user))
          end

          def can?(assigns, :show, item) do
            Ash.can?({item, @read_action}, Map.get(assigns, :current_user))
          end
        else
          def can?(_assigns, :index, _item), do: false
          def can?(_assigns, :show, _item), do: false
        end

        if @update_action do
          def can?(assigns, :edit, item) do
            Ash.can?({item, @update_action}, Map.get(assigns, :current_user))
          end
        else
          def can?(_assigns, :edit, _item), do: false
        end

        if @destroy_action do
          def can?(assigns, :delete, item) do
            Ash.can?({item, @destroy_action}, Map.get(assigns, :current_user))
          end
        else
          def can?(_assigns, :delete, _item), do: false
        end

        # Fallback for custom item actions and any other actions
        # Checks Ash authorization if a matching action exists, otherwise allows by default
        def can?(assigns, action, item) do
          case Ash.Resource.Info.action(@resource, action) do
            nil ->
              true

            ash_action ->
              target =
                if is_struct(item) and item.__struct__ == @resource do
                  {item, ash_action.name}
                else
                  {@resource, ash_action.name}
                end

              Ash.can?(target, Map.get(assigns, :current_user))
          end
        end

        def maybe_default_options(assigns) do
          case assigns do
            %{field: {attribute_name, _field_cfg}} ->
              options =
                case Ash.Resource.Info.attribute(@resource, attribute_name) do
                  %{constraints: constraints} ->
                    case Keyword.get(constraints, :items) do
                      items when is_list(items) -> Keyword.get(items, :one_of, nil)
                      _ -> Keyword.get(constraints, :one_of, nil)
                    end

                  _ ->
                    []
                end

              options
              |> Enum.map(fn atom_opt ->
                {
                  atom_opt
                  |> Atom.to_string()
                  |> String.split("_")
                  |> Enum.map_join(" ", &String.capitalize/1),
                  atom_opt
                }
              end)

            _ ->
              []
          end
        end

        Backpex.LiveResource.__before_compile__(__ENV__)
      end

    {:ok, Spark.Dsl.Transformer.eval(dsl_state, [], backpex)}
  end
end
