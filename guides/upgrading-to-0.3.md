# Upgrading to 0.3

Backpex made some significant changes that impacted AshBackpex, so expect this
upgrade to take a bit longer than the ones before it.

Backpex's own upgrade guides are the authority for everything Backpex changed.
Work through them first, in order, then come back here. This guide covers only
what is different or additional in an AshBackpex application, and does not
repeat what Backpex's guides already say.

| You are on | Backpex guides to follow                                                                                                      | Then in this guide                  |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| 0.1.x      | [Upgrading to v0.20](https://hexdocs.pm/backpex/v0-20.html), then [Upgrading to v0.21](https://hexdocs.pm/backpex/v0-21.html) | Everything                          |
| 0.2.x      | [Upgrading to v0.21](https://hexdocs.pm/backpex/v0-21.html)                                                                   | [From 0.2 to 0.3](#from-0-2-to-0-3) |

Install the latest 0.3 release.

## Errors You May Experience on Upgrading

- The application may stop compiling. Defining `can?/3`, `fields/0`,
  `filters/0`, `item_actions/1`, or `layout/1` in a LiveResource is now a [compile
  error](#callbacks-that-are-now-compile-errors). Previously, these functions were ignored in favor of AshBackpex DSL declarations, and Ash policies in the case of `can?/3`.
- Pages that compile may still raise. From 0.1, the admin layout has to change
  before any page renders (see Backpex's v0.20 guide). From either version, a LiveResource routed with
  `except: [:new]` raises on an empty index page until you set
  [`create_action false`](#the-new-button-on-an-empty-index-page).
- Resource changes run for every row of an index page. A change that reads an unloaded attribute
  [can crash the page](#resource-changes-run-for-every-index-row).

## Update the dependencies

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.3.3"}
  ]
end
```

AshBackpex declares its own dependency on Backpex `~> 0.21.0`. If your
application also lists `:backpex`, change that constraint to match.

```bash
mix deps.update ash_backpex backpex
```

## From 0.1 to 0.2

AshBackpex 0.2 requires Backpex 0.20, which replaced its cookie-based UI state
with a preference system and gave the app shell a collapsible sidebar.
[Upgrading to v0.20](https://hexdocs.pm/backpex/v0-20.html) walks through the
router, `app.js`, root and admin layouts, sidebar sections, persistence, and
default ordering. The [getting-started guide](getting-started.md) shows the
finished result in an AshBackpex application. In addition:

### Run your authentication hook first

```elixir
live_session :backpex_admin,
  on_mount: [{MyAppWeb.LiveUserAuth, :require_admin}, Backpex.InitAssigns] do
  live_resources "/posts", PostLive
end
```

AshBackpex uses `assigns.current_user` as the Ash actor, so the hook that
assigns it has to run before any LiveResource mounts. `Backpex.InitAssigns` now
reads the user's stored preferences using whatever that hook assigned, so it has
to come second.

### Admin pages that are not resources

A LiveResource passes every layout assign for you. A LiveView of your own that
renders the admin layout, such as a dashboard, has to pass the ones Backpex 0.20
added: `socket`, `sidebar_open`, `sidebar_section_states`, and
`preferences_manifest`. Route it in the same `live_session` so
`Backpex.InitAssigns` assigns them. See
[Admin Pages That Are Not Resources](getting-started.md#admin-pages-that-are-not-resources).

### `persist` and `init_order` go in the `backpex` block

Backpex's guide shows these as `use Backpex.LiveResource` options. In AshBackpex
they are DSL options:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  persist [:columns, :metrics]
  init_order %{by: :inserted_at, direction: :desc}
end
```

There is no project-wide default for `persist`; each LiveResource opts in.

## From 0.2 to 0.3

AshBackpex 0.3 requires Backpex 0.21, which enforces `can?/3` in
`Backpex.Resource` instead of leaving it to each caller.
[Upgrading to v0.21](https://hexdocs.pm/backpex/v0-21.html) covers the new
`Backpex.Resource` signatures, strict item actions, `authorize?: false`,
re-raising Backpex's errors from `rescue` clauses, and readonly fields.

LiveResources need no change for central enforcement: the `can?/3` that Backpex
enforces is the one AshBackpex generates from your Ash policies. An item action
that writes through your own Ash actions, with the current user as the actor,
also needs no change; Ash checks its policies again when it runs. What follows
is specific to AshBackpex.

### Callbacks that are now compile errors

AshBackpex generates `can?/3`, `fields/0`, `filters/0`, `item_actions/1`, and
`layout/1` from the `backpex` block, so defining one yourself is now a compile
error:

```text
MyAppWeb.PostLive defines can?/3 (lib/my_app_web/live/post_live.ex:13),
but AshBackpex generates can?/3 for every LiveResource.
```

| Function         | What to do                                                     |
| ---------------- | -------------------------------------------------------------- |
| `can?/3`         | Use Ash Policies                                               |
| `fields/0`       | Declare the fields in the `fields` section                     |
| `filters/0`      | Declare the filters in the `filters` section                   |
| `item_actions/1` | Use `action` and `strip_default` in the `item_actions` section |
| `layout/1`       | Set the `layout` option                                        |

For actions that should be entirely omitted, set the configured backpex action to false.
For example, if the admin does not allow updates:

```elixir
  backpex do
    ...
    update_action false
  end
```

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

### Resource changes run for every index row

AshBackpex now calls `Ash.can?/3` multiple times for every row on the index page:
for `:edit`, for `:delete`, and for bulk item actions as well, to
decide whether the row can be selected. You may run into errors with:

- a change that reads an attribute with `select_by_default? false`, unless that
  attribute is one of the LiveResource's declared fields
- a change that reads a relationship, calculation, or aggregate the record has
  not loaded

### Smaller changes

- Bulk deletion runs the LiveResource's `destroy_action` instead of always
  calling `:destroy`. Check any LiveResource whose configured `destroy_action`
  differs from its Ash Resource's primary `:destroy` action.
- A bulk deletion that fails now shows Backpex's error message. It used to
  report "0 items have been deleted successfully." On data layers that support
  transactions the whole selection is deleted in one transaction, so a failure
  deletes nothing. AshSqlite does not support them, so records deleted before
  the failure stay deleted.
- Readonly text inputs nested inside InlineCRUD and embedded fields render with
  `readonly` instead of `disabled`, so their values are submitted with the form.
  Top-level readonly fields are still dropped before they reach the Ash action.