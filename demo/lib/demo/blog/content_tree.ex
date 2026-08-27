defmodule Demo.Blog.ContentTarget do
  @moduledoc """
  A singular destination embedded in an article content column.
  """

  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :kind, :atom, public?: true, constraints: [one_of: [:internal, :external]]
    attribute :path, :string, public?: true
  end
end

defmodule Demo.Blog.ContentColumn do
  @moduledoc """
  A repeatable embedded column in an article content section.
  """

  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :heading, :string, public?: true
    attribute :target, Demo.Blog.ContentTarget, public?: true
  end
end

defmodule Demo.Blog.ContentSection do
  @moduledoc """
  A repeatable embedded content section for the recursive form demo.
  """

  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :title, :string, public?: true
    attribute :columns, {:array, Demo.Blog.ContentColumn}, default: [], public?: true
  end
end
