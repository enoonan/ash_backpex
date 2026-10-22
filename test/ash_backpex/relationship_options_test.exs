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

  test "derived relationship options_query only offers the tenant's records" do
    insert_label!("Alpha", "org-a")
    insert_label!("Beta", "org-b")
    insert_label!("Gamma", "org-a")

    options_query = TestBoardLive.fields()[:labels].options_query

    labels =
      AshBackpex.TestDomain.TenantLabel
      |> from()
      |> options_query.(%{tenant: "org-a"})
      |> TestRepo.all()

    assert Enum.map(labels, & &1.name) == ["Alpha", "Gamma"]
  end

  test "derived relationship options_query requires a tenant for multitenant destinations" do
    options_query = TestBoardLive.fields()[:labels].options_query

    assert_raise ArgumentError, ~r/tenant/i, fn ->
      AshBackpex.TestDomain.TenantLabel
      |> from()
      |> options_query.(%{})
    end
  end

  # Without an authorizer the options are never read through Ash.read, which applies the tenant.
  test "derived relationship options_query only offers the tenant's records without policies" do
    insert_note!("Alpha", "org-a")
    insert_note!("Beta", "org-b")

    options_query = TestBoardLive.fields()[:notes].options_query

    notes =
      AshBackpex.TestDomain.TenantNote
      |> from()
      |> options_query.(%{tenant: "org-a"})
      |> TestRepo.all()

    assert Enum.map(notes, & &1.name) == ["Alpha"]
  end

  test "derived relationship options_query requires a tenant without policies" do
    options_query = TestBoardLive.fields()[:notes].options_query

    assert_raise ArgumentError, ~r/tenant/i, fn ->
      AshBackpex.TestDomain.TenantNote
      |> from()
      |> options_query.(%{})
    end
  end

  # Ash cannot express this policy as a filter, so the options come from an authorized read.
  test "derived relationship options_query matches Ash reads for runtime policy checks" do
    actor = user()
    insert_badge!("Alpha")
    insert_badge!("Beta")
    insert_badge!("Apex")

    options_query = TestBoardLive.fields()[:badges].options_query

    badges =
      AshBackpex.TestDomain.RuntimeCheckedBadge
      |> from()
      |> options_query.(%{current_user: actor})
      |> TestRepo.all()

    authorized =
      AshBackpex.TestDomain.RuntimeCheckedBadge
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(actor: actor)

    assert Enum.map(badges, & &1.name) == Enum.map(authorized, & &1.name)
  end

  defp insert_label!(name, org) do
    Ecto.Adapters.SQL.query!(
      TestRepo,
      "INSERT INTO tenant_labels (id, name, org) VALUES (?, ?, ?)",
      [Ecto.UUID.generate(), name, org]
    )
  end

  defp insert_note!(name, org) do
    Ecto.Adapters.SQL.query!(
      TestRepo,
      "INSERT INTO tenant_notes (id, name, org) VALUES (?, ?, ?)",
      [Ecto.UUID.generate(), name, org]
    )
  end

  defp insert_badge!(name) do
    Ecto.Adapters.SQL.query!(
      TestRepo,
      "INSERT INTO runtime_checked_badges (id, name) VALUES (?, ?)",
      [Ecto.UUID.generate(), name]
    )
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
