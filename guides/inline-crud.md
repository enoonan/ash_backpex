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

          field :author, Backpex.Fields.BelongsTo do
            label "Author"
            display_field :name
            class "w-56"
          end

          field :sentiment, Backpex.Fields.Select do
            label "Sentiment"
            options Positive: :positive, Neutral: :neutral, Critical: :critical
            class "w-40"
          end

          field :approved, Backpex.Fields.Boolean do
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

The child DSL accepts the same field options as top-level fields. This example
uses a textarea, a relationship selector, a constrained select, and a boolean
field. `live_resource DemoWeb.CommentLive` also lets Backpex link comments to
their show pages in the read-only view.

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

## Limitations

Backpex does not support an `InlineCRUD` child field inside another
`InlineCRUD`. Use InlineCRUD for one repeated relationship level and a custom
field or dedicated editor for a nested repeater.
