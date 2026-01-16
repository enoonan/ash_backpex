# Getting Started with AshBackpex

This guide walks you through setting up AshBackpex to create an admin interface for your Ash resources.

## Prerequisites

- An existing Phoenix application with Ash Framework configured
- Backpex installed and configured (see [Backpex documentation](https://backpex.live/))
- At least one Ash resource you want to administer

## Installation

Add `ash_backpex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.1.0"}
  ]
end
```

Run `mix deps.get` to install the dependency.

## Creating Your First Admin LiveResource

### 1. Ensure You Have an Admin Layout

If you followed the [Backpex installation guide](https://hexdocs.pm/backpex), you should already have an admin layout configured. AshBackpex uses the same layout system as Backpex.

If you need to create a new admin layout, Backpex provides the `Backpex.HTML.Layout.app_shell/1` component as a foundation. Here's an example following Backpex conventions:

```elixir
# lib/my_app_web/components/layouts.ex
defmodule MyAppWeb.Layouts do
  use MyAppWeb, :html

  import Backpex.HTML.Layout

  attr :flash, :map, required: true
  attr :fluid?, :boolean, default: false
  attr :current_url, :string, required: true
  slot :inner_block, required: true

  def admin(assigns) do
    ~H"""
    <.app_shell fluid={@fluid?}>
      <:topbar>
        <.topbar_branding />
        <.topbar_dropdown>
          <:label>
            <div class="btn btn-square btn-ghost">
              <Backpex.HTML.CoreComponents.icon name="hero-user" class="size-6" />
            </div>
          </:label>
          <li>
            <.link href={~p"/"} class="flex justify-between hover:bg-base-200">
              <p>Back to App</p>
            </.link>
          </li>
        </.topbar_dropdown>
      </:topbar>
      <:sidebar>
        <.sidebar_item current_url={@current_url} navigate={~p"/admin/posts"}>
          <Backpex.HTML.CoreComponents.icon name="hero-document-text" class="size-5" /> Posts
        </.sidebar_item>
        <%!-- Add more sidebar items for your resources --%>
      </:sidebar>
      <.flash_messages flash={@flash} />
      {render_slot(@inner_block)}
    </.app_shell>
    """
  end
end
```

See the [Backpex layout documentation](https://hexdocs.pm/backpex/Backpex.HTML.Layout.html) for more details on available components and customization options.

### 2. Create a LiveResource

Create a LiveResource module that uses `AshBackpex.LiveResource`:

```elixir
# lib/my_app_web/live/admin/post_live.ex
defmodule MyAppWeb.Admin.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource MyApp.Blog.Post
    layout {MyAppWeb.Layouts, :admin}

    fields do
      field :title
      field :content do
        module Backpex.Fields.Textarea
      end
      field :published
      field :inserted_at
    end
  end
end
```

### 3. Add Routes

Add routes for your admin LiveResource:

```elixir
# lib/my_app_web/router.ex
scope "/admin", MyAppWeb.Admin do
  pipe_through [:browser]

  live "/posts", PostLive
end
```

### 4. Visit the Admin

Start your Phoenix server and visit `http://localhost:4000/admin/posts` to see your admin interface.

## Adding More Features

### Searchable Fields

Make fields searchable to enable the search box:

```elixir
fields do
  field :title do
    searchable true
  end
  field :content do
    searchable true
    module Backpex.Fields.Textarea
  end
end
```

### Relationships

Display relationships with navigation links:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  load [:author]  # Preload the relationship

  fields do
    field :title
    field :author do
      display_field :name
      live_resource MyAppWeb.Admin.UserLive
    end
  end
end
```

### Filters

Add filters to the index view:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}

  fields do
    field :title
    field :published
    field :status
  end

  filters do
    filter :published do
      module Backpex.Filters.Boolean
    end
    filter :status do
      module Backpex.Filters.Select
    end
  end
end
```

### Custom Sort Order

Set the default sort order:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  init_order %{by: :inserted_at, direction: :desc}

  fields do
    # ...
  end
end
```

### Panels for Form Organization

Organize form fields into panels:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}

  panels [
    content: "Content",
    settings: "Settings"
  ]

  fields do
    field :title do
      panel :content
    end
    field :content do
      panel :content
      module Backpex.Fields.Textarea
    end
    field :published do
      panel :settings
    end
    field :status do
      panel :settings
    end
  end
end
```

### Custom Display Names

Customize how resources are labeled:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  singular_name "Blog Post"
  plural_name "Blog Posts"

  fields do
    # ...
  end
end
```

### Custom Item Actions

Add or remove item actions:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}

  item_actions do
    strip_default [:delete]  # Remove delete action
    action :archive, MyApp.ItemActions.Archive
  end

  fields do
    # ...
  end
end
```

## Authorization

AshBackpex automatically integrates with Ash authorization policies. The admin will:

- Check `Ash.can?/2` before showing create/edit/delete buttons
- Use `assigns.current_user` as the actor for authorization checks

Make sure your Ash resources have policies defined and that you're setting `current_user` in your LiveView assigns.

## Next Steps

- See `AshBackpex.LiveResource.Dsl` for all available DSL options
- Check out the [Backpex documentation](https://backpex.live/) for field types and customization
- Look at the demo application in the `demo/` directory for more examples
