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
  end
end
