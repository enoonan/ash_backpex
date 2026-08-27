# Repeating Child Forms with InlineCRUD

`Backpex.Fields.InlineCRUD` renders repeated child forms. AshBackpex adds
move-up and move-down controls alongside Backpex's add and delete controls,
and supports the field as an opt-in for `has_many` relationships. The default
`Backpex.Fields.HasMany` selection UI remains unchanged.

The demo uses InlineCRUD to edit an article's comments directly in the article
form. Each comment has a body, author, sentiment, and approval status. The
complete working modules are
[`Demo.Blog.Post`](https://github.com/enoonan/ash_backpex/blob/main/demo/lib/demo/blog/post.ex),
[`Demo.Blog.Comment`](https://github.com/enoonan/ash_backpex/blob/main/demo/lib/demo/blog/comment.ex),
and
[`DemoWeb.PostLive`](https://github.com/enoonan/ash_backpex/blob/main/demo/lib/demo_web/live/post_live.ex).

## Define the Relationship

The parent resource exposes a `has_many` relationship:

```elixir
defmodule Demo.Blog.Post do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer

  relationships do
    has_many :comments, Demo.Blog.Comment
  end
end
```

The child resource needs create, update, and destroy actions appropriate for
the fields submitted by the repeated form. In the demo, `body`, `sentiment`,
`approved`, and `author_id` are editable:

```elixir
defmodule Demo.Blog.Comment do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
    end

    attribute :sentiment, :atom do
      allow_nil? false
      default :neutral
      public? true
      constraints one_of: [:positive, :neutral, :critical]
    end

    attribute :approved, :boolean do
      allow_nil? false
      default false
      public? true
    end
  end

  relationships do
    belongs_to :post, Demo.Blog.Post do
      allow_nil? false
    end

    belongs_to :author, Demo.Blog.Author do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:body, :sentiment, :approved, :post_id, :author_id]
    end

    update :update do
      primary? true
      accept [:body, :sentiment, :approved, :post_id, :author_id]
    end
  end
end
```

## Manage Comments in the Parent Actions

The parent create and update actions need an array-of-maps argument connected
to the relationship with `manage_relationship`. The demo uses dedicated admin
actions because its standard Post actions do not edit comments:

```elixir
defmodule Demo.Blog.Post do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer

  actions do
    create :admin_create do
      # Post attributes and other relationship arguments are omitted here.
      argument :comments, {:array, :map}, allow_nil?: true
      change manage_relationship(:comments, type: :direct_control)
    end

    update :admin_update do
      # Post attributes and other relationship arguments are omitted here.
      require_atomic? false
      argument :comments, {:array, :map}, allow_nil?: true
      change manage_relationship(:comments, type: :direct_control)
    end
  end
end
```

`:direct_control` creates new comments, updates comments whose primary keys are
present, and destroys existing comments omitted from the submitted list.

## Configure the LiveResource

Point the LiveResource at the actions above, load the relationship, then opt
the relationship field into InlineCRUD:

```elixir
defmodule DemoWeb.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource Demo.Blog.Post
    create_action :admin_create
    update_action :admin_update
    load [:author, :comments, :topic_tags, :audience_tags, :word_count, :comment_count]

    panels(
      content: "Content",
      publishing: "Publishing",
      relationships: "Relationships"
    )

    fields do
      field :comments do
        module Backpex.Fields.InlineCRUD
        except [:index]
        live_resource DemoWeb.CommentLive
        panel :relationships

        child_fields do
          field :body, Backpex.Fields.Textarea do
            label "Body"
            rows 3
            class "inline-crud-comment-body"
          end

          field :author do
            label "Author"
            display_field :name
            typeahead true
            typeahead_limit 10
            prompt "Choose an author"
            class "w-56"
          end

          field :sentiment do
            label "Sentiment"
            options Positive: :positive, Neutral: :neutral, Critical: :critical
            class "w-40"
          end

          field :approved do
            label "Approved"
            class "w-28"
          end
        end
      end
    end
  end
end
```

The demo gives the comment body its own row with two small CSS rules:

```css
.flex:has(> .inline-crud-comment-body) {
  flex-wrap: wrap;
}

.inline-crud-comment-body {
  flex: 0 0 100%;
}
```

The child DSL accepts the same field options as top-level fields. AshBackpex
derives child modules and relationship queries from the child resource, so the
author typeahead above resolves `Demo.Blog.Comment.author`, not a relationship
on the parent post. Explicit modules still override derivation, as shown by the
textarea. `live_resource DemoWeb.CommentLive` also lets Backpex link comments
to their show pages in the read-only view.

For an Ash `has_many` relationship, AshBackpex supplies InlineCRUD's required
`type: :assoc` option automatically. You can also set `type :assoc`
explicitly.

## Submitted Parameters

Backpex submits the repeated forms as an indexed map. It also provides:

- `comments_order[]`, which contains the submitted child indexes in UI order.
- `comments_delete[]`, which contains the indexes marked for deletion.
- `comments_move_up[]` or `comments_move_down[]`, which contains the index
  selected by a move control.
- A hidden `id` inside each persisted comment form.
- A hidden `_persistent_id` that keeps each LiveView form row stable while it
  moves.

AshBackpex applies a requested move, removes deleted entries, and converts the
remaining ordered entries into the list of maps expected by the Ash action. It
retains each hidden primary key so `manage_relationship` can distinguish an
update from a create.

The order controls preserve form order during submission. Persisting that order
after reloading is still part of the child resource model; add a position
attribute and set it from your child actions if the relationship needs durable
ordering.

## Recursive Embedded Configuration

The demo's article content composition is a compact, real recursive tree:
repeated sections contain repeated columns, and each column has one singular
target. Unlike relationship InlineCRUD, it needs no custom Backpex field or
`manage_relationship` change. Define each nested node as an Ash embedded
resource and accept the root attribute in the parent actions:

```elixir
defmodule Demo.Blog.ContentTarget do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :kind, :atom, public?: true, constraints: [one_of: [:internal, :external]]
    attribute :path, :string, public?: true
  end
end

defmodule Demo.Blog.ContentColumn do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :heading, :string, public?: true
    attribute :target, Demo.Blog.ContentTarget, public?: true
  end
end

defmodule Demo.Blog.ContentSection do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :title, :string, public?: true
    attribute :columns, {:array, Demo.Blog.ContentColumn}, default: [], public?: true
  end
end

defmodule Demo.Blog.Post do
  use Ash.Resource, domain: Demo.Blog, data_layer: AshSqlite.DataLayer

  attributes do
    attribute :sections, {:array, Demo.Blog.ContentSection}, default: [], public?: true
  end

  actions do
    create :admin_create do
      accept [:title, :sections]
    end

    update :admin_update do
      require_atomic? false
      accept [:title, :sections]
    end
  end
end
```

The embedded resources need `data_layer: :embedded`; they are attribute types,
not independently persisted records. The parent database column stores the
tree, and both create and update actions must accept the root `:sections`
attribute. Add the equivalent column through your Ash data-layer migration.

Configure the root field in the parent LiveResource. This is the complete DSL
shape used by the demo:

```elixir
field :sections do
  module Backpex.Fields.InlineCRUD

  child_fields do
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

AshBackpex infers `type: :embed` for both repeated embedded nodes and derives
every child field from the resource at that depth. Relationship InlineCRUD
remains limited to `has_many` and continues to infer `type: :assoc`; use the
normal relationship field for other relationship cardinalities.

## Embedded Parameters, Validation, and Empty Lists

The browser sends repeated fields as indexed maps, with controls at each
repeated level. For example, a section with one column normalizes to the Ash
attribute shape below; the `*_order`, `*_delete`, and `*_move_*` keys are form
controls and do not reach the Ash action:

```elixir
%{
  "sections" => [
    %{
      "title" => "Hero",
      "columns" => [
        %{
          "heading" => "Welcome",
          "target" => %{"kind" => "internal", "path" => "/welcome"}
        }
      ]
    }
  ]
}
```

AshBackpex applies moves and deletes, then turns every repeated indexed map
into its ordered list form before calling the parent create or update action.
A singular embedded node stays a map. An empty repeated node is normalized to
`[]`, so `default: []` on embedded array attributes is important and an empty
section or an empty root list remains editable after a validation rerender.

Each repeated node renders its own add, delete, move-up, and move-down controls.
Control names are derived from the current nested form, so validation events
operate on only that node while preserving persistent row identities and the
submitted order. Singular embedded nodes render a fieldset and pass their
immediate Phoenix form to child visibility, authorization, readonly, label,
help-text, and error translation callbacks.

When Ash rejects a nested value, its error is reconstructed at the submitted
array index and singular-field path on the next render. Keep the hidden
`_persistent_id` values emitted by the form: they give unsaved rows stable
LiveView identity while users add, delete, reorder, and correct invalid values.
Ordering controls only determine the submitted list order; persist a position
attribute in your own model if that order must survive a later reload.

Recursive embeds compose with relationship InlineCRUD. A parent can retain a
`has_many` relationship field configured with `type: :assoc` and
`manage_relationship`, alongside embedded fields configured with `type: :embed`.
They normalize independently at each repeated depth.

This support is for typed embedded resources and ordinary fields. Conditional
union or variant-specific forms remain outside this configuration model.
