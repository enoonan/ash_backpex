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
  - **Error Handling** - Ash changeset errors are converted to Phoenix form errors
  - **Nested Forms** - Supports both single (cardinality one) and multiple (cardinality many) nested forms
  - **Data Binding** - Values are sourced from params, then changeset changes, then original data

  ## Value Resolution

  When a form field requests a value, this implementation looks in order:

  1. Form params (user input from the current request)
  2. Changeset arguments (for action arguments)
  3. Changeset attribute changes
  4. Original changeset data

  ## Error Conversion

  Ash errors are converted to Phoenix form error tuples `{field, message}`:

  - Errors with a `:field` key use that field
  - Errors with a `:fields` list use the first field
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
    id = Keyword.get(opts, :id) || name

    unless is_binary(id) or is_nil(id) do
      raise ArgumentError, ":id option in form_for must be a binary/string, got: #{inspect(id)}"
    end

    # Use changeset errors plus any additional errors passed in
    all_errors = changeset_errors_to_form_errors(changeset) ++ List.wrap(errors)

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
    {default, opts} = Keyword.pop(opts, :default, %{})
    {prepend, opts} = Keyword.pop(opts, :prepend, [])
    {append, opts} = Keyword.pop(opts, :append, [])
    {name, opts} = Keyword.pop(opts, :as)
    {id, opts} = Keyword.pop(opts, :id)
    {hidden, opts} = Keyword.pop(opts, :hidden, [])
    {action, opts} = Keyword.pop(opts, :action, form.action)

    id = to_string(id || form.id <> "_#{field}")
    name = to_string(name || form.name <> "[#{field}]")

    field_string = field_to_string(field)
    params = get_in(form.params, [field_string])

    cond do
      # cardinality: one
      is_map(default) ->
        [
          %Phoenix.HTML.Form{
            source: changeset,
            impl: __MODULE__,
            id: id,
            name: name,
            data: default,
            action: action,
            params: params || %{},
            hidden: hidden,
            options: opts
          }
        ]

      # cardinality: many
      is_list(default) ->
        entries =
          if params do
            params
            |> Enum.sort_by(&elem(&1, 0))
            |> Enum.map(&{nil, elem(&1, 1)})
          else
            Enum.map(prepend ++ default ++ append, &{&1, %{}})
          end

        for {{data, params}, index} <- Enum.with_index(entries) do
          index_string = Integer.to_string(index)

          %Phoenix.HTML.Form{
            source: changeset,
            impl: __MODULE__,
            index: index,
            action: action,
            id: id <> "_" <> index_string,
            name: name <> "[" <> index_string <> "]",
            data: data,
            params: params,
            hidden: hidden,
            options: opts
          }
        end
    end
  end

  def input_value(changeset, %{data: data, params: params}, field)
      when is_atom(field) or is_binary(field) do
    key = field_to_string(field)

    case params do
      %{^key => value} ->
        value

      %{} ->
        # Try to get the value from changeset first, then fall back to data
        case get_changeset_value(changeset, field) do
          nil -> Map.get(data, field)
          value -> value
        end
    end
  end

  def input_validations(_changeset, _form, _field) do
    # Return empty list for now - could be enhanced to return HTML5 validations
    # based on Ash resource attribute constraints
    []
  end

  # Private helper functions

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

  defp changeset_errors_to_form_errors(changeset) do
    Enum.map(changeset.errors, &ash_error_to_form_error/1)
  end

  defp ash_error_to_form_error(%{field: field} = err) when not is_nil(field) do
    {field, Exception.message(err)}
  end

  defp ash_error_to_form_error(%{fields: [field | _], message: message}) do
    {field, message}
  end

  defp ash_error_to_form_error(%{fields: fields, message: message})
       when is_list(fields) and fields != [] do
    {hd(fields), message}
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

  # Normalize field name to string version
  defp field_to_string(field) when is_atom(field), do: Atom.to_string(field)
  defp field_to_string(field) when is_binary(field), do: field
end
