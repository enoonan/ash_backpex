defmodule DemoWeb.CoreComponents do
  use Phoenix.Component

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, _opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    msg
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Translates Backpex messages.
  """
  def translate_backpex(message) do
    case message do
      {:placeholder, _key} ->
        "Select..."

      {str, assigns} when is_binary(str) and is_map(assigns) ->
        # Generic handler for any string with assigns
        Enum.reduce(assigns, str, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)

      str when is_binary(str) ->
        str

      _ ->
        inspect(message)
    end
  end
end
