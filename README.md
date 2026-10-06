# Ash Backpex

You got your [Ash](https://ash-hq.org/) in my [Backpex](https://backpex.live/). You got your [Backpex](https://backpex.live/) in my [Ash](https://ash-hq.org/).

An integration library that brings together Ash Framework's powerful resource system with Backpex's admin interface capabilities. This library provides a clean DSL for creating admin interfaces directly from your Ash resources.

> ## Upgrading to 0.3? Read this first {: .warning}
>
> 0.2 and 0.3 break more than earlier releases did. Your application may stop
> compiling, and the admin layout has to change if you are coming from 0.1. Follow
> [Upgrading to 0.3](guides/upgrading-to-0.3.md) before you bump the dependency.

> ## Warning! {: .error}
>
> Backpex itself is pre-1.0, so expect its API to change, and AshBackpex's with
> it.

AshBackpex enforces your Ash policies in the admin. Reads, creates, and updates
run as the current user. Deletes are checked against the destroy action's
policies for every selected record, as the current user, before anything is
deleted; the destroy action itself then runs without an actor, because Backpex
does not pass one to that callback.

This is a partial implementation - feel free to open a github issue to request additional features or submit a PR if you're into that kind of thing ;)

## Installation

Add `ash_backpex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.3.3"}
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
    field :title

    field :config, Backpex.Fields.Textarea do
      label "Configuration"
    end

    field :category do
      display_field :name
      typeahead true
    end
  end
end
```

AshBackpex derives child modules and relationship options from the related
child resource using the same rules as top-level fields. It also derives
`type: :assoc`, adds move-up and move-down controls, translates the
add/delete/order form parameters to an ordered list for Ash, and preserves
child primary keys for updates. The parent Ash actions must expose an
array-of-maps argument and use `manage_relationship`, typically with
`type: :direct_control`.

The `child_fields` DSL is recursive for typed embedded Ash resources. Repeated
embedded children use InlineCRUD with an inferred `type: :embed`; singular
embedded children use `AshBackpex.Fields.Embedded`. Each nested field is
derived against its immediate embedded resource rather than the root resource.

```elixir
field :sections do
  module Backpex.Fields.InlineCRUD

  child_fields do
    field :title

    field :columns do
      module Backpex.Fields.InlineCRUD

      child_fields do
        field :heading

        field :target do
          module AshBackpex.Fields.Embedded

          child_fields do
            field :kind
            field :path
          end
        end
      end
    end
  end
end
```

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

## Development

See the
[contribution guide](https://github.com/enoonan/ash_backpex/blob/main/CONTRIBUTING.md)
for setup and pull-request expectations. The
[repository knowledge map](https://github.com/enoonan/ash_backpex/blob/main/docs/README.md)
links architecture, testing, and maintenance guidance to the authoritative source
and test files.

## Thanks!

Building this little integration seemed easier than any alternatives to get the admin I wanted, which is a credit to the great work of the Backpex team!
