# Ash Backpex

You got your [Ash](https://ash-hq.org/) in my [Backpex](https://backpex.live/). You got your [Backpex](https://backpex.live/) in my [Ash](https://ash-hq.org/).

An integration library that brings together Ash Framework's powerful resource system with Backpex's admin interface capabilities. This library provides a clean DSL for creating admin interfaces directly from your Ash resources.

> ## Warning! {: .error}
>
> Backpex itself is pre-1.0, so expect its API to change. AshBackpex passes the
> current actor through normal reads, creates, and updates, but Backpex's bulk
> delete adapter callback does not provide the actor. For now, use AshBackpex
> in a high-trust environment such as internal tooling.

This is a partial implementation - feel free to open a github issue to request additional features or submit a PR if you're into that kind of thing ;)

## Installation

Add `ash_backpex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.1.10"}
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

## Repeating Child Forms

Opt a `has_many` relationship into Backpex's `InlineCRUD` field to edit child
records directly in the parent form:

```elixir
field :rows do
  module Backpex.Fields.InlineCRUD
  except [:index]

  child_fields do
    field :title, Backpex.Fields.Text
    field :config, Backpex.Fields.Textarea do
      label "Configuration"
    end
  end
end
```

AshBackpex derives `type: :assoc`, adds move-up and move-down controls,
translates the add/delete/order form parameters to an ordered list for Ash,
and preserves child primary keys for updates. The parent Ash actions must
expose an array-of-maps argument and use `manage_relationship`, typically with
`type: :direct_control`.

See the [Inline CRUD guide](guides/inline-crud.md) for the complete resource and
LiveResource setup.

## Typeahead Relationship Fields

Large `belongs_to` relationships can use a server-backed, single-select
typeahead without loading every related record into the form:

```elixir
field :author do
  display_field :name
  typeahead true
  typeahead_limit 10
  debounce 300
  prompt "Choose an author"
end
```

The search uses `display_field` and preserves the relationship's Ash filter,
sort, read action, context, actor, tenant, and authorization through the
generated `options_query`. Opening the dropdown
preloads up to `typeahead_limit` options from that query; typing replaces them
with matching results.

## Filters and Actions

## Thanks!

Building this little integration seemed easier than any alternatives to get the admin I wanted, which is a credit to the great work of the Backpex team!
