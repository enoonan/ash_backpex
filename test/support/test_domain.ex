defmodule TestDomain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource(TestDomain.Post)
    resource(TestDomain.User)
    resource(TestDomain.Comment)
  end
end
