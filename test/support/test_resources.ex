defmodule TestDomain.Post do
  use Ash.Resource,
    domain: TestDomain,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("posts")
    repo(TestRepo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, allow_nil?: false)
    attribute(:content, :string)
    attribute(:published, :boolean, default: false)
    attribute(:published_at, :datetime)
    attribute(:view_count, :integer, default: 0)
    attribute(:rating, :float)
    attribute(:tags, {:array, :string}, default: [])
    attribute(:metadata, :map, default: %{})
    attribute(:status, :atom, constraints: [one_of: [:draft, :published, :archived]])
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to(:author, TestDomain.User)
    has_many(:comments, TestDomain.Comment)
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
    defaults([:create, :read, :update, :destroy])
  end
end

defmodule TestDomain.User do
  use Ash.Resource,
    domain: TestDomain,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("users")
    repo(TestRepo)
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
    has_many(:posts, TestDomain.Post, destination_attribute: :author_id)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end
end

defmodule TestDomain.Comment do
  use Ash.Resource,
    domain: TestDomain,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("comments")
    repo(TestRepo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:body, :string, allow_nil?: false)
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to(:post, TestDomain.Post)
    belongs_to(:author, TestDomain.User)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end
end

# Test LiveResource modules that will be used in tests
defmodule TestPostLive do
  use AshBackpex.LiveResource

  backpex do
    resource(TestDomain.Post)
    layout({TestLayout, :admin})

    fields do
      field :title do
        searchable(true)
      end

      field :content do
        module(Backpex.Fields.Textarea)
      end

      field(:published)
      field(:published_at)
      field(:view_count)
      field(:rating)
      field(:tags)
      field(:metadata)
      field(:status)
      field(:author)
      field(:word_count)
    end

    filters do
      filter :published do
        module(Backpex.Filters.Boolean)
      end
    end
  end
end

# Minimal LiveResource for basic tests
defmodule TestMinimalLive do
  use AshBackpex.LiveResource

  backpex do
    resource(TestDomain.User)
    layout({TestLayout, :admin})
  end
end

# LiveResource with custom names
defmodule TestCustomNamesLive do
  use AshBackpex.LiveResource

  backpex do
    resource(TestDomain.Post)
    layout({TestLayout, :admin})
    singular_name("Article")
    plural_name("Articles")
  end
end

# Test modules for layout and actions
defmodule TestLayout do
  import Phoenix.Component

  def admin(assigns) do
    ~H"""
    <div><%= @inner_content %></div>
    """
  end
end
