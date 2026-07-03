defmodule Demo.Blog do
  use Ash.Domain

  resources do
    resource Demo.Blog.Author
    resource Demo.Blog.Comment
    resource Demo.Blog.Post
    resource Demo.Blog.PostTag
    resource Demo.Blog.Tag
  end
end
