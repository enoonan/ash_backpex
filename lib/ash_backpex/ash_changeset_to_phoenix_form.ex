defimpl Phoenix.HTML.FormData, for: Ash.Changeset do
  @moduledoc """
  Implementation of `Phoenix.HTML.FormData` protocol for `Ash.Changeset`.

  This protocol implementation allows Ash changesets to be used directly with
  Phoenix forms and Backpex's form rendering. It bridges Ash's changeset system
  with Phoenix's form handling, enabling seamless integration in the admin interface.

  ## What This Enables

  With this implementation, you can use Ash changesets directly in Phoenix forms:

  ```heex
  <.form for={@changeset} phx-submit="save">
    <.input field={@form[:title]} label="Title" />
    <.input field={@form[:content]} label="Content" />
  </.form>
  ```

  ## Features

  - **Attribute Access** - Form inputs can read from changeset attributes
  - **Argument Access** - Form inputs can read from action arguments
  - **Error Handling** - Ash changeset errors are converted to path-aware Phoenix form errors
  - **Nested Forms** - Recursively supports both singular and repeated resource forms
  - **Data Binding** - Values are sourced from params, then changeset changes, then original data

  ## Value Resolution

  When a form field requests a value, this implementation looks in order:

  1. Form params (user input from the current request)
  2. Changeset arguments (for action arguments)
  3. Changeset attribute changes
  4. Original changeset data

  ## Error Conversion

  Ash errors are converted to Phoenix form error tuples `{field, message}`:

  - Errors with a `:field` key use that field on the form matching the error path
  - Errors with a `:fields` list use the first field
  - Embedded errors retain their repeated-row index and singular-resource path
  - Other errors are assigned to the `:base` field

  ## Automatic Usage

  This implementation is loaded automatically when you use AshBackpex. You don't
  need to configure anything - the adapter uses Ash changesets internally and
  this protocol makes them work with Phoenix/Backpex forms.
  """

  def to_form(changeset, opts) do
    {name, _params, opts} = name_params_and_opts(changeset, opts)
    {errors, opts} = Keyword.pop(opts, :errors, [])
    {action, opts} = Keyword.pop(opts, :action, nil)
    opts = put_form_context(opts, changeset.resource, [])
    id = Keyword.get(opts, :id) || name

    if not is_binary(id) and not is_nil(id) do
      raise ArgumentError, ":id option in form_for must be a binary/string, got: #{inspect(id)}"
    end

    # Use changeset errors plus any additional errors passed in
    all_errors = changeset_errors_to_form_errors(changeset, []) ++ List.wrap(errors)

    %Phoenix.HTML.Form{
      source: changeset,
      impl: __MODULE__,
      id: id,
      name: name,
      params: build_params(changeset),
      data: changeset.data || %{},
      errors: all_errors,
      action: action,
      options: opts
    }
  end

  def to_form(changeset, form, field, opts) when is_atom(field) or is_binary(field) do
    current_resource = form_resource(form, changeset.resource)
    nested_field = nested_field(current_resource, field)

    {default, opts} =
      Keyword.pop_lazy(opts, :default, fn ->
        nested_default(changeset, form, field, nested_field)
      end)

    {prepend, opts} = Keyword.pop(opts, :prepend, [])
    {append, opts} = Keyword.pop(opts, :append, [])
    {name, opts} = Keyword.pop(opts, :as)
    {id, opts} = Keyword.pop(opts, :id)
    {hidden, opts} = Keyword.pop(opts, :hidden, [])
    {action, opts} = Keyword.pop(opts, :action, form.action)

    id = to_string(id || form.id <> "_#{field}")
    name = to_string(name || form.name <> "[#{field}]")
    field_path = form_path(form) ++ [nested_field.name]
    opts = put_form_context(opts, nested_field.resource, field_path)
    params = fetch_form_value(form.params, field)

    case nested_field.cardinality do
      :one ->
        params = singular_params(params)
        data = singular_data(default)

        [
          %Phoenix.HTML.Form{
            source: changeset,
            impl: __MODULE__,
            id: id,
            name: name,
            data: data,
            action: action,
            params: params,
            hidden: merge_hidden(nested_field.resource, data, params, hidden),
            errors: changeset_errors_to_form_errors(changeset, field_path),
            options: opts
          }
        ]

      :many ->
        entries = nested_entries(params, prepend ++ repeated_data(default) ++ append)

        for {{data, params}, index} <- Enum.with_index(entries) do
          index_string = Integer.to_string(index)
          row_path = field_path ++ [index]

          %Phoenix.HTML.Form{
            source: changeset,
            impl: __MODULE__,
            index: index,
            action: action,
            id: id <> "_" <> index_string,
            name: name <> "[" <> index_string <> "]",
            data: data,
            params: params,
            hidden: merge_hidden(nested_field.resource, data, params, hidden),
            errors: changeset_errors_to_form_errors(changeset, row_path),
            options: put_form_context(opts, nested_field.resource, row_path)
          }
        end
    end
  end

  def input_value(changeset, %{data: data, params: params} = form, field)
      when is_atom(field) or is_binary(field) do
    case fetch_form_value(params, field) do
      {:ok, value} ->
        value

      :error ->
        if nested_form?(form) do
          get_data_value(data, field)
        else
          case get_changeset_value(changeset, field) do
            nil -> get_data_value(data, field)
            value -> value
          end
        end
    end
  end

  def input_validations(_changeset, _form, _field) do
    # Return empty list for now - could be enhanced to return HTML5 validations
    # based on Ash resource attribute constraints
    []
  end

  # Private helper functions

  defp put_form_context(opts, resource, path) do
    opts
    |> Keyword.put(:ash_resource, resource)
    |> Keyword.put(:ash_form_path, path)
  end

  defp nested_field(resource, field) do
    field = resource_field(resource, field)

    case Ash.Resource.Info.relationship(resource, field) do
      %{cardinality: cardinality, destination: destination} ->
        %{name: field, cardinality: cardinality, resource: destination}

      nil ->
        nested_attribute(resource, field)
    end
  end

  defp nested_attribute(resource, field) do
    case Ash.Resource.Info.attribute(resource, field) do
      %{type: {:array, type}} ->
        %{name: field, cardinality: :many, resource: nested_resource(type, resource)}

      %{type: type} ->
        %{name: field, cardinality: :one, resource: nested_resource(type, resource)}

      nil ->
        %{name: field, cardinality: :one, resource: resource}
    end
  end

  defp nested_resource(resource, fallback) do
    if Ash.Resource.Info.resource?(resource), do: resource, else: fallback
  end

  defp nested_entries({:ok, params}, _default), do: repeated_params(params)
  defp nested_entries(:error, default), do: Enum.map(default, &{&1, %{}})

  defp repeated_params(params) when is_list(params), do: Enum.map(params, &{nil, form_params(&1)})

  defp repeated_params(params) when is_map(params) do
    params
    |> Enum.sort_by(fn {key, _value} -> param_sort_key(key) end)
    |> Enum.map(fn {_key, value} -> {nil, form_params(value)} end)
  end

  defp repeated_params(_params), do: []

  defp param_sort_key(key) when is_integer(key), do: {0, key}

  defp param_sort_key(key) when is_binary(key) do
    case Integer.parse(key) do
      {index, ""} -> {0, index}
      _other -> {1, key}
    end
  end

  defp param_sort_key(key), do: {1, inspect(key)}

  defp singular_params({:ok, params}), do: form_params(params)
  defp singular_params(:error), do: %{}

  defp form_params(params) when is_map(params), do: params
  defp form_params(_params), do: %{}

  defp singular_data(value) when is_map(value) and not is_struct(value, Ash.NotLoaded), do: value
  defp singular_data(_value), do: %{}

  defp repeated_data(value) when is_list(value), do: value
  defp repeated_data(_value), do: []

  defp merge_hidden(resource, data, params, hidden) do
    Enum.reduce(Ash.Resource.Info.primary_key(resource), hidden, fn key, hidden ->
      value = get_data_value(data, key) || get_data_value(params, key)

      if is_nil(value), do: hidden, else: Keyword.put_new(hidden, key, value)
    end)
  end

  defp nested_default(changeset, form, field, nested_field) do
    value =
      if nested_form?(form) do
        get_data_value(form.data, field)
      else
        get_changeset_value(changeset, field)
      end

    case nested_field.cardinality do
      :many when is_nil(value) or is_struct(value, Ash.NotLoaded) -> []
      :many -> value
      :one when is_nil(value) or is_struct(value, Ash.NotLoaded) -> %{}
      :one -> value
    end
  end

  defp form_resource(form, fallback), do: Keyword.get(form.options, :ash_resource, fallback)
  defp form_path(form), do: Keyword.get(form.options, :ash_form_path, [])

  defp nested_form?(%{index: index}) when not is_nil(index), do: true
  defp nested_form?(form), do: form_path(form) != []

  defp resource_field(_resource, field) when is_atom(field), do: field

  defp resource_field(resource, field) when is_binary(field) do
    Enum.find_value(Ash.Resource.Info.fields(resource), field, fn resource_field ->
      if to_string(resource_field.name) == field, do: resource_field.name
    end)
  end

  defp fetch_form_value(map, field) when is_map(map) do
    string_field = field_to_string(field)

    case Map.fetch(map, string_field) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(map, field)
    end
  end

  defp fetch_form_value(_map, _field), do: :error

  defp get_data_value(data, field) when is_map(data) do
    case fetch_form_value(data, field) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  defp get_data_value(_data, _field), do: nil

  defp name_params_and_opts(changeset, opts) do
    case Keyword.pop(opts, :as) do
      {nil, opts} ->
        # Default form name based on resource name
        default_name =
          changeset.resource
          |> Module.split()
          |> List.last()
          |> Macro.underscore()

        {default_name, build_params(changeset), opts}

      {name, opts} ->
        {to_string(name), build_params(changeset), opts}
    end
  end

  defp build_params(changeset) do
    # Combine changeset params with current attribute and argument values
    base_params = changeset.params || %{}

    # Add current attribute values
    attribute_params =
      changeset.attributes
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)

    # Add current argument values
    argument_params =
      changeset.arguments
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)

    # Merge with changeset params taking precedence
    Map.merge(Map.merge(attribute_params, argument_params), base_params)
  end

  defp get_changeset_value(changeset, field) when is_atom(field) do
    # Try to get from arguments first, then attributes, then data
    case Ash.Changeset.fetch_argument(changeset, field) do
      {:ok, value} ->
        value

      :error ->
        case Ash.Changeset.fetch_change(changeset, field) do
          {:ok, value} -> value
          :error -> Ash.Changeset.get_data(changeset, field)
        end
    end
  end

  defp get_changeset_value(changeset, field) when is_binary(field) do
    field_atom = String.to_existing_atom(field)
    get_changeset_value(changeset, field_atom)
  rescue
    ArgumentError -> nil
  end

  defp changeset_errors_to_form_errors(changeset, path) do
    changeset.errors
    |> Enum.filter(&same_path?(error_path(&1), path))
    |> Enum.map(&ash_error_to_form_error/1)
  end

  defp error_path(error), do: List.wrap(Map.get(error, :path, []))

  defp same_path?(left, right) when length(left) == length(right) do
    Enum.zip(left, right)
    |> Enum.all?(fn
      {left, right} when is_integer(left) or is_integer(right) -> left == right
      {left, right} -> to_string(left) == to_string(right)
    end)
  end

  defp same_path?(_left, _right), do: false

  defp ash_error_to_form_error(%{field: field} = err) when not is_nil(field) do
    {field, Exception.message(err)}
  end

  defp ash_error_to_form_error(%{fields: [field | _], message: message}) do
    {field, message}
  end

  defp ash_error_to_form_error(%{field: nil, value: value} = error) when is_list(value) do
    if Keyword.keyword?(value) and Keyword.has_key?(value, :field) do
      field = Keyword.fetch!(value, :field)
      message = Keyword.get(value, :message, Exception.message(error))
      {field, interpolate_error_message(message, value)}
    else
      {:base, Exception.message(error)}
    end
  end

  defp ash_error_to_form_error(%{message: message}) do
    {:base, message}
  end

  defp ash_error_to_form_error(error) when is_binary(error) do
    {:base, error}
  end

  defp ash_error_to_form_error(error) do
    # Fallback for any other error format
    {:base, inspect(error)}
  end

  defp interpolate_error_message(message, vars) do
    Regex.replace(~r/%\{([^}]+)\}/, message, fn placeholder, key ->
      case Enum.find(vars, fn {var, _value} -> to_string(var) == key end) do
        {_var, value} -> to_string(value)
        nil -> placeholder
      end
    end)
  end

  # Normalize field name to string version
  defp field_to_string(field) when is_atom(field), do: Atom.to_string(field)
  defp field_to_string(field) when is_binary(field), do: field
end
