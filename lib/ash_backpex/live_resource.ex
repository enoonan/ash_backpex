defmodule AshBackpex.LiveResource do
  @moduledoc """
  The primary entry point to AshBackpex.

  ```elixir
  defmodule MyAppWeb.Live.PostLive do
    use AshBackpex.Live

    backpex do
      resource MyApp.Blog.Post
      load [:author, :comments]
      fields do
        field :title, Backpex.Fields.Text
        field :author, Backpex.Fields.BelongsTo
        field :comments, Backpex.Fields.HasMany, only: [:show]
      end
      singular_label "Post"
      plural_label "Posts"
    end
  end
  ```
  """
  use Spark.Dsl,
    default_extensions: [
      extensions: [AshBackpex.LiveResource.Dsl]
    ]
end
