defmodule AshBackpex.LoadSelectTest do
  use ExUnit.Case, async: true
  alias AshBackpex.LoadSelectResolver
  alias AshBackpex.TestDomain.Item

  describe "AshBackpex.LoadSelectResolver" do
    test "resolve_fields_and_loads/2 resolves all field types" do
      fields = [name: %{}, note: %{}, id: %{}, most_viewed: %{}, name_note: %{}, user: %{}]

      {load, select} = LoadSelectResolver.resolve(Item, fields)

      assert select === [:name, :note, :id]
      assert load === [:most_viewed, :name_note, :user]
    end
  end

  test "resolve_fields_and_loads/2 raises on unrecognized field" do
    fields = [foobar: %{}]

    msg =
      "Unrecognized field. :foobar is not a known attribute, relationship, calculation, or aggregate on AshBackpex.TestDomain.Item"

    assert_raise RuntimeError, msg, fn ->
      LoadSelectResolver.resolve(Item, fields)
    end
  end
end
