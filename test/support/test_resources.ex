defmodule AshBackpex.TestDomain.Post do
  @moduledoc false

  use Ash.Resource,
    domain: AshBackpex.TestDomain,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table("posts")
    repo(AshBackpex.TestRepo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, allow_nil?: false)
    attribute(:content, :string)
    attribute(:published, :boolean, default: false)
    attribute(:published_at, :datetime)
    attribute(:view_count, :integer, default: 0)
    attribute(:rating, :float)

    attribute(:tags, {:array, :string},
      default: [],
      constraints: [items: [match: ~r/^(food|entertainment|politics)$/]]
    )

    attribute(:metadata, :map, default: %{})
    attribute(:status, :atom, constraints: [one_of: [:draft, :published, :archived]])
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to(:author, AshBackpex.TestDomain.User)
    has_many(:comments, AshBackpex.TestDomain.Comment)
  end

  policies do
    policy action_type([:update, :destroy, :read]) do
      authorize_if relates_to_actor_via([:author])
    end

    policy action_type([:create, :read]) do
      authorize_if actor_attribute_equals(:active, true)
    end
  end

  calculations do
    calculate :word_count, :integer do
      calculation(fn records, _ ->
        Enum.map(records, fn record ->
          case record.content do
            nil -> 0
            content -> content |> String.split() |> length()
          end
        end)
      end)
    end
  end

  actions do
    defaults([:read, :update, :destroy])

    create :create do
      primary? true

      accept([
        :title,
        :content,
        :published,
        :published_at,
        :view_count,
        :rating,
        :tags,
        :metadata,
        :status,
        :author_id
      ])
    end
  end
end

defmodule AshBackpex.TestDomain.User do
  @moduledoc false

  use Ash.Resource,
    domain: AshBackpex.TestDomain,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("users")
    repo(AshBackpex.TestRepo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false)
    attribute(:email, :string, allow_nil?: false)
    attribute(:active, :boolean, default: true)
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many(:posts, AshBackpex.TestDomain.Post, destination_attribute: :author_id)
  end

  actions do
    defaults([:read, :update, :destroy])

    create :create do
      primary? true
      accept([:name, :email, :active])
    end
  end
end

defmodule AshBackpex.TestDomain.Comment do
  @moduledoc false

  use Ash.Resource,
    domain: AshBackpex.TestDomain,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("comments")
    repo(AshBackpex.TestRepo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:body, :string, allow_nil?: false)
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to(:post, AshBackpex.TestDomain.Post)
    belongs_to(:author, AshBackpex.TestDomain.User)
  end

  actions do
    defaults([:read, :update, :destroy])

    create :create do
      primary? true
      accept([:body, :post_id, :author_id])
    end
  end
end

defmodule AshBackpex.TestDomain.Item do
  @moduledoc false
  use Ash.Resource,
    domain: AshBackpex.TestDomain,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "items"
    repo(AshBackpex.TestRepo)
  end

  actions do
    defaults [:read, :destroy, create: [:name, :note], update: [:name, :note]]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :note, :string do
      public? true
    end

    attribute :view_count, :integer do
      public? true
    end
  end

  relationships do
    belongs_to(:user, AshBackpex.TestDomain.User)
  end

  aggregates do
    max :most_viewed, AshBackpex.TestDomain.Item, :view_count
  end

  calculations do
    calculate :name_note, :string, expr(name <> " " <> note)
  end
end
