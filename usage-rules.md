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
- `:has_many` → `AshBackpex.Fields.HasMany`
- `:many_to_many` → `AshBackpex.Fields.HasMany`
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

`index_editable true` works for `belongs_to` fields, with or without
`typeahead`. Backpex's index view saves the inline edit only when the chosen
value is one of the field's options and the user may update the record.

### Repeating and Embedded Child Fields

`has_many` relationships continue to use the selection-oriented
`AshBackpex.Fields.HasMany` by default. It renders and saves like
`Backpex.Fields.HasMany`, but its option search uses `lower(...) LIKE` instead
of `ILIKE`, so it works on SQLite and MySQL as well as Postgres. Set
`module Backpex.Fields.HasMany` only to keep Backpex's Postgres-only search. Opt into repeated child forms with
`Backpex.Fields.InlineCRUD` and configure its child fields:

```elixir
field :rows do
  module Backpex.Fields.InlineCRUD
  entry_label "row"
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

Set `entry_label` to the singular name of one entry; it words the Add, Delete,
and Move controls and defaults to the field's plural `label`. It is valid only
on InlineCRUD fields.

AshBackpex derives each child field against the related child resource using
the same module, option, and relationship-query derivation as top-level fields.
It also derives `type: :assoc` for a `has_many`, adds icon-only move-up and
move-down controls, normalizes InlineCRUD's order and delete parameters to an ordered
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

### Upload Fields

Use `Backpex.Fields.Upload` for an attribute that stores file names, such as a
`:string` for one file or `{:array, :string}` for several. Backpex requires the
`list_existing_files`, `put_upload_change`, `consume_upload` and
`remove_uploads` functions; see `Backpex.Fields.Upload` for their arguments.

```elixir
field :avatar, Backpex.Fields.Upload do
  accept ~w(.jpg .jpeg .png)
  max_entries 1
  list_existing_files &__MODULE__.list_existing_files/1
  put_upload_change &__MODULE__.put_upload_change/6
  consume_upload &__MODULE__.consume_upload/4
  remove_uploads &__MODULE__.remove_uploads/3
end
```

`put_upload_change` puts the file names into the params under the field name,
so the create and update actions must accept the attribute. Backpex consumes
uploads after the Ash action has saved the item, outside its transaction.
AshBackpex removes the `"<field>_used_input"` param Backpex adds, so the Ash
action does not reject it. A field module that implements Backpex's upload
callbacks, such as `consume_upload/5` of `Backpex.Field`, can be used instead of
the function options.

#### Upload fields backed by AshStorage

An [AshStorage](https://github.com/ash-project/ash_storage) attachment works
with the same callbacks. Backpex consumes the uploads after the Ash action has
saved the record, so attach them with `AshStorage.Operations` instead of an
action argument. Load the attachments and their blobs with the `load` option:

```elixir
load gallery: [:url, :blob]

field :gallery, Backpex.Fields.Upload do
  max_entries 6
  list_existing_files &__MODULE__.list_gallery_files/1
  file_label &__MODULE__.gallery_file_label/1
  put_upload_change &__MODULE__.put_gallery_change/6
  consume_upload &__MODULE__.consume_gallery_upload/4
  remove_uploads &__MODULE__.remove_gallery_uploads/3
end

# "<blob id>/<filename>" identifies a file and carries its label.
def list_gallery_files(%{gallery: images}) when is_list(images),
  do: Enum.map(images, &"#{&1.blob_id}/#{&1.blob.filename}")

def list_gallery_files(_item), do: []

def gallery_file_label(file), do: file |> String.split("/", parts: 2) |> List.last()

# Attachments are not inputs of the Ash action.
def put_gallery_change(_socket, params, _item, _uploaded, _removed, _action), do: params

def consume_gallery_upload(_socket, post, %{path: path}, entry) do
  {:ok, _result} =
    AshStorage.Operations.attach(post, :gallery, Ash.Type.File.from_path(path),
      filename: entry.client_name,
      content_type: entry.client_type
    )

  {:ok, entry.client_name}
end

def remove_gallery_uploads(_socket, post, removed_files) do
  for file <- removed_files do
    [blob_id | _filename] = String.split(file, "/", parts: 2)
    {:ok, _purged} = AshStorage.Operations.purge(post, :gallery, blob_id: blob_id)
  end
end
```

Pass the uploaded file as `Ash.Type.File.from_path/1`; AshStorage stores a
binary argument as the file's contents, not as a path. Give the attachment's
foreign key `on_delete: :nilify`, so AshStorage can purge the attachments of a
destroyed record. The demo's Articles gallery is a complete example.

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

## Selected Attributes and Preloading

The admin reads every attribute Ash selects by default, plus any attribute
listed as a field (including one with `select_by_default? false`).
Relationships, calculations, and aggregates are loaded only when they are fields
or listed in `load`.

`can?/3` builds an update and a destroy changeset for every index row, which
runs the resource's changes. A change must not read an attribute with
`select_by_default? false` or an unloaded relationship unless it checks for
`%Ash.NotLoaded{}`, reads only what the changeset is changing, or does the work
in a `before_action` hook.

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

The index, show page and record count all read through `read_action`, so its
filters and preparations apply. Backpex's search, filters, sort and pagination
are applied on top of it.

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

Backpex's `context_assigns` option limits the assigns that render-time
callbacks, such as `can?/3` and field and filter functions, receive on the index
and show views. It defaults to `:all`. A list of keys is added to the assigns
Backpex always passes, and AshBackpex appends `:current_user` and `:actor` so
the generated `can?/3` and relationship option queries keep their Ash actor:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  context_assigns [:tenant]
end
```

The functions and callbacks of fields and the `render/1` and `render_form/1`
callbacks of filters then receive only the reduced assigns, so list every other
assign they read. `filters/1` and a filter's `can?/1` always receive all
assigns.

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

The LiveResource defines a callback AshBackpex generates. For `can?/3`, set
`create_action false`, `update_action false`, or `destroy_action false` when the
rule turns an operation off for everyone, and write Ash policies otherwise. For
the others, use the matching DSL entry (`fields`, `filters`, `item_actions`,
`layout`). Then remove the function. The error message names the replacement.

### Index Page Crashes on `%Ash.NotLoaded{}` in a Change

A resource change reads a value the index rows do not have: an attribute with
`select_by_default? false` or a relationship that is not loaded. `can?/3` runs
the change for every row. Make the change read only attributes the changeset is
changing (`Ash.Changeset.changing_attribute?/2`), add the value to `fields` or
`load`, or move the work into `Ash.Changeset.before_action/2`.

### Fields Not Loading

If relationship/calculation fields show errors:
1. Add them to the `load` option: `load [:author, :word_count]`
2. Ensure the field is defined on the Ash resource
