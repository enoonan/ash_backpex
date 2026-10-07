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
    {:ash_backpex, "~> 0.3.4"}
  ]
end
```

Run `mix deps.get` to install the dependency.

AshBackpex targets Backpex `~> 0.22.0` and declares that dependency itself. If
your application pins Backpex directly, update its constraint to match.

> #### Upgrading an existing admin? {: .warning}
>
> AshBackpex 0.2 and 0.3 each follow a Backpex release with breaking changes.
> Read [Upgrading to 0.3](upgrading-to-0.3.md) before you bump the dependency.

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
  attr :socket, :any, required: true
  attr :current_theme, :string, required: true
  attr :sidebar_open, :boolean, required: true
  attr :sidebar_section_states, :map, required: true
  attr :preferences_manifest, :map, required: true
  slot :inner_block, required: true

  def admin(assigns) do
    ~H"""
    <.app_shell
      socket={@socket}
      fluid={@fluid?}
      sidebar_open={@sidebar_open}
      preferences_manifest={@preferences_manifest}
    >
      <:sidebar_branding>
        <.sidebar_branding title="My App" />
      </:sidebar_branding>
      <:topbar>
        <.theme_selector
          current_theme={@current_theme}
          themes={[{"Light", "light"}, {"Dark", "dark"}]}
        />
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
        <.sidebar_section id="blog" sidebar_section_states={@sidebar_section_states}>
          <:label>Blog</:label>
          <.sidebar_item current_url={@current_url} navigate={~p"/admin/posts"}>
            <Backpex.HTML.CoreComponents.icon name="hero-document-text" class="size-5" /> Posts
          </.sidebar_item>
          <%!-- Add more sidebar items for your resources --%>
        </.sidebar_section>
      </:sidebar>
      <.flash_messages flash={@flash} />
      {render_slot(@inner_block)}
    </.app_shell>
    """
  end
end
```

`Backpex.InitAssigns` assigns `@current_theme`, `@sidebar_open`,
`@sidebar_section_states`, and `@preferences_manifest`; the layout passes them
on. Two details of `sidebar_section/1` are easy to miss:

- `id` is required and must be unique among your sections. Backpex stores each
  section's open state under it. Use only letters, digits, underscores, and
  hyphens.
- `sidebar_section_states` must be passed explicitly. A function component does
  not inherit the surrounding assign, so a section without it always renders
  open and a collapsed section does not stay collapsed.

Use the server-assigned theme in your root layout:

```heex
<html data-theme={assigns[:current_theme] || "light"}>
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
import Backpex.Router

scope "/admin", MyAppWeb.Admin do
  pipe_through [:browser]

  backpex_routes()

  live_session :backpex_admin,
    on_mount: [{MyAppWeb.LiveUserAuth, :require_admin}, Backpex.InitAssigns] do
    live_resources "/posts", PostLive
  end
end
```

Put your authentication hook first. It must assign `current_user`, and halt the
mount for anyone who may not use the admin:

```elixir
# lib/my_app_web/live_user_auth.ex
defmodule MyAppWeb.LiveUserAuth do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:require_admin, _params, session, socket) do
    socket = assign_new(socket, :current_user, fn -> load_user(session) end)

    if admin?(socket.assigns.current_user) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/sign-in")}
    end
  end

  # load_user/1 and admin?/1 depend on how your application authenticates.
end
```

The order matters for two reasons. AshBackpex uses `assigns.current_user` as the
Ash actor, so it has to be there before the LiveResource mounts. And
`Backpex.InitAssigns` reads the user's stored preferences using whatever the
authentication hook assigned, so it has to run after it. If you use
AshAuthentication or `mix phx.gen.auth`, use the `on_mount` hook they provide in
place of `MyAppWeb.LiveUserAuth`.

### 4. Wire Up the Browser

Backpex sends the browser's stored preferences with the LiveView connection.
Wrap your connect params with `backpexParams` in `assets/js/app.js`:

```javascript
import { Hooks as BackpexHooks, backpexParams } from "backpex";

const liveSocket = new LiveSocket("/live", Socket, {
  params: backpexParams({ _csrf_token: csrfToken }),
  hooks: { ...BackpexHooks },
});
```

Without it, the theme, sidebar, and column choices revert when the user
navigates to another resource, and Backpex logs a console warning.

### 5. Visit the Admin

Start your Phoenix server and visit `http://localhost:4000/admin/posts` to see your admin interface.

### Admin Pages That Are Not Resources

A dashboard or any other LiveView can use the same admin layout. Route it inside
the same `live_session`, so both hooks run for it:

```elixir
live_session :backpex_admin,
  on_mount: [{MyAppWeb.LiveUserAuth, :require_admin}, Backpex.InitAssigns] do
  live "/", DashboardLive
  live_resources "/posts", PostLive
end
```

A LiveResource hands every assign to the layout for you. Your own LiveView has
to pass them itself:

```elixir
# lib/my_app_web/live/admin/dashboard_live.ex
defmodule MyAppWeb.Admin.DashboardLive do
  use MyAppWeb, :live_view

  def render(assigns) do
    ~H"""
    <MyAppWeb.Layouts.admin
      socket={@socket}
      flash={@flash}
      current_url={@current_url}
      current_theme={@current_theme}
      sidebar_open={@sidebar_open}
      sidebar_section_states={@sidebar_section_states}
      preferences_manifest={@preferences_manifest}
    >
      <h1 class="text-2xl font-semibold">Dashboard</h1>
    </MyAppWeb.Layouts.admin>
    """
  end
end
```

`socket`, `sidebar_open`, `sidebar_section_states`, and `preferences_manifest`
are the ones Backpex 0.20 added, and the ones an older dashboard will be
missing. The layout above requires all of them, so the page raises a `KeyError`
when one is left out.

Link to the page from the layout's `<:sidebar>` slot with another
`sidebar_item`.

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

### Persisted Index State

Persistence is opt-in, and the default is to persist nothing. Choose which index
settings should survive navigation and reloads:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  persist [:order, :filters, :columns, :metrics]

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

- Check `Ash.can?/2` before showing create/edit/delete buttons, and again
  before every create, update, delete, and item action
- Use `assigns.current_user` as the actor for reads and relationship options
- Persist create and update changesets with their configured actor

Make sure your Ash resources have policies defined and that you're setting
`current_user` in your LiveView assigns. If you provide custom create or update
changeset functions, set that actor on the returned Ash changeset.

Policies are for rules that depend on who is asking. When the admin should not
offer an operation to anyone, turn it off in the LiveResource instead:

```elixir
backpex do
  resource MyApp.Audit.Event
  layout {MyAppWeb.Layouts, :admin}

  create_action false   # no "New" button, and :new is denied
  update_action false   # no editing
  destroy_action false  # no deleting
end
```

Do this even if you also route the resource with `except: [:new]`. Backpex shows
the "New" button on an empty index page whenever `:new` is allowed, without
looking at the routes, and the page raises when the route is missing.

Do not define `can?/3` in the LiveResource. AshBackpex generates it, and
defining it is a compile error.

Deleting is authorized per record: Backpex checks the destroy action's policies
for every selected record, as the current user, before anything is deleted.
Backpex does not hand the actor to the delete callback itself, so the destroy
action then runs without one. A change or notifier on that action that reads the
actor (an audit trail, for example) will not see it.

## Next Steps

- See `AshBackpex.LiveResource.Dsl` for all available DSL options
- Check out the [Backpex documentation](https://backpex.live/) for field types and customization
- Look at the demo application in the `demo/` directory for more examples
