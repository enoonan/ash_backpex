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
  | `:many_to_many` | `Backpex.Fields.HasMany` |
  | `{:array, EmbeddedResource}` with InlineCRUD | `AshBackpex.Fields.InlineCRUD` (`type: :embed`) |
  | singular `EmbeddedResource` | `AshBackpex.Fields.Embedded` (explicit) |
  | `{:array, _}` | `Backpex.Fields.MultiSelect` |
  | Aggregates (`:count`, `:sum`, etc.) | `Backpex.Fields.Number` or `Boolean` |

  ## Constraint Handling

  - Attributes with `one_of` constraints automatically use `Backpex.Fields.Select`
  - Array attributes with `one_of` constraints use `Backpex.Fields.MultiSelect`
  - Options are auto-derived from constraint values with title-cased labels
  - Relationship filters and sorts are auto-derived into Backpex `options_query`

  ## Error Handling

  The transformer raises helpful errors when:

  - A field doesn't exist on the Ash resource
  - A field type can't be derived (suggests using `module` option)
  - Recursive `child_fields` do not resolve to an immediate child Ash resource
  - InlineCRUD is used with a cardinality other than `has_many` or an embedded-resource array
  - The resource lacks a primary key
  - The LiveResource defines `can?/3`, `fields/0`, `filters/0`, `item_actions/1`,
    or `layout/1` itself. The generated callback would silently replace it, so
    the error points to the Ash policy or DSL option to use instead.

  ## Internal Use

  This module is invoked automatically by Spark during compilation. You don't
  need to call it directly - just define your `backpex` block and the transformer
  handles the rest.
  """

  use Spark.Dsl.Transformer
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
  def transform(dsl_state) do
    ensure_no_replaced_callbacks!(dsl_state)

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

        get_one_of_constraint = fn resource, attribute_name ->
          case Ash.Resource.Info.attribute(resource, attribute_name) do
            %{constraints: constraints} ->
              case Keyword.get(constraints, :items) do
                items when is_list(items) -> Keyword.get(items, :one_of, nil)
                _ -> Keyword.get(constraints, :one_of, nil)
              end

            _ ->
              nil
          end
        end

        has_one_of_constraint = fn resource, attribute_name ->
          get_one_of_constraint.(resource, attribute_name) |> is_list
        end

        select_or = fn resource, attribute_name, default ->
          if has_one_of_constraint.(resource, attribute_name) do
            Backpex.Fields.Select
          else
            default
          end
        end

        derive_type = fn resource, attribute_name ->
          cond do
            !is_nil(Ash.Resource.Info.attribute(resource, attribute_name)) ->
              Ash.Resource.Info.attribute(resource, attribute_name).type

            !is_nil(Ash.Resource.Info.relationship(resource, attribute_name)) ->
              Ash.Resource.Info.relationship(resource, attribute_name).type

            !is_nil(Ash.Resource.Info.calculation(resource, attribute_name)) ->
              Ash.Resource.Info.calculation(resource, attribute_name).type

            !is_nil(Ash.Resource.Info.aggregate(resource, attribute_name)) ->
              Ash.Resource.Info.aggregate(resource, attribute_name).kind

            true ->
              att = inspect(attribute_name)

              resource_shortname =
                resource |> Atom.to_string() |> String.split(".") |> List.last()

              raise """

              Unable to derive the `Backpex.Field` module for the #{att} field in #{resource_shortname}.

              To debug:

                * Ensure #{att} is spelled correctly, and is a valid attribute, relation,
                  calculation, aggregate or other loadable entity on the #{resource_shortname} resource.

                * If a default field module still cannot be derived, specify it manually by using the `module` macro. E.g.:

                  fields do
                    field #{att} do
                      module Backpex.Fields.Text
                    end
                  end
              """
          end
        end

        multiselect_or = fn resource, attribute_name, default ->
          case derive_type.(resource, attribute_name) do
            {:array, Ash.Type.Atom} ->
              if has_one_of_constraint.(resource, attribute_name) do
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

        get_constraints = fn resource, attribute_name ->
          case Ash.Resource.Info.attribute(resource, attribute_name) do
            %{constraints: constraints} -> constraints
            _ -> []
          end
        end

        try_derive_module = fn resource, attribute_name ->
          type = derive_type.(resource, attribute_name)
          constraints = get_constraints.(resource, attribute_name)

          # Check custom mappings first, then fall back to defaults
          case lookup_custom_mapping.(type, constraints, attribute_name) do
            nil ->
              case type do
                Ash.Type.Boolean ->
                  Backpex.Fields.Boolean

                Ash.Type.String ->
                  select_or.(resource, attribute_name, Backpex.Fields.Text)

                Ash.Type.Atom ->
                  select_or.(resource, attribute_name, Backpex.Fields.Text)

                Ash.Type.CiString ->
                  select_or.(resource, attribute_name, Backpex.Fields.Text)

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
                  select_or.(resource, attribute_name, Backpex.Fields.Number)

                Ash.Type.Float ->
                  select_or.(resource, attribute_name, Backpex.Fields.Number)

                :belongs_to ->
                  Backpex.Fields.BelongsTo

                :has_many ->
                  Backpex.Fields.HasMany

                :many_to_many ->
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
                  multiselect_or.(resource, attribute_name, Backpex.Fields.Text)

                {:array, Ash.Type.String} ->
                  multiselect_or.(resource, attribute_name, Backpex.Fields.Text)

                {:array, Ash.Type.CiString} ->
                  multiselect_or.(resource, attribute_name, Backpex.Fields.Text)

                {:array, Ash.Type.Integer} ->
                  multiselect_or.(resource, attribute_name, Backpex.Fields.Number)

                {:array, Ash.Type.Float} ->
                  multiselect_or.(resource, attribute_name, Backpex.Fields.Number)
              end

            custom_module ->
              custom_module
          end
        end

        maybe_derive_options = fn resource, attribute_name, module ->
          case module do
            Backpex.Fields.Select ->
              case get_one_of_constraint.(resource, attribute_name) do
                constraints when is_list(constraints) ->
                  constraints
                  |> Enum.map(fn val ->
                    {atom_to_title_case.(val), val}
                  end)

                _ ->
                  []
              end

            module when module in [Backpex.Fields.MultiSelect, Backpex.Fields.Checkgroup] ->
              case get_one_of_constraint.(resource, attribute_name) do
                [_ | _] -> &__MODULE__.maybe_default_options/1
                _ -> []
              end

            _ ->
              nil
          end
        end

        maybe_derive_options_query = fn resource, attribute_name, module ->
          case module do
            relationship_module
            when relationship_module in [
                   AshBackpex.Fields.BelongsTo,
                   Backpex.Fields.BelongsTo,
                   Backpex.Fields.HasMany
                 ] ->
              if AshBackpex.RelationshipOptions.options_query?(resource, attribute_name) do
                {resource, attribute_name}
              end

            _ ->
              nil
          end
        end

        # Derive the appropriate AshBackpex filter module from an Ash attribute type
        derive_filter_module = fn attribute_name ->
          type = derive_type.(@resource, attribute_name)

          case type do
            Ash.Type.Boolean ->
              AshBackpex.Filters.Boolean

            Ash.Type.Atom ->
              if has_one_of_constraint.(@resource, attribute_name) do
                AshBackpex.Filters.Select
              else
                nil
              end

            Ash.Type.String ->
              if has_one_of_constraint.(@resource, attribute_name) do
                AshBackpex.Filters.Select
              else
                nil
              end

            Ash.Type.CiString ->
              if has_one_of_constraint.(@resource, attribute_name) do
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
              if has_one_of_constraint.(@resource, attribute_name) do
                AshBackpex.Filters.MultiSelect
              else
                nil
              end

            {:array, Ash.Type.String} ->
              if has_one_of_constraint.(@resource, attribute_name) do
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
          type = derive_type.(@resource, attribute_name)

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
              case get_one_of_constraint.(@resource, attribute_name) do
                constraints when is_list(constraints) ->
                  constraints
                  |> Enum.map(fn val ->
                    {atom_to_title_case.(val), val}
                  end)

                _ ->
                  []
              end

            AshBackpex.Filters.MultiSelect ->
              case get_one_of_constraint.(@resource, attribute_name) do
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

        field_resource = fn resource, field ->
          relationship = Ash.Resource.Info.relationship(resource, field.attribute)
          attribute = Ash.Resource.Info.attribute(resource, field.attribute)

          child_resource =
            case {relationship, attribute} do
              {%{destination: destination}, _attribute} ->
                destination

              {nil, %{type: {:array, type}}} ->
                if Ash.Resource.Info.resource?(type), do: type

              {nil, %{type: type}} ->
                if Ash.Resource.Info.resource?(type), do: type

              _other ->
                nil
            end

          {relationship, attribute, child_resource}
        end

        transform_field = fn transform_field, field, resource, nested?, parent_path ->
          field_path = parent_path ++ [field.attribute]
          formatted_path = Enum.map_join(field_path, ".", &to_string/1)

          module =
            case field.module do
              nil when is_nil(resource) ->
                raise Spark.Error.DslError,
                  module: __MODULE__,
                  message: """
                  LiveResource: #{inspect(__MODULE__)}
                  field path: #{formatted_path}

                  The parent field does not resolve to an Ash resource, so the module for
                  #{inspect(field.attribute)} cannot be derived. Remove `child_fields` from the
                  non-resource parent or point it at a relationship or typed embedded resource.
                  """

              nil ->
                try_derive_module.(resource, field.attribute)

              module ->
                module
            end

          inline_crud? =
            module in [AshBackpex.Fields.InlineCRUD, Backpex.Fields.InlineCRUD]

          {relationship, attribute, nested_resource} = field_resource.(resource, field)

          inferred_inline_type =
            case {relationship, attribute} do
              {%{type: :has_many}, _attribute} ->
                :assoc

              {nil, %{type: {:array, type}}} ->
                if Ash.Resource.Info.resource?(type) && Ash.Resource.Info.embedded?(type),
                  do: :embed

              _other ->
                nil
            end

          singular_embed? =
            case attribute do
              %{type: type} when is_atom(type) ->
                Ash.Resource.Info.resource?(type) && Ash.Resource.Info.embedded?(type)

              _attribute ->
                false
            end

          if inline_crud? && is_nil(inferred_inline_type) do
            correction =
              cond do
                singular_embed? ->
                  "This is a singular embedded resource; use `AshBackpex.Fields.Embedded` instead."

                relationship ->
                  "InlineCRUD supports only `has_many` relationships; use the field module for this relationship cardinality."

                match?(%{type: {:array, _type}}, attribute) ->
                  "InlineCRUD arrays must contain a typed embedded Ash resource."

                true ->
                  "Use InlineCRUD only for a `has_many` relationship or an `{:array, EmbeddedResource}` attribute."
              end

            raise Spark.Error.DslError,
              module: __MODULE__,
              message: """
              LiveResource: #{inspect(__MODULE__)}
              field path: #{formatted_path}

              InlineCRUD is not supported for this field cardinality. #{correction}
              """
          end

          belongs_to? =
            module in [AshBackpex.Fields.BelongsTo, Backpex.Fields.BelongsTo]

          can_typeahead? = field.typeahead == true && belongs_to?

          if field.typeahead == true && not can_typeahead? do
            raise Spark.Error.DslError,
              module: __MODULE__,
              message:
                "`typeahead true` is only supported on belongs_to fields using Backpex.Fields.BelongsTo or AshBackpex.Fields.BelongsTo"
          end

          output_module =
            cond do
              inline_crud? -> AshBackpex.Fields.InlineCRUD
              can_typeahead? || (nested? && belongs_to?) -> AshBackpex.Fields.BelongsTo
              true -> module
            end

          type = Map.get(field, :type) || if(inline_crud?, do: inferred_inline_type)

          child_fields =
            case field.child_fields do
              child_fields when child_fields in [nil, []] ->
                nil

              child_fields when is_list(child_fields) ->
                if is_nil(nested_resource) do
                  raise Spark.Error.DslError,
                    module: __MODULE__,
                    message: """
                    LiveResource: #{inspect(__MODULE__)}
                    field path: #{formatted_path}

                    `child_fields` does not resolve to a relationship or typed embedded Ash resource.
                    Remove `child_fields` or change #{inspect(field.attribute)} to a relationship or
                    typed embedded resource.
                    """
                end

                Enum.map(child_fields, fn child ->
                  transform_field.(transform_field, child, nested_resource, true, field_path)
                end)
            end

          derived_options_query =
            cond do
              Map.get(field, :options_query) ->
                nil

              can_typeahead? ->
                {resource, field.attribute}

              true ->
                maybe_derive_options_query.(resource, field.attribute, module)
            end

          options =
            Map.get(field, :options) ||
              maybe_derive_options.(resource, field.attribute, module)

          link_assocs =
            case {module, Map.get(field, :link_assocs)} do
              {Backpex.Fields.HasMany, nil} -> true
              {Backpex.Fields.HasMany, true} -> true
              {Backpex.Fields.HasMany, false} -> false
              _ -> nil
            end

          config =
            field
            |> Map.from_struct()
            |> Map.drop([:attribute, :__spark_metadata__])
            |> Map.merge(%{
              module: output_module,
              label: field.label || atom_to_title_case.(field.attribute),
              type: type,
              child_fields: child_fields,
              options: options,
              link_assocs: link_assocs,
              typeahead: if(can_typeahead?, do: true),
              typeahead_limit: if(can_typeahead?, do: Map.get(field, :typeahead_limit)),
              __ash_backpex_options_query__: derived_options_query
            })
            |> Map.reject(fn {_key, value} -> is_nil(value) end)

          {field.attribute, config}
        end

        @fields Spark.Dsl.Extension.get_entities(__MODULE__, [:backpex, :fields])
                |> Enum.reverse()
                |> Enum.reduce([], fn field, fields ->
                  {attribute, config} =
                    transform_field.(transform_field, field, @resource, false, [])

                  Keyword.put(fields, attribute, config)
                end)

        @filters Spark.Dsl.Extension.get_entities(__MODULE__, [:backpex, :filters])
                 |> Enum.reduce([], fn filter, acc ->
                   derived_module = filter.attribute |> derive_filter_module.()
                   module = filter.module || derived_module

                   # Raise compile-time error if filter module cannot be derived
                   # and no explicit module was provided
                   if is_nil(module) do
                     att = inspect(filter.attribute)
                     type = derive_type.(@resource, filter.attribute)

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
                       type: filter.type || filter.attribute |> derive_filter_type.(),
                       options:
                         filter.options || filter.attribute |> derive_filter_options.(module),
                       prompt: filter.prompt
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

        @backpex_layout Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :layout)

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
              on_mount: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :on_mount),
              persist: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :persist),
              context_assigns:
                case Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :context_assigns) do
                  keys when is_list(keys) -> Enum.uniq(keys ++ [:current_user, :actor])
                  all -> all
                end
            ]
            |> Keyword.reject(&(&1 |> elem(1) |> is_nil))

        @impl Backpex.LiveResource
        def fields do
          finalize_field = fn finalize_field, {attribute, config} ->
            config =
              case Map.pop(config, :__ash_backpex_options_query__) do
                {nil, config} ->
                  config

                {{resource, relationship_name}, config} ->
                  Map.put(config, :options_query, fn query, assigns ->
                    AshBackpex.RelationshipOptions.apply_options_query(
                      resource,
                      relationship_name,
                      query,
                      assigns
                    )
                  end)
              end

            config =
              case Map.fetch(config, :child_fields) do
                {:ok, child_fields} ->
                  Map.put(
                    config,
                    :child_fields,
                    Enum.map(child_fields, &finalize_field.(finalize_field, &1))
                  )

                :error ->
                  config
              end

            {attribute, config}
          end

          Enum.map(@fields, &finalize_field.(finalize_field, &1))
        end

        @impl Backpex.LiveResource
        def layout(_assigns), do: @backpex_layout

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

  # Backpex marks these callbacks overridable, and the code generated below is
  # evaluated after the LiveResource's own module body. A user definition of any
  # of them is therefore replaced by the generated one without a warning.
  @replaced_callbacks [can?: 3, fields: 0, filters: 0, item_actions: 1, layout: 1]

  defp ensure_no_replaced_callbacks!(dsl_state) do
    module = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

    if module && Module.open?(module) do
      Enum.each(@replaced_callbacks, fn callback ->
        if Module.defines?(module, callback) do
          raise Spark.Error.DslError,
            module: module,
            path: [:backpex],
            message: replaced_callback_message(dsl_state, module, callback)
        end
      end)
    end
  end

  defp replaced_callback_message(dsl_state, module, {name, arity} = callback) do
    signature = "#{name}/#{arity}"
    resource = Spark.Dsl.Transformer.get_option(dsl_state, [:backpex], :resource)

    """
    #{inspect(module)} defines #{signature}#{definition_location(dsl_state, module, callback)},
    but AshBackpex generates #{signature} for every LiveResource.

    Prior to AshBackpex 0.3.0, this would not throw a compiler error.
    Instead, the custom function was silently overridden by the generated
    `#{signature}` AshBackpex function. Since this could cause unexpected
    #{replaced_callback_behavior(name)} behavior, it is now treated as a compiler error.

    #{replaced_callback_guidance(name, resource)}

      Then remove #{signature} from #{inspect(module)}.
    """
    |> indent_continuation_lines()
  end

  # Spark indents the first line of a DSL error message; indent the rest to match.
  defp indent_continuation_lines(message) do
    message
    |> String.trim_trailing()
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> "  " <> line
    end)
    |> String.trim_leading()
  end

  defp definition_location(dsl_state, module, callback) do
    file = Spark.Dsl.Transformer.get_persisted(dsl_state, :file)

    line =
      case Module.get_definition(module, callback) do
        {:v1, _kind, meta, [{clause_meta, _args, _guards, _body} | _clauses]} ->
          Keyword.get(meta, :line) || Keyword.get(clause_meta, :line)

        _definition ->
          nil
      end

    case {file, line} do
      {file, line} when is_binary(file) and is_integer(line) ->
        " (#{Path.relative_to_cwd(file)}:#{line})"

      _location ->
        ""
    end
  end

  defp replaced_callback_behavior(:can?), do: "authorization"
  defp replaced_callback_behavior(:fields), do: "field"
  defp replaced_callback_behavior(:filters), do: "filter"
  defp replaced_callback_behavior(:item_actions), do: "item action"
  defp replaced_callback_behavior(:layout), do: "layout"

  defp replaced_callback_guidance(:can?, resource) do
    """
      To fix it, if the rule turns creating, editing, or deleting off in this
      admin for everyone, set `create_action false`, `update_action false`, or
      `destroy_action false` in the `backpex` block. The generated can?/3 then
      denies :new, :edit, or :delete without consulting Ash.

      Otherwise, express the rule as Ash policies on #{inspect(resource)}.
      The generated can?/3 checks them with Ash.can?/2, using assigns.current_user
      as the actor:

        :new            -> the create action
        :index, :show   -> the read action
        :edit           -> the update action
        :delete         -> the destroy action
        other keys      -> the Ash action with the same name, if one exists
                           (custom item and resource actions without one are allowed)\
    """
  end

  defp replaced_callback_guidance(:fields, _resource) do
    """
      To fix it, declare fields in the `fields` section of the `backpex` block:

        fields do
          field :title
        end\
    """
  end

  defp replaced_callback_guidance(:filters, _resource) do
    """
      To fix it, declare filters in the `filters` section of the `backpex` block:

        filters do
          filter :published
        end\
    """
  end

  defp replaced_callback_guidance(:item_actions, _resource) do
    """
      To fix it, configure item actions in the `item_actions` section of the
      `backpex` block:

        item_actions do
          action :publish, MyAppWeb.ItemActions.Publish
          strip_default [:delete]
        end\
    """
  end

  defp replaced_callback_guidance(:layout, _resource) do
    """
      To fix it, set the `layout` option in the `backpex` block. It accepts a
      {module, function} tuple or a function that receives the assigns:

        layout {MyAppWeb.Layouts, :admin}\
    """
  end
end
