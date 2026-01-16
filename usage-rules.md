# AshBackpex Usage Rules

Rules for LLM agents working with AshBackpex - an integration library between Ash Framework and Backpex admin interfaces.

## Overview

AshBackpex provides a DSL for creating Backpex admin interfaces from Ash resources. It uses Spark DSL for compile-time code generation and automatically bridges Backpex operations to Ash actions.

## Creating a LiveResource

Always use `AshBackpex.LiveResource` with a `backpex` block:

```elixir
defmodule MyAppWeb.Admin.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource MyApp.Blog.Post           # Required: Ash resource module
    layout {MyAppWeb.Layouts, :admin}  # Required: LiveView layout

    fields do
      field :title
      field :content
    end
  end
end
```

## Required Options

Every `backpex` block MUST have:
- `resource` - The Ash resource module
- `layout` - The LiveView layout as `{Module, :function}` tuple or function capture

## Field Configuration

### Basic Fields

Fields can reference attributes, relationships, calculations, or aggregates:

```elixir
fields do
  field :title                    # Simple attribute
  field :author                   # Relationship (auto-detects BelongsTo)
  field :word_count              # Calculation
  field :comment_count           # Aggregate
end
```

### Field Type Auto-Detection

AshBackpex automatically maps Ash types to Backpex fields:
- `Ash.Type.String` → `Backpex.Fields.Text`
- `Ash.Type.Boolean` → `Backpex.Fields.Boolean`
- `Ash.Type.Integer` / `Float` → `Backpex.Fields.Number`
- `Ash.Type.Date` → `Backpex.Fields.Date`
- `Ash.Type.DateTime` / `UtcDatetime` → `Backpex.Fields.DateTime`
- `:belongs_to` → `Backpex.Fields.BelongsTo`
- `:has_many` → `Backpex.Fields.HasMany`
- Atom with `one_of` constraint → `Backpex.Fields.Select`
- Array with `one_of` constraint → `Backpex.Fields.MultiSelect`

### Override Field Module

When auto-detection isn't sufficient, specify the module explicitly:

```elixir
field :content do
  module Backpex.Fields.Textarea
end
```

### Relationship Fields

For relationships, specify `display_field` and optionally `live_resource`:

```elixir
field :author do
  display_field :name                        # Field to display from related record
  live_resource MyAppWeb.Admin.UserLive      # Enables navigation links
end
```

### Searchable Fields

Enable search on string fields:

```elixir
field :title do
  searchable true
end
```

### Field Visibility

Control where fields appear:

```elixir
field :inserted_at do
  only [:index, :show]      # Only show on index and show views
end

field :internal_notes do
  except [:index]           # Hide from index view
end
```

## Preloading Relationships

Use `load` to preload relationships, calculations, or aggregates:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  load [:author, :comments, nested: [:author]]

  fields do
    field :author
  end
end
```

## Filters

Add filters to the index view:

```elixir
filters do
  filter :published do
    module Backpex.Filters.Boolean
  end

  filter :status do
    module Backpex.Filters.Select
    label "Post Status"              # Optional custom label
  end
end
```

## Item Actions

Add or remove per-item actions:

```elixir
item_actions do
  strip_default [:delete]                    # Remove default delete action
  action :archive, MyApp.ItemActions.Archive # Add custom action
end
```

## Custom Ash Actions

Specify which Ash actions to use (defaults to primary actions):

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}

  create_action :admin_create
  read_action :admin_read
  update_action :admin_update
  destroy_action :soft_delete
end
```

## Custom Changesets

Provide custom changeset functions for advanced control:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}

  create_changeset fn item, params, metadata ->
    assigns = Keyword.get(metadata, :assigns)
    Ash.Changeset.for_create(item.__struct__, :create, params,
      actor: assigns.current_user
    )
  end
end
```

The changeset function receives:
- `item` - The struct being created/updated
- `params` - Form parameters
- `metadata` - Keyword list with `:assigns` and `:target` keys

## Display Names

Customize resource labels:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  singular_name "Blog Post"
  plural_name "Blog Posts"
end
```

## Sorting

Set default sort order:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  init_order %{by: :inserted_at, direction: :desc}
end
```

## Pagination

Configure pagination options:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  per_page_default 25
  per_page_options [10, 25, 50, 100]
end
```

## Form Panels

Organize form fields into panels:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}

  panels [
    content: "Content",
    settings: "Settings"
  ]

  fields do
    field :title do
      panel :content
    end
    field :published do
      panel :settings
    end
  end
end
```

## Authorization

AshBackpex automatically integrates with Ash authorization:
- Uses `assigns.current_user` as the actor
- Checks `Ash.can?/2` for CRUD operations
- Hides buttons/actions the user can't perform

Ensure your Ash resources have policies defined and `current_user` is set in assigns.

## Router Setup

Add routes for your LiveResource:

```elixir
scope "/admin", MyAppWeb.Admin do
  pipe_through [:browser, :admin_auth]

  live "/posts", PostLive
end
```

## Common Patterns

### Read-Only Admin

For resources without update/destroy:

```elixir
backpex do
  resource MyApp.AuditLog
  layout {MyAppWeb.Layouts, :admin}

  item_actions do
    strip_default [:edit, :delete]
  end

  fields do
    field :action
    field :user
    field :inserted_at
  end
end
```

### Rich Text Content

Use Textarea for longer content:

```elixir
field :content do
  module Backpex.Fields.Textarea
  rows 15
end
```

### Date Formatting

Custom date display format:

```elixir
field :published_at do
  format "%B %d, %Y at %H:%M"
end
```

## Troubleshooting

### "Unable to derive Backpex.Field module"

The field type couldn't be auto-detected. Solutions:
1. Ensure the field name matches an attribute/relationship/calculation/aggregate on the resource
2. Specify the module explicitly: `field :foo do module Backpex.Fields.Text end`

### Authorization Issues

If actions are hidden unexpectedly:
1. Check that `current_user` is set in your LiveView assigns
2. Verify your Ash resource policies allow the action
3. Test with `Ash.can?({resource, action}, user)` in IEx

### Fields Not Loading

If relationship/calculation fields show errors:
1. Add them to the `load` option: `load [:author, :word_count]`
2. Ensure the field is defined on the Ash resource
