defmodule Demo.Blog.Comment do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "comments"
    repo(Demo.Repo)
  end

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

    create_timestamp :inserted_at
    update_timestamp :updated_at
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
