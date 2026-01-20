# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

posts = [
  %{
    title: "Getting Started with Ash Framework",
    content: "Ash is a declarative, resource-based framework for building Elixir applications. It provides a powerful DSL for defining your domain model and automatically generates APIs, queries, and mutations.",
    published: true,
    rating: 5
  },
  %{
    title: "Understanding Backpex Admin Panels",
    content: "Backpex is a highly customizable admin panel for Phoenix LiveView applications. Combined with Ash, it provides a seamless way to manage your resources through an intuitive interface.",
    published: true,
    rating: 4
  },
  %{
    title: "SQLite for Development",
    content: "SQLite is an excellent choice for development and small-scale applications. It requires no separate server process and stores the entire database in a single file.",
    published: true,
    rating: 4
  },
  %{
    title: "Phoenix LiveView Patterns",
    content: "LiveView enables rich, real-time user experiences with server-rendered HTML. Learn about common patterns like live navigation, form handling, and real-time updates.",
    published: true,
    rating: 5
  },
  %{
    title: "Draft: Upcoming Features",
    content: "This is a draft post about upcoming features we're planning to add. Stay tuned for more updates!",
    published: false,
    rating: 3
  },
  %{
    title: "Working with Ecto Migrations",
    content: "Ecto migrations allow you to evolve your database schema over time. This post covers best practices for writing migrations that are safe and reversible.",
    published: true,
    rating: 4
  },
  %{
    title: "Elixir Pattern Matching",
    content: "Pattern matching is one of Elixir's most powerful features. It allows you to destructure data and control flow in elegant ways that aren't possible in most other languages.",
    published: true,
    rating: 5
  },
  %{
    title: "Building APIs with Ash",
    content: "Ash makes it easy to build robust APIs. Define your resources once and get JSON:API, GraphQL, or custom endpoints with minimal configuration.",
    published: false,
    rating: 3
  }
]

for post <- posts do
  Demo.Blog.Post
  |> Ash.Changeset.for_create(:create, post)
  |> Ash.create!()
end

IO.puts("Created #{length(posts)} posts")
