# Upgrading to 0.3

AshBackpex 0.2 and 0.3 each follow a Backpex release that changes how an admin
is wired together. Expect this upgrade to take longer than the ones before it.

Backpex's own upgrade guides are the authority for everything Backpex changed.
Work through them first, in order, then come back here. This guide covers only
what is different or additional in an AshBackpex application, and does not
repeat what Backpex's guides already say.

| You are on | Backpex guides to follow | Then in this guide |
| --- | --- | --- |
| 0.1.x | [Upgrading to v0.20](https://hexdocs.pm/backpex/v0-20.html), then [Upgrading to v0.21](https://hexdocs.pm/backpex/v0-21.html) | Everything |
| 0.2.x | [Upgrading to v0.21](https://hexdocs.pm/backpex/v0-21.html) | [From 0.2 to 0.3](#from-0-2-to-0-3) |

0.3.0 and 0.3.1 were tagged on GitHub but not published to Hex. Install the
latest 0.3 release.

What to expect:

- The application may stop compiling. Defining `can?/3`, `fields/0`,
  `filters/0`, `item_actions/1`, or `layout/1` in a LiveResource is now a compile
  error. [Each one has a fix](#callbacks-that-are-now-compile-errors).
- Pages that compile may still raise. From 0.1, the admin layout has to change
  before any page renders (see Backpex's v0.20 guide). From either version, a LiveResource routed with
  `except: [:new]` raises on an empty index page until you set
  [`create_action false`](#the-new-button-on-an-empty-index-page).
- Resource changes run for every row of an index page. A change that reads an
  attribute the record may not have
  [can crash the page](#resource-changes-run-for-every-index-row).
- Access rules written in `can?/3` never ran. If a LiveResource defined one, its
  rule was not being enforced, and you have to decide where it belongs now.

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

### Resource changes run for every index row

Backpex asks `can?/3` about every row on the index page: `:edit` and `:delete`
for the row's buttons, and since 0.21 each bulk item action as well, to decide
whether the row can be selected. The generated `can?/3` answers with
`Ash.can?/2`, which builds an update or destroy changeset for the row. Building
a changeset runs the action's changes and the resource's global changes, so they
run for every row, on every render, with an empty input.

Before 0.3.3 the admin read only the attributes its fields listed, so a change
that read any other attribute found `%Ash.NotLoaded{}` and the index page
crashed. Since 0.3.3 the admin reads every attribute Ash selects by default, as
`Ash.read/2` does anywhere else, plus any attribute listed as a field. Two cases
can still fail:

- a change that reads an attribute with `select_by_default? false`, unless that
  attribute is one of the LiveResource's fields
- a change that reads a relationship, calculation, or aggregate the record has
  not loaded

Those changes fail the same way outside the admin, for any record read with a
narrower selection. Have them read only what the changeset is changing
(`Ash.Changeset.changing_attribute?/2`), load what they need, or move the work
into an `Ash.Changeset.before_action/2` hook, which runs only when the action
does.

Each check is an `Ash.can?/2` call, so policies that run queries run them once
per row and operation. Keep an eye on index pages for resources with expensive
policies.

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
  report "0 items have been deleted successfully." On data layers that support
  transactions the whole selection is deleted in one transaction, so a failure
  deletes nothing. AshSqlite does not support them, so records deleted before
  the failure stay deleted.
- Readonly text inputs nested inside InlineCRUD and embedded fields render with
  `readonly` instead of `disabled`, so their values are submitted with the form.
  Top-level readonly fields are still dropped before they reach the Ash action.

## Checklist

1. You have worked through Backpex's upgrade guides for every version you
   crossed.
2. `mix compile` succeeds, with each removed `can?/3` replaced by
   `create_action false` and friends, or by a policy.
3. Every resource routed with `except: [:new]` sets `create_action false`. Open
   one with an empty table.
4. Open the index page of every resource whose changes read other attributes,
   and of every resource with filters.
5. Toggle the theme, a sidebar section, and a column, navigate to another
   resource, and reload. Each choice should survive, which confirms the
   authentication hook runs before `Backpex.InitAssigns`.
6. Open any admin page that is not a resource.
7. Run each custom item action, and a bulk delete, as a user who is allowed and
   as one who is not.
