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
- `:many_to_many` → `Backpex.Fields.HasMany`
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

Relationship fields derive Backpex `options_query` from Ash relationship
`filter`, `sort`, and `default_sort` settings. If a relationship only allows
records with `filter expr(type == :public)`, the generated options list will use
the same filter. Set `options_query` on the field to override this behavior.

For large `belongs_to` relationships, opt into a server-backed single-select
typeahead instead of loading every option:

```elixir
field :author do
  display_field :name
  typeahead true
  typeahead_limit 10
  debounce 300
  prompt "Choose an author"
end
```

The typeahead searches `display_field`. The existing `debounce` option controls
search debouncing.
The dropdown initially shows up to `typeahead_limit` options from the normal
relationship query, then replaces them with matching results as the user types.
Relationship filters, sorts, read action, context, actor, tenant, and
authorization continue to flow through the field's derived `options_query`.

### Repeating and Embedded Child Fields

`has_many` relationships continue to use the selection-oriented
`Backpex.Fields.HasMany` by default. Opt into repeated child forms with
`Backpex.Fields.InlineCRUD` and configure its child fields:

```elixir
field :rows do
  module Backpex.Fields.InlineCRUD
  except [:index]

  child_fields do
    field :title
    field :position

    field :category do
      display_field :name
      typeahead true
    end
  end
end
```

AshBackpex derives each child field against the related child resource using
the same module, option, and relationship-query derivation as top-level fields.
It also derives `type: :assoc` for a `has_many`, adds move-up and move-down
controls, normalizes InlineCRUD's order and delete parameters to an ordered
list, and includes existing child primary keys in hidden inputs. The parent
create/update action must accept an `{:array, :map}` argument and connect it to
the relationship:

```elixir
argument :rows, {:array, :map}, allow_nil?: false, default: []
change manage_relationship(:rows, type: :direct_control)
```

Typed embedded Ash resources may describe their field tree recursively. Use
InlineCRUD for an array embed and `AshBackpex.Fields.Embedded` for a singular
embed:

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

At every level, field modules, labels, relationship option queries, and
typeaheads are derived from the immediate child resource. AshBackpex supplies
`type: :embed` for each `{:array, EmbeddedResource}` InlineCRUD node. A
singular embedded resource is not a valid InlineCRUD cardinality.

Each typed embedded resource uses `data_layer: :embedded`. The parent resource
stores the root embedded array and its create/update actions must accept that
attribute; unlike a relationship, it does not use `manage_relationship`:

```elixir
attribute :sections, {:array, MyApp.Content.Section}, default: [], public?: true

create :admin_create do
  accept [:title, :sections]
end

update :admin_update do
  require_atomic? false
  accept [:title, :sections]
end
```

Repeated levels submit indexed maps plus depth-local order, delete, and move
controls. AshBackpex removes the controls and normalizes each repeated level to
an ordered list of maps; singular embedded values remain maps. Keep `default:
[]` for editable empty lists. Validation rerenders retain the nested field path
and persistent row identity. Typed embedded trees can coexist with relationship
InlineCRUD; union or variant-specific conditional forms are not supported.

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

## Persisting Index State

Backpex 0.20 makes index-state persistence opt-in. Choose any index settings
that should survive navigation and reloads:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  persist [:order, :filters, :columns, :metrics]
end
```

The application layout must use Backpex's preference-enabled app shell and the
router must include `backpex_routes()`. See the Getting Started guide for the
complete layout and router setup.

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

Backpex enforces the generated `can?/3` before every mutation and item action:
- Item actions receive records re-read through the adapter as the current actor
- A selection with any unauthorized record raises `Backpex.ForbiddenError`; a
  deleted or unreadable record raises `Backpex.NoResultsError`
- Pass `authorize?: false` when a custom item action writes the records it was
  handed through `Backpex.Resource`; Backpex already authorized them
- Call `Backpex.Resource.delete_all/4` and `update_all/5` with `socket.assigns`

Do not define `can?/3` in a LiveResource. AshBackpex generates it, and defining
it is a compile error. Express access rules one of two ways:

- The admin does not offer create, edit, or delete to anyone: set
  `create_action false`, `update_action false`, or `destroy_action false`. The
  generated `can?/3` denies `:new`, `:edit`, or `:delete` without consulting Ash.
- The rule depends on the actor or the record: write Ash policies on the
  resource.

Routing with `except: [:new]` does not hide Backpex's empty-state "New" button,
which only consults `can?(assigns, :new, nil)`. Set `create_action false` too.

## Backpex Callbacks

AshBackpex generates `can?/3`, `fields/0`, `filters/0`, `item_actions/1`, and
`layout/1`; defining them is a compile error. Use the DSL instead; for `can?/3`,
use `create_action false` / `update_action false` / `destroy_action false` or
Ash policies (see Authorization).

Other `Backpex.LiveResource` callbacks (`on_item_updated/2`, `return_to/5`,
`form_actions/2`, `index_row_class/4`, ...) can be defined in the module. Write
`form_actions/2` and `index_row_class/4` as pattern-matching clauses without a
catch-all so unmatched calls fall through to Backpex's default:

```elixir
@impl Backpex.LiveResource
def form_actions(%{item: %{status: :draft}}, _default_actions) do
  [save: %{label: "Save as draft", soft: true}, publish: %{label: "Publish"}]
end
```

A catch-all clause makes Elixir warn that Backpex's default clause is redundant.

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

### "defines can?/3, but AshBackpex generates can?/3"

The LiveResource defines a callback AshBackpex generates. Earlier versions
silently replaced the definition, so it never ran. For `can?/3`, set
`create_action false`, `update_action false`, or `destroy_action false` when the
rule turns an operation off for everyone, and write Ash policies otherwise. For
the others, use the matching DSL entry (`fields`, `filters`, `item_actions`,
`layout`). Then remove the function. The error message names the replacement.

### Fields Not Loading

If relationship/calculation fields show errors:
1. Add them to the `load` option: `load [:author, :word_count]`
2. Ensure the field is defined on the Ash resource
