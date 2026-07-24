# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Demo.Blog.{Author, Comment, Post, Tag}

require Ash.Query

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

create_or_update_author! = fn attrs ->
  case Author
       |> Ash.Query.filter(email: attrs.email)
       |> Ash.read!() do
    [] ->
      create!.(Author, :create, attrs)

    [author | _duplicates] ->
      author
      |> Ash.Changeset.for_update(:update, attrs)
      |> Ash.update!()
  end
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
  |> Enum.map(create_or_update_author!)

author_by_name = Map.new(authors, &{&1.name, &1})

tag_attrs = [
  %{
    name: "Ash",
    type: :topic,
    description: "Resource modeling, actions, policies, and Ash Framework patterns."
  },
  %{
    name: "Backpex",
    type: :topic,
    description: "Admin interfaces, fields, filters, and operational tooling."
  },
  %{
    name: "LiveView",
    type: :topic,
    description: "Phoenix LiveView interaction patterns and server-rendered UI."
  },
  %{
    name: "SQLite",
    type: :topic,
    description: "Small, local-first database workflows for demos and development."
  },
  %{
    name: "Beginners",
    type: :audience,
    description: "Introductory articles for readers learning the stack."
  },
  %{
    name: "Admins",
    type: :audience,
    description: "Operational guidance for people maintaining admin interfaces."
  },
  %{
    name: "Editors",
    type: :audience,
    description: "Publishing and workflow guidance for editorial users."
  }
]

# When migrating an existing demo database, the migration defaults existing tags to "topic".
# Normalize known demo tags so rerunning seeds gives the relationship filter POC useful data.
Enum.each(tag_attrs ++ [%{name: "Tutorial", type: :audience}], fn attrs ->
  Demo.Repo.query!(
    "UPDATE tags SET type = ? WHERE slug = ?",
    [Atom.to_string(attrs.type), slugify.(attrs.name)]
  )
end)

tags =
  tag_attrs
  |> Enum.map(fn attrs ->
    attrs
    |> Map.put(:slug, slugify.(attrs.name))
    |> then(&create!.(Tag, :create, &1))
  end)

tag_by_name = Map.new(tags, &{&1.name, &1})

posts =
  [
    %{
      title: "Getting Started with Ash Framework",
      content:
        "Ash is a declarative, resource-based framework for building Elixir applications. It provides a powerful DSL for defining your domain model and automatically generates APIs, queries, and mutations.",
      excerpt: "A first look at resource-driven Elixir apps.",
      status: :published,
      topic_tags: ["Ash"],
      audience_tags: ["Beginners"],
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
      topic_tags: ["Backpex", "LiveView"],
      audience_tags: ["Admins"],
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
      topic_tags: ["SQLite"],
      audience_tags: ["Beginners", "Admins"],
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
      topic_tags: ["LiveView"],
      audience_tags: ["Editors"],
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
      topic_tags: ["Ash", "Backpex"],
      audience_tags: ["Admins", "Editors"],
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
      topic_tags: ["Backpex"],
      audience_tags: ["Admins"],
      published: false,
      published_on: ~D[2025-09-01],
      featured: false,
      rating: 2,
      author: "Katherine Johnson"
    }
  ]
  |> Enum.map(fn attrs ->
    {author_name, attrs} = Map.pop!(attrs, :author)
    {topic_tag_names, attrs} = Map.pop!(attrs, :topic_tags)
    {audience_tag_names, attrs} = Map.pop!(attrs, :audience_tags)

    attrs =
      attrs
      |> Map.put(:slug, slugify.(attrs.title))
      |> Map.put(:author_id, Map.fetch!(author_by_name, author_name).id)
      |> Map.put(:topic_tags, Enum.map(topic_tag_names, &Map.fetch!(tag_by_name, &1).id))
      |> Map.put(:audience_tags, Enum.map(audience_tag_names, &Map.fetch!(tag_by_name, &1).id))

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
  "Created #{length(authors)} authors, #{length(tags)} tags, #{length(posts)} posts, and #{length(comments)} comments"
)
