defmodule AshBackpex.LoadSelectResolver do
  @moduledoc """
  Resolves which Ash loads and selects are needed for a given set of Backpex fields.

  This module analyzes the fields configured in an AshBackpex LiveResource and
  determines which ones are:

  - **Attributes** - Added to the `select` list for efficient querying
  - **Relationships, Calculations, or Aggregates** - Added to the `load` list

  This separation allows the adapter to build efficient Ash queries that only
  fetch the data actually needed for the admin interface.

  ## How It Works

  The resolver examines each field name against the Ash resource schema:

  1. If the field is an attribute → add to `select`
  2. If the field is a relationship, calculation, or aggregate → add to `load`
  3. If the field doesn't exist on the resource → raise an error

  ## Usage

  This module is called internally by `AshBackpex.Adapter` to build queries.
  You typically don't need to use it directly, but it can be useful for
  debugging or custom adapter implementations:

  ```elixir
  fields = [
    title: %{module: Backpex.Fields.Text},
    author: %{module: Backpex.Fields.BelongsTo},
    word_count: %{module: Backpex.Fields.Number}
  ]

  {loads, selects} = AshBackpex.LoadSelectResolver.resolve(MyApp.Blog.Post, fields)
  # loads => [:author, :word_count]
  # selects => [:title]
  ```
  """

  alias Ash.Resource.Info
  @type load() :: atom()
  @type select() :: atom()
  @type field_list() :: keyword()

  @doc """
  Resolves field configurations into Ash loads and selects.

  Given an Ash resource module and a keyword list of Backpex field configurations,
  returns a tuple of `{loads, selects}` where:

  - `loads` - List of relationships, calculations, and aggregates to load
  - `selects` - List of attributes to select

  ## Parameters

  - `resource` - An `Ash.Resource` module
  - `fields` - Keyword list of field configurations (field name → config map)

  ## Returns

  A tuple `{loads, selects}` where both are lists of atoms.

  ## Raises

  Raises an error if a field name doesn't correspond to any attribute,
  relationship, calculation, or aggregate on the resource.

  ## Examples

      iex> fields = [title: %{}, author: %{}, word_count: %{}]
      iex> AshBackpex.LoadSelectResolver.resolve(MyApp.Post, fields)
      {[:author, :word_count], [:title]}
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
