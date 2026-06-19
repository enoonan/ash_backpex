defmodule Demo.Blog.Author do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "authors"
    repo(Demo.Repo)
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :role, :atom do
      allow_nil? false
      default :contributor
      public? true
      constraints one_of: [:admin, :editor, :contributor]
    end

    attribute :active, :boolean do
      allow_nil? false
      default true
      public? true
    end

    attribute :bio, :string do
      public? true
    end

    attribute :joined_on, :date do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :posts, Demo.Blog.Post
    has_many :comments, Demo.Blog.Comment
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :email, :role, :active, :bio, :joined_on]
    end

    update :update do
      primary? true
      accept [:name, :email, :role, :active, :bio, :joined_on]
    end
  end
end
