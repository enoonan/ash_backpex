# Ash Backpex

You got your [Ash](https://ash-hq.org/) in my [Backpex](https://backpex.live/). You got your [Backpex](https://backpex.live/) in my [Ash](https://ash-hq.org/).

An integration library that brings together Ash Framework's powerful resource system with Backpex's admin interface capabilities. This library provides a clean DSL for creating admin interfaces directly from your Ash resources.

> ## Warning! {: .error}
>
> Backpex itself is pre-1.0 so expect the API to change in a breaking way! Also, it cannot currently take full advantage of Ash authorization policies. For now I would only recommend using it in a high-trust environment such as internal tooling.

This is a partial implementation - feel free to open a github issue to request additional features or submit a PR if you're into that kind of thing ;)

## Installation

Add `ash_backpex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.0.13"}
  ]
end
```

## Basic Usage

```elixir
# myapp_web/live/admin/post_live.ex
defmodule MyAppWeb.Live.Admin.PostLive do
    use AshBackpex.LiveResource

    backpex do
      resource MyApp.Blog.Post
      load [:author]
      layout &MyAppWeb.Layouts.admin/1

      fields do
        field :title
        field :published_at

        field :author do
          display_field(:name)
          live_resource(MyAppWeb.Live.Admin.AuthorLive)
        end
      end
    end
end
```

## Custom Field Type Mappings

AshBackpex automatically maps Ash types to Backpex field modules, but you can customize these mappings globally or per-application.

### Configuration

```elixir
# config/config.exs

# Global config (applies to all apps using AshBackpex)
config :ash_backpex,
  field_type_mappings: %{
    MyApp.Types.Money => Backpex.Fields.Currency,
    MyApp.Types.RichText => Backpex.Fields.Textarea
  }

# Or use a function for conditional logic
config :ash_backpex,
  field_type_mappings: fn type, constraints ->
    case type do
      MyApp.Types.Money -> Backpex.Fields.Currency
      _ -> nil  # Fall back to default
    end
  end
```

### Precedence

Field type resolution follows this order:
1. Explicit `module` option in the field DSL
2. App-scoped config (`config :my_app, AshBackpex, ...`)
3. Global config (`config :ash_backpex, ...`)
4. Default Ash type mappings

See `AshBackpex.LiveResource` module docs for more examples and details.

## Filters and Actions

## Thanks!

Building this little integration seemed easier than any alternatives to get the admin I wanted, which is a credit to the great work of the Backpex team!
