defmodule AshBackpex.TestTranslator do
  @moduledoc """
  Backpex translator functions for the test suite.

  They interpolate `%{key}` placeholders the way Backpex's fallback translator
  does. Configuring them keeps Backpex from warning on every translation.
  """

  def translate({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
