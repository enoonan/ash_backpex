defmodule Demo.Blog.PostTag do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "post_tags"
    repo(Demo.Repo)
  end

  relationships do
    belongs_to :post, Demo.Blog.Post do
      primary_key? true
      allow_nil? false
    end

    belongs_to :tag, Demo.Blog.Tag do
      primary_key? true
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:post_id, :tag_id]
    end
  end
end
