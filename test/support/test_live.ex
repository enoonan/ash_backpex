defmodule TestPostLive do
  @moduledoc false

  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestLayout, :admin})

    fields do
      field(:title)

      field :content do
        module(Backpex.Fields.Textarea)
      end

      field(:published)
      field(:published_at)
      field(:view_count)
      field(:rating)
      field(:tags)
      # field(:metadata)
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
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.User)
    layout({TestLayout, :admin})
  end
end

# LiveResource with custom names
defmodule TestCustomNamesLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestLayout, :admin})
    singular_name("Article")
    plural_name("Articles")
  end
end

# Test modules for layout and actions
defmodule TestLayout do
  @moduledoc false
  import Phoenix.Component

  def admin(assigns) do
    ~H"""
    <div><%= @inner_content %></div>
    """
  end
end
