# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Demo.Blog.{Author, Comment, Post}

slugify = fn title ->
  title
  |> String.downcase()
  |> String.replace(~r/[^a-z0-9]+/u, "-")
  |> String.trim("-")
end

create! = fn resource, action, attrs ->
  resource
  |> Ash.Changeset.for_create(action, attrs)
  |> Ash.create!()
end

authors =
  [
    %{
      name: "Ada Lovelace",
      email: "ada@example.com",
      role: :admin,
      active: true,
      bio: "Writes the long-form architecture notes and keeps the admin tidy.",
      joined_on: ~D[2024-01-15]
    },
    %{
      name: "Grace Hopper",
      email: "grace@example.com",
      role: :editor,
      active: true,
      bio: "Turns rough drafts into crisp tutorials.",
      joined_on: ~D[2024-03-03]
    },
    %{
      name: "Katherine Johnson",
      email: "katherine@example.com",
      role: :contributor,
      active: false,
      bio: "Contributes occasional data-heavy walkthroughs.",
      joined_on: ~D[2023-11-20]
    }
  ]
  |> Enum.map(fn attrs -> create!.(Author, :create, attrs) end)

author_by_name = Map.new(authors, &{&1.name, &1})

posts =
  [
    %{
      title: "Getting Started with Ash Framework",
      content:
        "Ash is a declarative, resource-based framework for building Elixir applications. It provides a powerful DSL for defining your domain model and automatically generates APIs, queries, and mutations.",
      excerpt: "A first look at resource-driven Elixir apps.",
      status: :published,
      tags: [:ash, :tutorial],
      published: true,
      published_on: ~D[2026-01-10],
      featured: true,
      rating: 5,
      author: "Ada Lovelace"
    },
    %{
      title: "Understanding Backpex Admin Panels",
      content:
        "Backpex is a highly customizable admin panel for Phoenix LiveView applications. Combined with Ash, it provides a seamless way to manage your resources through an intuitive interface.",
      excerpt: "How the generated admin surfaces map to your resources.",
      status: :published,
      tags: [:backpex, :liveview],
      published: true,
      published_on: ~D[2026-02-04],
      featured: true,
      rating: 4,
      author: "Grace Hopper"
    },
    %{
      title: "SQLite for Development",
      content:
        "SQLite is an excellent choice for development and small-scale applications. It requires no separate server process and stores the entire database in a single file.",
      excerpt: "A practical local database setup for demos and tests.",
      status: :review,
      tags: [:sqlite, :tutorial],
      published: false,
      published_on: nil,
      featured: false,
      rating: 4,
      author: "Katherine Johnson"
    },
    %{
      title: "Phoenix LiveView Patterns",
      content:
        "LiveView enables rich, real-time user experiences with server-rendered HTML. Learn about common patterns like live navigation, form handling, and real-time updates.",
      excerpt: "Common patterns for responsive server-rendered interfaces.",
      status: :published,
      tags: [:liveview, :tutorial],
      published: true,
      published_on: ~D[2026-03-19],
      featured: false,
      rating: 5,
      author: "Grace Hopper"
    },
    %{
      title: "Draft: Upcoming Features",
      content:
        "This is a draft post about upcoming features we're planning to add. Stay tuned for more updates!",
      excerpt: "An intentionally unfinished article for filtering demos.",
      status: :draft,
      tags: [:ash, :backpex],
      published: false,
      published_on: nil,
      featured: false,
      rating: 3,
      author: "Ada Lovelace"
    },
    %{
      title: "Archived: Old Admin Prototype",
      content:
        "A short archive entry kept around to demonstrate enum filters and custom item actions.",
      excerpt: "An archived row for status filtering.",
      status: :archived,
      tags: [:backpex],
      published: false,
      published_on: ~D[2025-09-01],
      featured: false,
      rating: 2,
      author: "Katherine Johnson"
    }
  ]
  |> Enum.map(fn attrs ->
    {author_name, attrs} = Map.pop!(attrs, :author)

    attrs =
      attrs
      |> Map.put(:slug, slugify.(attrs.title))
      |> Map.put(:author_id, Map.fetch!(author_by_name, author_name).id)

    create!.(Post, :create, attrs)
  end)

post_by_title = Map.new(posts, &{&1.title, &1})

comments = [
  %{
    post: "Getting Started with Ash Framework",
    author: "Grace Hopper",
    body: "The resource/action framing clicked immediately.",
    sentiment: :positive,
    approved: true
  },
  %{
    post: "Understanding Backpex Admin Panels",
    author: "Ada Lovelace",
    body: "The relationship fields make the demo feel much closer to a real admin.",
    sentiment: :positive,
    approved: true
  },
  %{
    post: "SQLite for Development",
    author: "Grace Hopper",
    body: "Needs one more pass on migration caveats before publishing.",
    sentiment: :critical,
    approved: false
  },
  %{
    post: "Draft: Upcoming Features",
    author: "Katherine Johnson",
    body: "Good outline, but the examples need concrete code.",
    sentiment: :neutral,
    approved: false
  }
]

Enum.each(comments, fn attrs ->
  {post_title, attrs} = Map.pop!(attrs, :post)
  {author_name, attrs} = Map.pop!(attrs, :author)

  attrs =
    attrs
    |> Map.put(:post_id, Map.fetch!(post_by_title, post_title).id)
    |> Map.put(:author_id, Map.fetch!(author_by_name, author_name).id)

  create!.(Comment, :create, attrs)
end)

IO.puts(
  "Created #{length(authors)} authors, #{length(posts)} posts, and #{length(comments)} comments"
)
