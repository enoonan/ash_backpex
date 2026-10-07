defmodule AshBackpex.TestDomain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource AshBackpex.TestDomain.Post do
      define :create_post, action: :create
    end

    resource(AshBackpex.TestDomain.User)
    resource(AshBackpex.TestDomain.Comment)
    resource(AshBackpex.TestDomain.Item)
    resource(AshBackpex.TestDomain.AggregateItem)
    resource(AshBackpex.TestDomain.ReadOnlyEntry)
    resource(AshBackpex.TestDomain.RichTextEntry)
    resource AshBackpex.TestDomain.NonDefaultPrimaryKeyName
    resource AshBackpex.TestDomain.ManyToManyPost
    resource AshBackpex.TestDomain.ManyToManyCategory
    resource AshBackpex.TestDomain.ManyToManyPostCategory
    resource AshBackpex.TestDomain.EmbeddedPage
    resource AshBackpex.TestDomain.Assignment
  end
end
