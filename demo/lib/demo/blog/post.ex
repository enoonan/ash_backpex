defmodule Demo.Blog.Post do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "posts"
    repo(Demo.Repo)
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :content, :string do
      allow_nil? true
      public? true
    end

    attribute :rating, :integer do
      default 5
      public? true
      constraints min: 1, max: 5
    end

    attribute :published, :boolean do
      default false
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  calculations do
    calculate :word_count,
              :integer,
              expr(
                fragment(
                  "CASE
              WHEN ? IS NULL THEN 0
              WHEN length(trim(?)) = 0 THEN 0
              ELSE length(trim(?)) - length(replace(trim(?), ' ', '')) + 1
              END",
                  content,
                  content,
                  content,
                  content
                )
              ),
              public?: true
  end

  actions do
    default_accept [:title, :content, :published, :rating]
    defaults [:create, :read, :update, :destroy]
  end
end
