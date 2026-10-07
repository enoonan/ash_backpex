# LiveResources for the `context_assigns` option of the backpex section
defmodule TestContextAssignsListLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestLayout, :admin})
    context_assigns([:locale])

    fields do
      field(:title)
    end
  end
end

defmodule TestContextAssignsCurrentUserLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.User)
    layout({TestLayout, :admin})
    context_assigns([:current_user, :locale])
  end
end

defmodule TestContextAssignsAllLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.User)
    layout({TestLayout, :admin})
    context_assigns(:all)
  end
end
