# Upgrading to 0.4

AshBackpex 0.4 changes one default: derived `has_many` and `many_to_many`
fields use `AshBackpex.Fields.HasMany` instead of `Backpex.Fields.HasMany`.
Coming from 0.2 or 0.1, follow [Upgrading to 0.3](upgrading-to-0.3.md) first.

## Update the dependency

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.4.0"}
  ]
end
```

## The new HasMany field

Backpex's `HasMany` field searches its options with `ILIKE`, which only Postgres
supports. On SQLite and MySQL, typing into a relationship's search box crashed
the LiveView with `ilike is not supported`.

`AshBackpex.Fields.HasMany` searches with `lower(display_field) LIKE
lower(pattern)`, which works on every SQL data layer. It accepts the same
options as Backpex's field and renders, selects and saves the same way, so the
form looks and behaves as before.

Fields that set `module Backpex.Fields.HasMany` explicitly keep Backpex's field.

### What can differ

- **Postgres matching.** `ILIKE` and `lower(...) LIKE` agree for most text. They
  can differ for characters whose lowercase form depends on the collation or
  locale. On SQLite, `lower/1` folds only ASCII letters, so a search for `É`
  does not match `é`.
- **Surrounding whitespace.** The search text is trimmed before matching.
- **`query_limit nil`.** All options load at once, so there is no "Show more".
  This was already the result with Backpex's field.

### Keep Backpex's field

To keep the previous behavior on a field, name Backpex's module:

```elixir
field :tags do
  module Backpex.Fields.HasMany
  display_field :name
end
```

Do this only on Postgres. The search crashes on other data layers.

### Custom fields built on Backpex's HasMany

The new field copies Backpex's search handlers and depends on the assigns
Backpex's `HasMany` uses internally. If your own field wraps or matches on
`Backpex.Fields.HasMany`, check that it also handles
`AshBackpex.Fields.HasMany`, or set the module explicitly as shown above.
