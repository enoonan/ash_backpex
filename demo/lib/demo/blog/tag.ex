defmodule Demo.Blog.Tag do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "tags"
    repo(Demo.Repo)
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :type, :atom do
      allow_nil? false
      default :topic
      public? true
      constraints one_of: [:topic, :audience]
    end

    attribute :description, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :posts, Demo.Blog.Post do
      through Demo.Blog.PostTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :post_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :slug, :type, :description]
    end

    update :update do
      primary? true
      accept [:name, :slug, :type, :description]
    end
  end
end
