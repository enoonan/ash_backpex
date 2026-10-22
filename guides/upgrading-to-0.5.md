# Upgrading to 0.5

AshBackpex 0.5 makes relationship and typeahead options respect multitenancy
for every related resource. Coming from 0.3 or earlier, follow
[Upgrading to 0.4](upgrading-to-0.4.md) first.

## Update the dependency

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.5.0"}
  ]
end
```

## Relationship options use the tenant

A relationship field lists its options through a query derived from the Ash
relationship. When the related resource has an authorizer, that query has
always been scoped to the `tenant` assign, because the options were read with
`Ash.read/2`. When it has no authorizer, the tenant was ignored:

- With attribute multitenancy, the options listed every tenant's records.
- With context multitenancy, the options were read from the default schema.

From 0.5 every related resource is handled like `Ash.read/2` handles it:

- With attribute multitenancy, only the records of the `tenant` assign are
  listed.
- Without a `tenant` assign, rendering the field raises a tenant-required error,
  unless the resource is `global? true` or its read action sets
  `multitenancy :allow_global`, `:bypass` or `:bypass_all`.

This affects `belongs_to`, `has_many` and `many_to_many` fields, including
`typeahead` fields, whose related resource uses multitenancy.

### Set the tenant assign

Assign `:tenant` on the LiveView socket, for example in an `on_mount` hook that
runs for your admin routes:

```elixir
def on_mount(:admin, _params, _session, socket) do
  {:cont, Phoenix.Component.assign(socket, :tenant, socket.assigns.current_user.org_id)}
end
```

If the LiveResource sets `context_assigns`, include `:tenant` so field
callbacks still receive it:

```elixir
backpex do
  resource MyApp.Blog.Post
  layout {MyAppWeb.Layouts, :admin}
  context_assigns [:tenant]
end
```

### Keep listing every tenant's records

If an admin should choose from every tenant's records, say so on the related
resource rather than leaving the tenant unset. Mark the resource
`global? true` in its `multitenancy` block, or give the read action the
relationship uses `multitenancy :allow_global`.
