if Code.ensure_loaded?(Phoenix.HTML) do
  defimpl Phoenix.HTML.FormData, for: Ash.Changeset do
    def to_form(changeset, opts) do
      %{data: data, action: action} = changeset
      {action, opts} = Keyword.pop(opts, :action, action)
      {name, opts} = Keyword.pop(opts, :as)

      name = to_string(name || form_for_name(data))
      id = Keyword.get(opts, :id) || name

      %Phoenix.HTML.Form{
        source: changeset,
        impl: __MODULE__,
        id: id,
        action: action,
        name: name,
        errors: form_for_errors(changeset, action),
        data: data,
        params: changeset.params || %{},
        hidden: form_for_hidden(data),
        options: Keyword.put_new(opts, :method, form_for_method(data))
      }
    end

    def to_form(source, %{action: parent_action} = form, field, opts) do
      if Keyword.has_key?(opts, :default) do
        raise ArgumentError,
              ":default is not supported on inputs_for with changesets. " <>
                "The default value must be set in the changeset data"
      end

      {prepend, opts} = Keyword.pop(opts, :prepend, [])
      {append, opts} = Keyword.pop(opts, :append, [])
      {name, opts} = Keyword.pop(opts, :as)
      {id, opts} = Keyword.pop(opts, :id)

      id = to_string(id || form.id <> "_#{field}")
      name = to_string(name || form.name <> "[#{field}]")

      case find_inputs_for_type!(source, field) do
        {:one, cast, module} ->
          changesets =
            case Map.fetch(source.relationships, field) do
              {:ok, nil} ->
                []

              {:ok, map} ->
                [validate_map!(map, field)]

              _ ->
                [validate_map!(assoc_from_data(source.data, field), field) || module.__struct__()]
            end

          for changeset <- skip_replaced(changesets) do
            %{data: data, params: params} =
              changeset = to_changeset(changeset, parent_action, module, cast, nil)

            %Phoenix.HTML.Form{
              source: changeset,
              action: parent_action,
              impl: __MODULE__,
              id: id,
              name: name,
              errors: form_for_errors(changeset, parent_action),
              data: data,
              params: params || %{},
              hidden: form_for_hidden(data),
              options: opts
            }
          end

        {:many, cast, module} ->
          changesets =
            validate_list!(Map.get(source.relationships, field), field) ||
              validate_list!(assoc_from_data(source.data, field), field) || []

          changesets =
            if form.params[Atom.to_string(field)] do
              changesets
            else
              prepend ++ changesets ++ append
            end

          changesets = skip_replaced(changesets)

          for {changeset, index} <- Enum.with_index(changesets) do
            %{data: data, params: params} =
              changeset = to_changeset(changeset, parent_action, module, cast, index)

            index_string = Integer.to_string(index)

            %Phoenix.HTML.Form{
              source: changeset,
              impl: __MODULE__,
              action: parent_action,
              id: id <> "_" <> index_string,
              name: name <> "[" <> index_string <> "]",
              index: index,
              errors: form_for_errors(changeset, parent_action),
              data: data,
              params: params || %{},
              hidden: form_for_hidden(data),
              options: opts
            }
          end
      end
    end

    def input_value(%{attributes: attributes, data: data}, %{params: params}, field)
        when is_atom(field) do
      case attributes do
        %{^field => value} ->
          value

        %{} ->
          string = Atom.to_string(field)

          case params do
            %{^string => value} -> value
            %{} -> Map.get(data, field)
          end
      end
    end

    def input_value(_data, _form, field) do
      raise ArgumentError, "expected field to be an atom, got: #{inspect(field)}"
    end

    def input_type(changeset, _, field) do
      # Get attribute type from the resource schema
      resource = changeset.resource

      if function_exported?(resource, :__ash_attributes__, 0) do
        attribute = Enum.find(resource.__ash_attributes__(), &(&1.name == field))

        case attribute && attribute.type do
          :integer ->
            :number_input

          :boolean ->
            :checkbox

          :date ->
            :date_select

          :time ->
            :time_select

          :utc_datetime ->
            :datetime_select

          :naive_datetime ->
            :datetime_select

          Ash.Type.Integer ->
            :number_input

          Ash.Type.Boolean ->
            :checkbox

          Ash.Type.Date ->
            :date_select

          Ash.Type.Time ->
            :time_select

          Ash.Type.UtcDatetime ->
            :datetime_select

          Ash.Type.NaiveDatetime ->
            :datetime_select

          # Handle custom types that implement a primitive type
          type when not is_nil(type) ->
            try do
              if function_exported?(type, :storage_type, 1) do
                case type.storage_type(attribute.constraints || []) do
                  :integer -> :number_input
                  :boolean -> :checkbox
                  :date -> :date_select
                  :time -> :time_select
                  :utc_datetime -> :datetime_select
                  :naive_datetime -> :datetime_select
                  _ -> :text_input
                end
              else
                :text_input
              end
            rescue
              _ -> :text_input
            end

          _ ->
            :text_input
        end
      else
        :text_input
      end
    end

    def input_validations(changeset, _, field) do
      # Extract validations from Ash changeset
      validations = extract_ash_validations(changeset, field)

      # Check if field is required
      required? = field_required?(changeset, field)

      [required: required?] ++ validations
    end

    # Private helper functions

    defp extract_ash_validations(changeset, field) do
      resource = changeset.resource

      # Get attribute definition to check constraints
      if function_exported?(resource, :__ash_attributes__, 0) do
        attribute = Enum.find(resource.__ash_attributes__(), &(&1.name == field))

        case attribute do
          nil -> []
          attr -> constraints_to_validations(attr.constraints || [], field, attr.type)
        end
      else
        []
      end
    end

    defp constraints_to_validations(constraints, _field, type) do
      Enum.flat_map(constraints, fn
        {:max_length, val} -> [maxlength: val]
        {:min_length, val} -> [minlength: val]
        {:max, val} when type in [:integer, Ash.Type.Integer] -> [max: val]
        {:min, val} when type in [:integer, Ash.Type.Integer] -> [min: val]
        {:greater_than, val} when type in [:integer, Ash.Type.Integer] -> [min: val + 1]
        {:greater_than_or_equal_to, val} when type in [:integer, Ash.Type.Integer] -> [min: val]
        {:less_than, val} when type in [:integer, Ash.Type.Integer] -> [max: val - 1]
        {:less_than_or_equal_to, val} when type in [:integer, Ash.Type.Integer] -> [max: val]
        _ -> []
      end) ++ type_specific_validations(type)
    end

    defp type_specific_validations(type) do
      case type do
        :integer -> [step: 1]
        Ash.Type.Integer -> [step: 1]
        _ -> [step: "any"]
      end
    end

    defp field_required?(changeset, field) do
      resource = changeset.resource
      action = changeset.action

      cond do
        # Check if the action exists and has required arguments/attributes
        action && function_exported?(resource, :__ash_actions__, 0) ->
          actions = resource.__ash_actions__()
          action_config = Enum.find(actions, &(&1.name == action.name && &1.type == action.type))

          case action_config do
            nil ->
              false

            config ->
              # Check if field is in action's required attributes
              required_attrs =
                Enum.filter(config.accept || [], fn attr_name ->
                  attr = Enum.find(resource.__ash_attributes__(), &(&1.name == attr_name))
                  attr && !attr.allow_nil?
                end)

              field in required_attrs
          end

        # Fallback: check attribute definition
        function_exported?(resource, :__ash_attributes__, 0) ->
          attribute = Enum.find(resource.__ash_attributes__(), &(&1.name == field))
          attribute && !attribute.allow_nil?

        true ->
          false
      end
    end

    defp assoc_from_data(data, field) do
      case Map.get(data, field) do
        %Ash.NotLoaded{} -> nil
        value -> value
      end
    end

    defp skip_replaced(changesets) do
      Enum.reject(changesets, fn
        %Ash.Changeset{action: %{type: :destroy}} -> true
        _ -> false
      end)
    end

    defp find_inputs_for_type!(changeset, field) do
      resource = changeset.resource

      if function_exported?(resource, :__ash_relationships__, 0) do
        relationship = Enum.find(resource.__ash_relationships__(), &(&1.name == field))

        case relationship do
          nil ->
            raise ArgumentError,
                  "could not generate inputs for #{inspect(field)} from #{inspect(resource)}. " <>
                    "Check the field exists and it is a relationship"

          %{cardinality: :one, destination: module} ->
            {:one, nil, module}

          %{cardinality: :many, destination: module} ->
            {:many, nil, module}
        end
      else
        raise ArgumentError,
              "could not generate inputs for #{inspect(field)} from #{inspect(resource)}. " <>
                "Resource does not define relationships"
      end
    end

    defp to_changeset(%Ash.Changeset{} = changeset, parent_action, _module, _cast, _index),
      do: apply_action(changeset, parent_action)

    # defp to_changeset(%{} = data, parent_action, _module, {module, func, arguments} = mfa, _index)
    #      when is_atom(module) and is_atom(func) and is_list(arguments),
    #      do: apply_action(apply!(mfa, data), parent_action)

    defp to_changeset(%{} = _data, parent_action, module, nil, _index),
      do: apply_action(Ash.Changeset.new(module), parent_action)

    # defp apply!({module, func, arguments}, data) do
    #   case apply(module, func, [data, %{} | arguments]) do
    #     %Ash.Changeset{} = changeset ->
    #       changeset

    #     other ->
    #       raise "expected #{module}.#{func} to return an Ash.Changeset, got: #{inspect(other)}"
    #   end
    # end

    # If the parent changeset had no action, we need to remove the action
    # from children changeset so we ignore all errors accordingly.
    defp apply_action(changeset, nil),
      do: %{changeset | action: nil}

    defp apply_action(changeset, _action),
      do: changeset

    defp validate_list!(value, _what) when is_list(value) or is_nil(value), do: value

    defp validate_list!(value, what) do
      raise ArgumentError, "expected #{what} to be a list, got: #{inspect(value)}"
    end

    defp validate_map!(value, _what) when is_map(value) or is_nil(value), do: value

    defp validate_map!(value, what) do
      raise ArgumentError, "expected #{what} to be a map/struct, got: #{inspect(value)}"
    end

    defp form_for_errors(_changeset, nil = _action), do: []
    defp form_for_errors(_changeset, :ignore = _action), do: []

    defp form_for_errors(%Ash.Changeset{errors: errors}, _action) do
      # Convert Ash errors to Phoenix form errors format
      Enum.map(errors, fn error ->
        case error do
          %{field: field, message: message} when not is_nil(field) ->
            {field, {message, []}}

          %{path: [field | _], message: message} when not is_nil(field) ->
            {field, {message, []}}

          %{message: message} ->
            {:base, {message, []}}

          _ ->
            {:base, {inspect(error), []}}
        end
      end)
    end

    defp form_for_hidden(%{__struct__: module} = data) do
      try do
        if function_exported?(module, :__ash_primary_key__, 0) do
          keys = module.__ash_primary_key__()
          for k <- keys, v = Map.get(data, k), do: {k, v}
        else
          []
        end
      rescue
        _ -> []
      end
    end

    defp form_for_hidden(_), do: []

    defp form_for_name(%{__struct__: module}) do
      module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
    end

    defp form_for_name(_) do
      raise ArgumentError,
            "cannot generate name for changeset where the data is not backed by a struct. " <>
              "You must either pass the :as option to form/form_for or use a struct-based changeset"
    end

    # Ash resources don't have the same concept of :loaded state like Ecto
    # We'll determine the method based on whether there's an ID present
    defp form_for_method(%{__struct__: module} = data) do
      try do
        if function_exported?(module, :__ash_primary_key__, 0) do
          primary_keys = module.__ash_primary_key__()
          has_id = Enum.any?(primary_keys, &Map.get(data, &1))
          if has_id, do: "put", else: "post"
        else
          "post"
        end
      rescue
        _ -> "post"
      end
    end

    defp form_for_method(_), do: "post"
  end
end
