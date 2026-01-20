defmodule TestPostLive do
  @moduledoc false

  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestLayout, :admin})

    fields do
      field(:title) do
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

defmodule TestItemLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Item)
    layout({TestLayout, :admin})

    fields do
      field :name do
        searchable(true)
      end

      field :note do
        searchable(true)
      end

      field :content do
        searchable(true)
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

# LiveResource for read-only resource (no update/destroy actions)
defmodule TestReadOnlyLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.ReadOnlyEntry)
    layout({TestLayout, :admin})

    item_actions do
      strip_default([:edit, :delete])
    end

    fields do
      field(:name)
    end
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

# Custom item action for testing can?/3 fallback
defmodule TestPromoteItemAction do
  @moduledoc false
  use BackpexWeb, :item_action

  @impl Backpex.ItemAction
  def icon(assigns, _item) do
    ~H"""
    <Backpex.HTML.CoreComponents.icon
      name="hero-arrow-up-circle"
      class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110 hover:text-success"
    />
    """
  end

  @impl Backpex.ItemAction
  def label(_assigns, _item), do: "Promote"

  @impl Backpex.ItemAction
  def handle(socket, _items, _data) do
    {:ok, socket}
  end
end

# LiveResource with custom item action for testing can?/3 fallback
defmodule TestCustomItemActionLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Item)
    layout({TestLayout, :admin})

    item_actions do
      action :promote, TestPromoteItemAction
    end

    fields do
      field(:name)
    end
  end
end

defmodule TestNonDefaultPrimaryKeyNameLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource AshBackpex.TestDomain.NonDefaultPrimaryKeyName
    layout({TestLayout, :admin})

    fields do
      field :foo_key
    end
  end
end

defmodule TestCustomItemActionLiveWithOnly do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Item)
    layout({TestLayout, :admin})

    item_actions do
      action :promote, TestPromoteItemAction, only: [:row]
    end

    fields do
      field(:name)
    end
  end
end

defmodule TestCustomItemActionLiveWithExcept do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Item)
    layout({TestLayout, :admin})

    item_actions do
      action :promote, TestPromoteItemAction, except: [:index]
    end

    fields do
      field(:name)
    end
  end
end

# LiveResource with derived filters (no explicit module)
defmodule TestDerivedFiltersLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestLayout, :admin})

    fields do
      field(:title)
      field(:published)
      field(:status)
    end

    filters do
      # Filter without module - should be derived from Ash attribute type
      filter(:published)
      filter(:status)
    end
  end
end

# LiveResource with explicit filter module override
defmodule TestExplicitFilterModuleLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestLayout, :admin})

    fields do
      field(:title)
      field(:published)
    end

    filters do
      # Explicit module should be preserved (uses Backpex filter, not AshBackpex)
      filter :published do
        module(Backpex.Filters.Boolean)
      end
    end
  end
end

# LiveResource with explicit AshBackpex filter module override (different from derived)
defmodule TestExplicitAshFilterModuleLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Post)
    layout({TestLayout, :admin})

    fields do
      field(:title)
      field(:view_count)
    end

    filters do
      # Explicit AshBackpex module should be preserved even when different from derived
      # view_count is Integer which would normally derive to Range filter,
      # but we explicitly override to use Boolean filter
      filter :view_count do
        module(AshBackpex.Filters.Boolean)
      end
    end
  end
end

# LiveResource with date filter for testing filter type derivation
defmodule TestDateFilterTypeLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Item)
    layout({TestLayout, :admin})

    fields do
      field(:name)
      field(:birth_date)
    end

    filters do
      # Date filter with explicit module (since derive_filter_module doesn't yet support date)
      # This tests that derive_filter_type returns :date for date attributes
      filter :birth_date do
        module(AshBackpex.Filters.Range)
      end
    end
  end
end

# LiveResource with datetime filter for testing filter type derivation
defmodule TestDatetimeFilterTypeLive do
  @moduledoc false
  use AshBackpex.LiveResource

  backpex do
    resource(AshBackpex.TestDomain.Item)
    layout({TestLayout, :admin})

    fields do
      field(:name)
      field(:created_at)
    end

    filters do
      # DateTime filter with explicit module (since derive_filter_module doesn't yet support datetime)
      # This tests that derive_filter_type returns :datetime for datetime attributes
      filter :created_at do
        module(AshBackpex.Filters.Range)
      end
    end
  end
end
