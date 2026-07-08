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

    attribute :slug, :string do
      allow_nil? false
      default "untitled"
      public? true
    end

    attribute :content, :string do
      allow_nil? true
      public? true
    end

    attribute :excerpt, :string do
      allow_nil? true
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :draft
      public? true
      constraints one_of: [:draft, :review, :published, :archived]
    end

    attribute :rating, :integer do
      default 5
      public? true
      constraints min: 1, max: 5
    end

    attribute :featured, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :published, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :published_on, :date do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :author, Demo.Blog.Author

    has_many :comments, Demo.Blog.Comment

    many_to_many :tags, Demo.Blog.Tag do
      through Demo.Blog.PostTag
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :tag_id
    end

    many_to_many :topic_tags, Demo.Blog.Tag do
      through Demo.Blog.PostTag
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :tag_id
      filter expr(type == :topic)
      sort name: :asc
    end

    many_to_many :audience_tags, Demo.Blog.Tag do
      through Demo.Blog.PostTag
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :tag_id
      filter expr(type == :audience)
      sort name: :asc
    end
  end

  calculations do
    calculate :comment_count,
              :integer,
              fn records, _context ->
                Enum.map(records, fn record ->
                  case record.comments do
                    %Ash.NotLoaded{} -> 0
                    comments when is_list(comments) -> length(comments)
                    _ -> 0
                  end
                end)
              end,
              load: [:comments],
              public?: true

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
    default_accept [
      :title,
      :slug,
      :content,
      :excerpt,
      :status,
      :published,
      :published_on,
      :featured,
      :rating,
      :author_id
    ]

    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :title,
        :slug,
        :content,
        :excerpt,
        :status,
        :published,
        :published_on,
        :featured,
        :rating,
        :author_id
      ]

      argument :topic_tags, {:array, :uuid}, allow_nil?: true
      argument :audience_tags, {:array, :uuid}, allow_nil?: true

      change manage_relationship(:topic_tags, type: :append_and_remove)
      change manage_relationship(:audience_tags, type: :append_and_remove)
    end

    create :admin_create do
      accept [
        :title,
        :slug,
        :content,
        :excerpt,
        :status,
        :published,
        :published_on,
        :featured,
        :rating,
        :author_id
      ]

      argument :topic_tags, {:array, :uuid}, allow_nil?: true
      argument :audience_tags, {:array, :uuid}, allow_nil?: true

      change manage_relationship(:topic_tags, type: :append_and_remove)
      change manage_relationship(:audience_tags, type: :append_and_remove)
    end

    update :update do
      primary? true

      accept [
        :title,
        :slug,
        :content,
        :excerpt,
        :status,
        :published,
        :published_on,
        :featured,
        :rating,
        :author_id
      ]

      require_atomic? false
      argument :topic_tags, {:array, :uuid}, allow_nil?: true
      argument :audience_tags, {:array, :uuid}, allow_nil?: true

      change manage_relationship(:topic_tags, type: :append_and_remove)
      change manage_relationship(:audience_tags, type: :append_and_remove)
    end

    update :admin_update do
      accept [
        :title,
        :slug,
        :content,
        :excerpt,
        :status,
        :published,
        :published_on,
        :featured,
        :rating,
        :author_id
      ]

      require_atomic? false
      argument :topic_tags, {:array, :uuid}, allow_nil?: true
      argument :audience_tags, {:array, :uuid}, allow_nil?: true

      change manage_relationship(:topic_tags, type: :append_and_remove)
      change manage_relationship(:audience_tags, type: :append_and_remove)
    end
  end
end
