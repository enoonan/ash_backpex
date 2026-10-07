# Upgrade AshBackpex to Backpex 0.22

Date: 2026-10-07. Executed as an eno_harness epic in the AshBackpex Linear project.

## Why

Backpex 0.22.0 was released on 2026-10-07. Against 0.21, AshBackpex compiles
cleanly and its 277 tests pass on 0.22, but one feature regresses silently and a
new option is not reachable from the DSL:

- **Inline index edits moved to the index LiveView.** Built-in
  `render_index_form/1` now renders `Backpex.HTML.Form.index_form/1`, which sends
  an `"index-edit"` event to the LiveView instead of `"update-field"` to the
  field component. `Backpex.LiveResource.Index` saves the edit only when the
  field module exports the new optional callback
  `Backpex.Field.index_editable_change/3`; otherwise it logs a warning and marks
  the input invalid. `AshBackpex.Fields.BelongsTo` (used for `belongs_to` fields
  with `typeahead(true)`) delegates `render_index_form/1` to
  `Backpex.Fields.BelongsTo` but does not export `index_editable_change/3`, so
  its inline edits are never saved. No test covers the save path.
- **New `context_assigns` LiveResource option** (default `:all`). A list
  restricts the assigns that render-time callbacks receive (`can?/3`, item
  actions, filter and field callbacks) to Backpex's fixed set plus the listed
  keys. AshBackpex's generated `can?/3` reads `assigns.current_user`, and
  `AshBackpex.RelationshipOptions` reads `:actor` or `:current_user`, so a list
  without those keys silently authorizes as a nil actor.
- `phoenix_live_view` floor rises to `~> 1.1`; the locks already resolve 1.2.x.
- `Backpex.Adapter` is unchanged; `AshBackpex.Adapter` needs no change.
- Upload fields gained callbacks; AshBackpex ships no upload field, so nothing to do.

## Decisions

| Decision | Choice |
| --- | --- |
| Backpex constraint | `{:backpex, "~> 0.22.0"}`; AshBackpex's own version and release are maintainer-owned and out of scope. |
| Demo LiveView constraint | `demo/mix.exs` `{:phoenix_live_view, "~> 1.1"}`. |
| `AshBackpex.Fields.BelongsTo.index_editable_change/3` | `defdelegate` to `Backpex.Fields.BelongsTo.index_editable_change/3`. It uses the same Ecto-schema/`options_query` path that `index_assigns/3` already delegates to, so the saved value must be one of the options the select offers (including AshBackpex's derived relationship filter and authorization restriction). No Ash-native reimplementation. |
| Dead component handler | Remove `handle_event("update-field", ...)` from `AshBackpex.Fields.BelongsTo`; keep the typeahead `search`/`select`/`clear` handlers. |
| Inline-edit test style | Router-mounted index LiveView test (`Phoenix.LiveViewTest.live/2`) through a new test router plugged into `AshBackpex.TestEndpoint`, covering both the typeahead and the plain `Backpex.Fields.BelongsTo` paths. |
| `context_assigns` DSL option | New `backpex` section option `context_assigns`, type `:all` or a list of atoms, default `:all`, passed through to `use Backpex.LiveResource`. |
| Actor keys in a list | When `context_assigns` is a list, AshBackpex appends `:current_user` and `:actor` (deduplicated, user order preserved). `:all` passes through unchanged. Users cannot opt out. |
| Changelog | Entries go under a new `## Unreleased` heading at the top of `CHANGELOG.md`, below the upgrade callout. |
| Demo | Add an inline-editable, typeahead `belongs_to` field to the demo so the regression is manually checkable. |

## Facts an implementer would otherwise rediscover

- `AshBackpex.Fields.BelongsTo` is chosen only when a `belongs_to` field sets
  `typeahead(true)`; plain `belongs_to` fields use `Backpex.Fields.BelongsTo`,
  which already implements `index_editable_change/3` in 0.22.
- Backpex 0.22's index save path (`Backpex.LiveResource.Index` `save_index_edit/4`)
  re-reads the item with `Backpex.Resource.get/4`, checks
  `index_editable_enabled?/2`, `readonly?/2` and `can?(assigns, :edit, item)`,
  then calls `Backpex.Resource.update/6` with the update changeset.
- Test fixtures: no router exists; `AshBackpex.TestEndpoint` only has the
  LiveView socket and session plug. Tables are created by raw SQL in
  `AshBackpex.DataCase.create_test_tables/0` against in-memory SQLite. `Post`
  has policies that need an active actor related as author, and the primary
  update actions of `Post` and `Comment` accept no attributes, so neither can
  persist an inline `belongs_to` edit as is.
- Spark's `InfoGenerator` in `AshBackpex.LiveResource.Info` generates accessors
  for new `backpex` section options automatically.

## Issue tree

```
EIL-316  Upgrade AshBackpex to Backpex 0.22
├── EIL-317  Upgrade the Backpex dependency to 0.22               tier:fast    full
├── EIL-318  Save inline belongs_to edits on the index view        tier:medium  focused  (after 317)
├── EIL-319  Expose Backpex context_assigns in the LiveResource DSL tier:medium  focused  (after 317)
├── EIL-320  Document the Backpex 0.22 upgrade                     tier:fast    full     (after 318, 319)
└── EIL-321  Review the Backpex 0.22 upgrade epic                  epic_review  full     (after 317–320)
```

EIL-318 and EIL-319 run in parallel and own disjoint files, listed in their briefs. The
published briefs in Linear are the source of truth for each task.

## Out of scope

- Releasing AshBackpex, bumping its version, or publishing to Hex.
- Adopting `context_assigns` in the demo or in any default; the default stays `:all`.
- Upload callbacks, custom upload fields, or any change to `AshBackpex.Adapter`.
- An Ash-native rewrite of belongs_to option loading.

## Harness onboarding

This epic is the first AshBackpex work run by eno_harness. `.harness/` holds the
project manifest (profile `ash_backpex`: `compile`, `unit`, `format`, `credo`;
focused mode enabled with `compile`, `format` and `credo` mandatory), the fixed
hooks (`verify-full` runs `mix ci`), and the runner Dockerfile built on
`runner-base-202609281629`.
