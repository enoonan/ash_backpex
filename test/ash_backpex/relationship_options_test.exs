defmodule AshBackpex.RelationshipOptionsTest do
  use AshBackpex.DataCase, async: false

  alias AshBackpex.TestDomain.ManyToManyCategory

  test "derived relationship options_query applies relationship filters and sorts" do
    insert_category!("assignable-beta", "Beta", "assignable")
    insert_category!("internal-alpha", "Alpha", "internal")
    insert_category!("assignable-alpha", "Alpha", "assignable")

    options_query = TestManyToManyLive.fields()[:categories].options_query

    categories =
      ManyToManyCategory
      |> from()
      |> options_query.(%{})
      |> TestRepo.all()

    assert Enum.map(categories, & &1.id) == ["assignable-alpha", "assignable-beta"]
  end

  test "derived relationship options_query accepts aliased Backpex option queries" do
    insert_category!("assignable-beta", "Beta", "assignable")
    insert_category!("internal-alpha", "Alpha", "internal")

    options_query = TestManyToManyLive.fields()[:categories].options_query

    categories =
      ManyToManyCategory
      |> from(as: :tag)
      |> options_query.(%{})
      |> TestRepo.all()

    assert Enum.map(categories, & &1.id) == ["assignable-beta"]
  end

  defp insert_category!(id, name, type) do
    Ecto.Adapters.SQL.query!(
      TestRepo,
      """
      INSERT INTO many_to_many_categories (id, name, type)
      VALUES (?, ?, ?)
      """,
      [id, name, type]
    )
  end
end
