defmodule AshBackpex.LiveResource.Transformers.GenerateBackpex do
  @moduledoc """
    Generates a Backpex.LiveResource based on the the `backpex` DSL configuration provided in files that `use AshBackpex.LiveResource`.
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

        try_derive_module = fn attribute_name ->
          type = derive_type.(attribute_name)

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
              AshBackpex.Fields.BelongsTo

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
                   Keyword.put(
                     acc,
                     filter.attribute,
                     %{
                       module: filter.module,
                       label: filter.label || filter.attribute |> atom_to_title_case.()
                     }
                   )
                 end)

        @item_actions Spark.Dsl.Extension.get_entities(__MODULE__, [:backpex, :item_actions])
                      |> Enum.reduce([], fn action, acc ->
                        Keyword.put(
                          acc,
                          action.name,
                          %{
                            module: action.module
                          }
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
              layout: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :layout),
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
                    end,
                  init_order: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :init_order)
                ]
                |> Keyword.reject(&(&1 |> elem(1) |> is_nil)),
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
