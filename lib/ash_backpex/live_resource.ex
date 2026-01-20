defmodule AshBackpex.LiveResource do
  @moduledoc """
  The primary entry point to AshBackpex - an integration library that brings together
  Ash Framework's powerful resource system with Backpex's admin interface capabilities.

  This module provides a clean DSL for creating admin interfaces directly from your Ash resources.
  When you `use AshBackpex.LiveResource`, it automatically generates a Backpex LiveResource
  at compile time based on your DSL configuration.

  ## Basic Usage

  ```elixir
  defmodule MyAppWeb.Admin.PostLive do
    use AshBackpex.LiveResource

    backpex do
      resource MyApp.Blog.Post
      layout {MyAppWeb.Layouts, :admin}

      fields do
        field :title
        field :content do
          module Backpex.Fields.Textarea
        end
        field :published
        field :author do
          display_field :name
          live_resource MyAppWeb.Admin.UserLive
        end
      end
    end
  end
  ```

  ## Features

  ### Automatic Field Type Detection

  AshBackpex automatically derives Backpex field modules from your Ash resource attribute types:

  | Ash Type | Backpex Field |
  |----------|---------------|
  | `Ash.Type.String` | `Backpex.Fields.Text` |
  | `Ash.Type.Boolean` | `Backpex.Fields.Boolean` |
  | `Ash.Type.Integer` | `Backpex.Fields.Number` |
  | `Ash.Type.Float` | `Backpex.Fields.Number` |
  | `Ash.Type.Date` | `Backpex.Fields.Date` |
  | `Ash.Type.Time` | `Backpex.Fields.Time` |
  | `Ash.Type.DateTime` | `Backpex.Fields.DateTime` |
  | `Ash.Type.UtcDatetime` | `Backpex.Fields.DateTime` |
  | `:belongs_to` relationship | `Backpex.Fields.BelongsTo` |
  | `:has_many` relationship | `Backpex.Fields.HasMany` |
  | `{:array, _}` with `one_of` | `Backpex.Fields.MultiSelect` |
  | Atom with `one_of` constraint | `Backpex.Fields.Select` |

  You can always override the derived module by specifying it explicitly:

  ```elixir
  field :content do
    module Backpex.Fields.Textarea
  end
  ```

  ### Custom Field Type Mappings

  You can configure custom mappings from Ash types to Backpex field modules globally
  or per-application. This is useful when you have custom Ash types (like `Money` or
  `RichText`) that should consistently map to specific Backpex fields.

  #### Configuration Options

  **Global config** (applies to all apps using AshBackpex):

  ```elixir
  # config/config.exs
  config :ash_backpex,
    field_type_mappings: %{
      MyApp.Types.Money => Backpex.Fields.Currency,
      MyApp.Types.RichText => Backpex.Fields.Textarea
    }
  ```

  **App-scoped config** (overrides global for a specific app):

  ```elixir
  # config/config.exs
  config :my_app, AshBackpex,
    field_type_mappings: %{
      MyApp.Types.Money => MyApp.Fields.MoneyField
    }
  ```

  #### Precedence Rules

  Field type derivation follows this precedence order (highest to lowest):

  1. **Explicit `module` option in DSL** - Always wins
  2. **App-scoped config** - `config :my_app, AshBackpex, field_type_mappings: ...`
  3. **Global config** - `config :ash_backpex, field_type_mappings: ...`
  4. **Default mappings** - Built-in Ash type to Backpex field mappings

  #### Map Format

  Use a map when you have simple type-to-field mappings:

  ```elixir
  config :ash_backpex,
    field_type_mappings: %{
      # Override default String -> Text mapping
      Ash.Type.String => Backpex.Fields.Textarea,

      # Map custom Ash types
      MyApp.Types.Money => Backpex.Fields.Currency,
      MyApp.Types.RichText => MyApp.Fields.RichTextField,

      # Map array types
      {:array, Ash.Type.String} => Backpex.Fields.MultiSelect
    }
  ```

  #### Function Format

  Use a function when you need to inspect constraints or implement conditional logic:

  ```elixir
  config :ash_backpex,
    field_type_mappings: fn type, constraints ->
      case {type, constraints} do
        # Map Money type to currency field
        {MyApp.Types.Money, _} ->
          Backpex.Fields.Currency

        # Map strings with max_length > 255 to Textarea
        {Ash.Type.String, constraints} when is_list(constraints) ->
          if Keyword.get(constraints, :max_length, 0) > 255 do
            Backpex.Fields.Textarea
          else
            nil  # Fall back to default
          end

        # Return nil to use default mapping
        _ ->
          nil
      end
    end
  ```

  The function must have arity 2, receiving `(type, constraints)`, and return either:
  - A Backpex field module (atom) - Use this field for the type
  - `nil` - Fall back to the default mapping

  #### Common Use Cases

  **Custom Rich Text field:**

  ```elixir
  config :ash_backpex,
    field_type_mappings: %{
      MyApp.Types.RichText => MyApp.Fields.TiptapEditor
    }
  ```

  **Custom Money/Currency field:**

  ```elixir
  config :ash_backpex,
    field_type_mappings: %{
      Money.Ecto.Composite.Type => Backpex.Fields.Currency
    }
  ```

  **Override all strings to use Textarea:**

  ```elixir
  config :ash_backpex,
    field_type_mappings: %{
      Ash.Type.String => Backpex.Fields.Textarea
    }
  ```

  See `AshBackpex.Config` for more details on configuration options and validation.

  ### Ash Authorization Integration

  AshBackpex respects your Ash authorization policies. The generated `can?/3` callback
  checks Ash authorization for CRUD operations:

  - `:new` - Checks `Ash.can?({Resource, create_action}, actor)`
  - `:index` / `:show` - Checks `Ash.can?({Resource, read_action}, actor)`
  - `:edit` - Checks `Ash.can?({item, update_action}, actor)`
  - `:delete` - Checks `Ash.can?({item, destroy_action}, actor)`

  Custom item actions fall back to checking if a matching Ash action exists and
  verifying authorization against it.

  ### Relationships, Calculations, and Aggregates

  All Ash relationships, calculations, and aggregates can be displayed as fields:

  ```elixir
  backpex do
    resource MyApp.Blog.Post
    layout {MyAppWeb.Layouts, :admin}
    load [:author, :comments]  # Preload relationships

    fields do
      field :title
      field :author do          # belongs_to relationship
        display_field :name
        live_resource MyAppWeb.Admin.UserLive
      end
      field :word_count         # calculation
      field :comment_count      # aggregate
    end
  end
  ```

  ### Search

  Enable search on string fields by setting `searchable: true`:

  ```elixir
  fields do
    field :title do
      searchable true
    end
    field :content do
      searchable true
    end
  end
  ```

  Search uses Ash's `contains` expression and supports multiple searchable fields
  (combined with OR logic).

  ### Filters

  Add filters to your admin interface:

  ```elixir
  filters do
    filter :published do
      module Backpex.Filters.Boolean
    end
    filter :status do
      module MyApp.Filters.StatusFilter
      label "Post Status"
    end
  end
  ```

  ### Custom Item Actions

  Add custom actions to individual items:

  ```elixir
  item_actions do
    action :promote, MyApp.ItemActions.Promote
    strip_default [:delete]  # Remove default delete action
  end
  ```

  ### Custom Actions

  Specify which Ash actions to use for CRUD operations:

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

  ### Custom Changesets

  Provide custom changeset functions for create and update operations:

  ```elixir
  backpex do
    resource MyApp.Blog.Post
    layout {MyAppWeb.Layouts, :admin}

    create_changeset &MyApp.Blog.Post.admin_create_changeset/3
    update_changeset &MyApp.Blog.Post.admin_update_changeset/3
  end
  ```

  The changeset function receives `(item, params, metadata)` where metadata contains:
  - `:assigns` - The LiveView assigns
  - `:target` - The form field that triggered the changeset (or `nil`)

  ## Router Setup

  Add routes for your LiveResource in your router:

  ```elixir
  scope "/admin", MyAppWeb.Admin do
    pipe_through [:browser, :admin_auth]

    live "/posts", PostLive
  end
  ```

  ## DSL Reference

  See `AshBackpex.LiveResource.Dsl` for complete DSL documentation including all
  available options for `backpex`, `fields`, `filters`, and `item_actions` sections.
  """
  use Spark.Dsl,
    default_extensions: [
      extensions: [AshBackpex.LiveResource.Dsl]
    ]
end
