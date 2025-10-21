defmodule AshBackpex.LoadSelectResolver do
  @moduledoc """
     Translates and validates user-provided list of fields for a given Ash resource into Backpex-compatible loads and selects.
  """

  alias Ash.Resource.Info
  @type load() :: atom()
  @type select() :: atom()
  @type field_list() :: keyword()

  @doc """
    Given an `Ash.Resource.t()` and a keyword list of Backpex field configurations, return a tuple of loads and selects.
  """
  @spec resolve(Ash.Resource.t(), field_list()) :: {list(load()), list(select())}
  def resolve(resource, fields) do
    fields
    |> Keyword.keys()
    |> Enum.reduce(%{load: [], select: []}, fn field, acc ->
      cond do
        att?(resource, field) ->
          acc |> Map.update(:select, [field], &(&1 ++ [field]))

        load?(resource, field) ->
          acc |> Map.update(:load, [field], &(&1 ++ [field]))

        true ->
          raise "Unrecognized field. #{field |> inspect} is not a known attribute, relationship, calculation, or aggregate on #{resource |> inspect}"
      end
    end)
    |> then(fn map -> {map.load, map.select} end)
  end

  defp att?(resource, field) do
    !is_nil(Info.attribute(resource, field))
  end

  defp load?(resource, field) do
    Enum.any?(
      [
        Info.relationship(resource, field),
        Info.calculation(resource, field),
        Info.aggregate(resource, field)
      ],
      &(!is_nil(&1))
    )
  end
end
