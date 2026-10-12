# LiveResources mounted by the filter badge tests. Backpex renders a filter badge
# with the render context and the value only, without the filter's field, so each
# fixture covers one shape of that context or of the filter options.
defmodule TestFilterBadgeLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestIndexEditLayout, :admin})
    pubsub(server: AshBackpex.TestPubSub)

    fields do
      field(:title)
    end

    filters do
      filter :status do
        module(AshBackpex.Filters.Select)
        options(fn _assigns -> [{"Draft", :draft}, {"Published", :published}] end)
      end

      filter :tags do
        module(AshBackpex.Filters.MultiSelect)
        options(fn _assigns -> [{"Food", :food}, {"Politics", :politics}] end)
      end
    end
  end
end

# With a list of context assigns the badge receives no `:filters` assign.
defmodule TestFilterBadgeContextKeysLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestIndexEditLayout, :admin})
    pubsub(server: AshBackpex.TestPubSub)
    context_assigns([])

    fields do
      field(:title)
    end

    filters do
      filter :status do
        module(AshBackpex.Filters.Select)
        options(fn _assigns -> [{"Draft", :draft}, {"Published", :published}] end)
      end

      filter :tags do
        module(AshBackpex.Filters.MultiSelect)
        options(fn _assigns -> [{"Food", :food}, {"Politics", :politics}] end)
      end
    end
  end
end

# Module and options derived from the `one_of` constraints of the Post resource.
defmodule TestFilterBadgeDerivedLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestIndexEditLayout, :admin})
    pubsub(server: AshBackpex.TestPubSub)

    fields do
      field(:title)
    end

    filters do
      filter(:status)
      filter(:tags)
    end
  end
end

# Two filters list the value "draft" with different labels.
defmodule TestFilterBadgeSharedValueLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestIndexEditLayout, :admin})
    pubsub(server: AshBackpex.TestPubSub)

    fields do
      field(:title)
    end

    filters do
      filter :status do
        module(AshBackpex.Filters.Select)
        options([{"Draft status", "draft"}])
      end

      filter :title do
        module(AshBackpex.Filters.Select)
        options([{"Draft title", "draft"}])
      end
    end
  end
end
