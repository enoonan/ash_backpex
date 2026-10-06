# Upgrading to 0.3

AshBackpex 0.2 and 0.3 each follow a Backpex release that changes how an admin
is wired together. Expect this upgrade to take longer than the ones before it:

| You are on | AshBackpex changes | Backpex changes |
| --- | --- | --- |
| 0.1.x | Everything in this guide | 0.19 → 0.21 |
| 0.2.x | [From 0.2 to 0.3](#from-0-2-to-0-3) | 0.20 → 0.21 |

0.3.0 and 0.3.1 were tagged on GitHub but not published to Hex. Install the
latest 0.3 release.

What to expect:

- The application may stop compiling. Defining `can?/3`, `fields/0`,
  `filters/0`, `item_actions/1`, or `layout/1` in a LiveResource is now a compile
  error. [Each one has a fix](#callbacks-that-are-now-compile-errors).
- Pages that compile may still raise. From 0.1, the admin layout has to change
  before any page renders. From either version, a LiveResource routed with
  `except: [:new]` raises on an empty index page until you set
  [`create_action false`](#the-new-button-on-an-empty-index-page).
- Access rules written in `can?/3` never ran. If a LiveResource defined one, its
  rule was not being enforced, and you have to decide where it belongs now.

## Update the dependencies

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.3.2"}
  ]
end
```

AshBackpex declares its own dependency on Backpex `~> 0.21.0`. If your
application also lists `:backpex`, change that constraint to match.

```bash
mix deps.update ash_backpex backpex
```

### If Ash moves to 3.33 or later

AshBackpex accepts any Ash 3 release, so this upgrade does not need a newer Ash.
If you update Ash at the same time, for example with `mix deps.update --all`,
and it reaches 3.33 or later, Ash refuses to compile resources until you tell it
how to count string lengths:

```elixir
# config/config.exs

# Keeps the behavior your application has today.
config :ash, default_string_length_count: :mixed

# What Ash recommends, and what new applications get.
# config :ash, default_string_length_count: :codepoints
```

See
[Ash's backwards compatibility config](https://hexdocs.pm/ash/backwards-compatibility-config.html#default_string_length_count)
for the difference. This is an Ash requirement, not an AshBackpex one; it is
here because the two upgrades tend to arrive together.

## From 0.1 to 0.2

AshBackpex 0.2 requires Backpex 0.20, which replaced its cookie-based UI state
with a preference system and gave the app shell a collapsible sidebar. Work
through Backpex's own
[Upgrading to v0.20](https://hexdocs.pm/backpex/v0-20.html) guide; it is the
authority. The steps below are the ones every AshBackpex application hits, and
the [getting-started guide](getting-started.md) shows the finished result.

### Router

Remove `plug Backpex.ThemeSelectorPlug`; it no longer exists. `backpex_routes()`
is now required, because the app shell looks up the preferences route on every
render.

Run your authentication hook before `Backpex.InitAssigns`:

```elixir
live_session :backpex_admin,
  on_mount: [{MyAppWeb.LiveUserAuth, :require_admin}, Backpex.InitAssigns] do
  live_resources "/posts", PostLive
end
```

`Backpex.InitAssigns` now reads the user's stored preferences, using whatever
your authentication hook assigned. It has to run second.

### app.js

Wrap your LiveSocket connect params with `backpexParams`:

```diff
- import { Hooks as BackpexHooks } from "backpex";
+ import { Hooks as BackpexHooks, backpexParams } from "backpex";

  const liveSocket = new LiveSocket("/live", Socket, {
-   params: { _csrf_token: csrfToken },
+   params: backpexParams({ _csrf_token: csrfToken }),
    hooks: { ...BackpexHooks },
  });
```

Nothing fails without it. The theme, sidebar, and column choices revert when the
user navigates to another resource, and Backpex logs a console warning.

### Root layout

```diff
- <html data-theme={assigns[:theme] || "light"}>
+ <html data-theme={assigns[:current_theme] || "light"}>
```

### Admin layout

`app_shell` now requires `socket`. The branding moved from the top bar into a
`<:sidebar_branding>` slot, and `topbar_branding` was renamed to
`sidebar_branding`. The theme selector takes `current_theme` instead of
`socket`.

```diff
  <Backpex.HTML.Layout.app_shell
+   socket={@socket}
    fluid={@fluid?}
+   sidebar_open={@sidebar_open}
+   preferences_manifest={@preferences_manifest}
  >
    <:topbar>
-     <Backpex.HTML.Layout.topbar_branding />
-     <Backpex.HTML.Layout.theme_selector socket={@socket} themes={...} />
+     <Backpex.HTML.Layout.theme_selector current_theme={@current_theme} themes={...} />
    </:topbar>
+   <:sidebar_branding>
+     <Backpex.HTML.Layout.sidebar_branding />
+   </:sidebar_branding>
    <:sidebar>
-     <Backpex.HTML.Layout.sidebar_section id="blog">
+     <Backpex.HTML.Layout.sidebar_section
+       id="blog"
+       sidebar_section_states={@sidebar_section_states}
+     >
        <:label>Blog</:label>
      </Backpex.HTML.Layout.sidebar_section>
    </:sidebar>
  </Backpex.HTML.Layout.app_shell>
```

`sidebar_open` and `preferences_manifest` have defaults, so the layout renders
without them, but the sidebar forgets whether it was open.

### Sidebar sections

Every `sidebar_section` needs two attributes:

- `id`, which is now required and must be unique. Backpex stores each section's
  open state under it, so two sections with the same id toggle together. Use
  only letters, digits, underscores, and hyphens.
- `sidebar_section_states={@sidebar_section_states}`. It is not inherited from
  the surrounding assigns. A section without it always renders open, and a
  collapsed section does not stay collapsed.

### Admin pages that are not resources

A LiveResource hands every assign to your layout. A LiveView of your own that
renders the admin layout, such as a dashboard, has to pass the new ones itself:

```elixir
<MyAppWeb.Layouts.admin
  socket={@socket}
  flash={@flash}
  current_url={@current_url}
  current_theme={@current_theme}
  sidebar_open={@sidebar_open}
  sidebar_section_states={@sidebar_section_states}
  preferences_manifest={@preferences_manifest}
>
  ...
</MyAppWeb.Layouts.admin>
```

`Backpex.InitAssigns` assigns all of them, so the page must be routed in a
`live_session` that mounts it.

### `persist` is opt-in

Backpex 0.19 remembered column and metric visibility for every resource. Backpex
0.20 remembers nothing unless the resource asks. To keep the old behavior, add
`persist` to each LiveResource:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  persist [:columns, :metrics]
end
```

`:order` and `:filters` can be persisted the same way. There is no project-wide
default; each resource opts in.

Existing choices are not carried over. After the upgrade every user starts with
the default theme, columns, and open sidebar sections.

## From 0.2 to 0.3

AshBackpex 0.3 requires Backpex 0.21, which enforces `can?/3` everywhere instead
of leaving it to each caller.

### Callbacks that are now compile errors

AshBackpex generates `can?/3`, `fields/0`, `filters/0`, `item_actions/1`, and
`layout/1` from the `backpex` block, and it generates them after your module
body. In every earlier version a definition of your own was silently replaced:
it compiled, and it never ran. It is now a compile error, which names the
function, the file, and the line:

```text
MyAppWeb.PostLive defines can?/3 (lib/my_app_web/live/post_live.ex:13),
but AshBackpex generates can?/3 for every LiveResource.
```

Do not delete the function until you know what it was for. It records a rule
somebody wanted, and that rule has not been in force.

| Function | What to do |
| --- | --- |
| `can?/3` | See below |
| `fields/0` | Declare the fields in the `fields` section |
| `filters/0` | Declare the filters in the `filters` section |
| `item_actions/1` | Use `action` and `strip_default` in the `item_actions` section |
| `layout/1` | Set the `layout` option |

For `can?/3`, read each clause and ask which of two things it says.

**"This admin does not offer create, edit, or delete."** The clause returns
`false` for `:new`, `:edit`, or `:delete` whoever is asking. Turn the action off
in the `backpex` block:

```diff
  defmodule MyAppWeb.Admin.EventLive do
    use AshBackpex.LiveResource

    backpex do
      resource MyApp.Audit.Event
      layout {MyAppWeb.Layouts, :admin}
+     create_action false
+     update_action false
+     destroy_action false
    end
-
-   def can?(_assigns, action, _item) when action in [:new, :edit, :delete], do: false
-   def can?(_assigns, _action, _item), do: true
  end
```

The generated `can?/3` then denies that operation without consulting Ash. The
resource keeps its actions, so the rest of the application is unaffected.

**"It depends on who is asking, or on the record."** Write the rule as an Ash
policy on the resource. The generated `can?/3` checks policies with
`assigns.current_user` as the actor:

| Backpex asks about | Ash action checked |
| --- | --- |
| `:new` | the create action |
| `:index`, `:show` | the read action |
| `:edit` | the update action |
| `:delete` | the destroy action |
| anything else | the Ash action with that name, if there is one; otherwise allowed |

A policy applies everywhere the resource is used, not only in the admin. If the
rule is about the admin alone, give the admin its own action with
`create_action`, `update_action`, or `destroy_action` and put the policy on
that.

Other Backpex callbacks (`on_item_updated/2`, `return_to/5`, `form_actions/2`,
`index_row_class/4`, and so on) can still be defined in the module. See
"Defining Backpex Callbacks" in `AshBackpex.LiveResource`.

### The New button on an empty index page

Backpex shows a "New" button on an empty index page whenever
`can?(assigns, :new, nil)` is true. It does not look at the routes. A
LiveResource routed without `:new` therefore raises as soon as its table is
empty, which is easy to miss in development and easy to hit in a new
environment:

```elixir
live_resources "/events", EventLive, except: [:new, :edit]
```

Set `create_action false` in that LiveResource. Do it for every resource routed
with `except: [:new]`, not only the ones that crash today.

### Backpex now enforces `can?/3` centrally

In Backpex 0.20, authorization was checked where the interface asked for it. In
0.21, `Backpex.Resource` checks `can?/3` before every insert, update,
`update_all`, and `delete_all`, and item actions re-read the selected records as
the current user before they run. LiveResources need no change for this. Code
that calls Backpex directly does:

- `Backpex.Resource.delete_all/4` used to take two arguments, and
  `Backpex.Resource.update_all/5` three or four. Pass `socket.assigns`, and move
  `event_name` into the options.
- Item actions are strict. A selection containing a record the user may not act
  on raises `Backpex.ForbiddenError` instead of skipping it. A record that was
  deleted, or that the user can no longer read, raises `Backpex.NoResultsError`.
  `handle/3` is never called with an empty list.
- A custom item action that writes the records it was handed through
  `Backpex.Resource` should pass `authorize?: false`. Backpex has already
  authorized them.

An item action that writes through your own domain functions instead of
`Backpex.Resource` needs no code change; the strict checks still apply to its
selection. Backpex's [Upgrading to v0.21](https://hexdocs.pm/backpex/v0-21.html) guide has
the details.

### Resource changes run for every index row

Backpex 0.21 calls `can?(assigns, :edit, item)` and `can?(assigns, :delete, item)`
for every row on the index page. The generated `can?/3` asks `Ash.can?/2`, which
builds an update or destroy changeset for the row, and building a changeset runs
the action's changes and the resource's global changes. Before 0.21 that only
happened when someone submitted a form.

In 0.3.0 through 0.3.2 the admin read only the attributes its fields listed, so
a change that read any other attribute found `%Ash.NotLoaded{}` and the index
page crashed. Since 0.3.3 the admin reads every attribute Ash selects by
default, as `Ash.read/2` does anywhere else. Two cases can still fail:

- a change that reads an attribute with `select_by_default? false`, unless that
  attribute is one of the LiveResource's fields
- a change that reads a relationship, calculation, or aggregate the record has
  not loaded

Those changes fail the same way outside the admin, for any record read with a
narrower selection. Have them read only what the changeset is changing
(`Ash.Changeset.changing_attribute?/2`), load what they need, or move the work
into an `Ash.Changeset.before_action/2` hook, which runs only when the action
does.

### Filter options given as functions

Backpex 0.21 validates filter values on every index load. A `Select` or
`MultiSelect` filter whose `options` is a 1-arity function raised
`Protocol.UndefinedError` on 0.3.0, because the function was passed to Backpex
uncalled. 0.3.1 fixed it. If you pinned 0.3.0 from GitHub, move to the latest
0.3 release.

### Smaller changes

- Bulk deletion runs the LiveResource's `destroy_action` instead of always
  calling `:destroy`, so a soft-delete action is now honored. Check any resource
  whose configured destroy action differs from its `:destroy` action.
- A bulk deletion that fails now shows Backpex's error message. It used to
  report "0 items have been deleted successfully."
- Readonly text inputs nested inside InlineCRUD and embedded fields render with
  `readonly` instead of `disabled`, so their values are submitted with the form.
  Top-level readonly fields are still dropped before they reach the Ash action.

## Checklist

1. `mix compile` succeeds, with each removed `can?/3` replaced by
   `create_action false` and friends, or by a policy.
2. Every resource routed with `except: [:new]` sets `create_action false`. Open
   one with an empty table.
3. Toggle the theme, a sidebar section, and a column, navigate to another
   resource, and reload. Each choice should survive, and the browser console
   should show no `BackpexPreferences` warning.
4. Open any admin page that is not a resource.
5. Open an index page for every resource that has filters.
6. Run each custom item action, and a bulk delete, as a user who is allowed and
   as one who is not.
