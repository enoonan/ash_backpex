defmodule TestGenerators do
  @moduledoc false
  alias AshBackpex.TestDomain.{Post, User}

  def user(opts \\ []) do
    Ash.Seed.seed!(%User{
      name: "User #{System.unique_integer([:positive])}",
      email: "email_#{System.unique_integer([:positive])}@example.com",
      active: Keyword.get(opts, :active, true)
    })
  end

  def post(opts \\ []) do
    actor = Keyword.get(opts, :actor)

    Ash.Seed.seed!(%Post{
      title: Faker.Lorem.sentence(),
      content: Faker.Lorem.paragraphs(1..3) |> Enum.join(" "),
      view_count: Keyword.get(opts, :view_count, 0),
      published: Keyword.get(opts, :published, false),
      status: Keyword.get(opts, :status),
      author_id: actor.id
    })
  end
end
