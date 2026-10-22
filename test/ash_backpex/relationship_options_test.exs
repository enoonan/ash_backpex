defmodule AshBackpex.RelationshipOptionsTest do
  use AshBackpex.DataCase, async: false

  import TestGenerators

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

  # Backpex's HasMany search filters the options query through the alias it gave the root.
  test "derived relationship options_query keeps the Backpex alias for searching" do
    insert_category!("assignable-beta", "Beta", "assignable")
    insert_category!("assignable-gamma", "Gamma", "assignable")
    insert_category!("internal-beta", "Beta", "internal")

    options_query = TestManyToManyLive.fields()[:categories].options_query

    categories =
      ManyToManyCategory
      |> from(as: :tag)
      |> options_query.(%{})
      |> where([tag: tag], like(tag.name, ^"%Bet%"))
      |> TestRepo.all()

    assert Enum.map(categories, & &1.id) == ["assignable-beta"]
  end

  test "derived relationship options_query enforces Ash read policies" do
    actor = user()
    other_user = user()
    own_post = post(actor: actor, title: "Authorized", published: true)
    post(actor: actor, title: "Unpublished", published: false)
    post(actor: other_user, title: "Other user's", published: true)

    options_query = TestAuthorizedRelationshipLive.fields()[:published_posts].options_query

    posts =
      AshBackpex.TestDomain.Post
      |> from()
      |> options_query.(%{current_user: actor})
      |> TestRepo.all()

    assert Enum.map(posts, & &1.id) == [own_post.id]
  end

  # Reading every authorized record to restrict by id times out on large tables, so the policy
  # filter is part of the query and records created after it is built still match.
  test "derived relationship options_query filters by policy instead of reading records" do
    actor = user()
    options_query = TestAuthorizedRelationshipLive.fields()[:published_posts].options_query

    query =
      AshBackpex.TestDomain.Post
      |> from()
      |> options_query.(%{current_user: actor})

    later_post = post(actor: actor, title: "Created later", published: true)
    post(actor: user(), title: "Other user's", published: true)

    assert Enum.map(TestRepo.all(query), & &1.id) == [later_post.id]
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
