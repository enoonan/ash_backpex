# Ash Backpex

You got your [Ash](https://ash-hq.org/) in my [Backpex](https://backpex.live/). You got your [Backpex](https://backpex.live/) in my [Ash](https://ash-hq.org/).

An integration library that brings together Ash Framework's powerful resource system with Backpex's admin interface capabilities. This library provides a clean DSL for creating admin interfaces directly from your Ash resources.

> Warning!
> Backpex itself is pre-1.0 so expect the API to change in a breaking way! Also, it cannot currently take full advantage of Ash authorization policies. For now I would only recommend using it in a high-trust environment such as internal tooling.

This is a partial implementation - feel free to open a github issue to request additional features or submit a PR if you're into that kind of thing ;)

## Installation

Add `ash_backpex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.0.6"}
  ]
end
```

## Usage

```elixir
# myapp_web/live/admin/post_live.ex
defmodule MyAppWeb.Live.Admin.PostLive do
    use AshBackpex.LiveResource

    backpex do
      resource MyApp.Blog.Post
      load [:author]
      layout({MyAppWeb.Layouts, :admin})

      fields do
        field :title
        field :published_at

        field :author do
          display_field(:name)
          live_resource(MyAppWeb.Live.Admin.AuthorLive)
        end
      end

      filters do
        filter :state do
          module MyAppWeb.Live.Admin.Filters.PostStateFilter
        end
      end
    end
end
```

## Thanks!

Building this little integration seemed easier than any alternatives to get the admin I wanted, which is a credit to the great work of the Backpex team!
