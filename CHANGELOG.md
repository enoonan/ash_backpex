# Changelog

<!-- changelog -->

## [Unreleased]

### Features

- Document `create_action false`, `update_action false`, and `destroy_action
  false`. They turn creating, editing, or deleting off in the admin: the
  generated `can?/3` denies `:new`, `:edit`, or `:delete` without consulting
  Ash. This hides Backpex's empty-state "New" button, which a LiveResource
  routed with `except: [:new]` could not otherwise remove.

### Fixes

- `AshBackpex.Filters.Select` and `AshBackpex.Filters.MultiSelect` now call
  `options` given as a 1-arity function with the assigns, as the filter DSL
  documents. They passed the function to Backpex unchanged, and Backpex 0.21
  validates filter values on every index load, so the index page raised
  `Protocol.UndefinedError`.

## [v0.3.0]

### Breaking Changes

- Require Backpex 0.21. Backpex now enforces the generated, Ash-backed `can?/3`
  centrally: `Backpex.Resource` authorizes every insert, update, `update_all`,
  and `delete_all`, and item actions re-read the selected records through the
  AshBackpex adapter before authorizing them. AshBackpex LiveResources need no
  configuration changes, but application code that calls Backpex directly must
  follow the [Backpex 0.21 upgrade guide](https://hexdocs.pm/backpex/v0-21.html):
  - `Backpex.Resource.delete_all/2` is now `delete_all/4`, and `update_all/3`
    and `update_all/4` are now `update_all/5` (pass `socket.assigns`; move
    `event_name` into the options).
  - Item actions are strict. A selection that contains an item the actor cannot
    act on raises `Backpex.ForbiddenError` instead of silently skipping it, a
    record that was deleted or is no longer readable by the actor raises
    `Backpex.NoResultsError`, and `handle/3` is never called with an empty list.
  - Custom item actions receive the freshly reloaded records. When `handle/3`
    writes those same records through `Backpex.Resource`, pass
    `authorize?: false`; Backpex has already authorized them.
- Defining `can?/3`, `fields/0`, `filters/0`, `item_actions/1`, or `layout/1` in
  an AshBackpex LiveResource is now a compile error. AshBackpex generates these
  callbacks after the module body, so earlier versions silently replaced a user
  definition, and it never ran. For `can?/3` this meant a custom access rule
  was never enforced. The error explains what happened and names the Ash policy
  or DSL entry to use instead. `form_actions/2`, `index_row_class/4`, and other
  Backpex callbacks can still be defined; see "Defining Backpex Callbacks" in
  `AshBackpex.LiveResource`.
- Nested readonly text-like inputs inside InlineCRUD and embedded fields now
  render with the native `readonly` attribute instead of `disabled`, so their
  current values are submitted with the form. Readonly checkboxes and toggles no
  longer submit a hidden `false` value. Top-level readonly fields are still
  dropped from submitted params before they reach the Ash action.

### Updates

- Support `Backpex.Fields.Checkgroup`. Checkgroup fields on array attributes with
  `one_of` constraints derive their options automatically, and the blank
  placeholder value Checkgroup submits is removed before the Ash action runs.
- Load `belongs_to` options for index-editable `AshBackpex.Fields.BelongsTo`
  fields once per index page through Backpex's `index_assigns/3`, instead of
  once per row.

### Fixes

- Bulk deletion now runs the LiveResource's configured `destroy_action` (or the
  resource's primary destroy action) instead of always calling `:destroy`, so
  custom and soft-delete destroy actions are honored.
- Report failed bulk deletions instead of a false success. `delete_all/2` now
  returns `{:error, errors}` when any record cannot be deleted (for example,
  because another record still references it), so Backpex shows its error
  message. Previously the errors were discarded and Backpex reported
  "0 items have been deleted successfully." On data layers that support
  transactions, the selection is deleted in one transaction, so a failure
  deletes nothing. AshSqlite does not support transactions, so records deleted
  before the failure stay deleted.

## [v0.2.0]

### Breaking Changes

- Require Backpex 0.20 and its unified preference system and collapsible app
  shell. Applications upgrading from AshBackpex 0.1 must migrate their Backpex
  layout and router integration; the demo and getting-started guide show the new
  setup.

### Updates

- Expose opt-in index-state persistence through the `persist` DSL option.
- Keep the demo theme selector at the right edge of the top bar so its menu opens
  within the viewport.

### Fixes

- Treat unloaded `has_many` relationships as empty InlineCRUD collections when
  rendering new-resource forms.

## [v0.1.13]

### Updates

- Define recursive `child_fields` configuration for typed embedded resource
  trees, including inferred InlineCRUD embed types and a singular
  `AshBackpex.Fields.Embedded` contract.
- Reconstruct recursive embedded forms from loaded data or submitted list/map
  params while preserving empty lists, row identity, and path-aware field errors.
- Render recursively composed InlineCRUD arrays and singular embedded fieldsets
  with depth-local controls, stable row identities, nested callback context, and
  Ash-compatible input names.
- Add a runnable demo content tree and complete documentation for repeated and
  singular recursive embedded forms, including action inputs and parameter
  normalization.
- Run Sobelow security analysis as part of `mix ci`.

### Fixes

- Make repeated InlineCRUD entries and singular embedded values visually distinct,
  and label their add, move, and delete controls with the entry type.
- Keep InlineCRUD actions usable at desktop and narrow viewport widths, with
  responsive wrapping and consistent spacing between controls.

## [v0.1.12]

### Updates

- Derive InlineCRUD child fields recursively from the child Ash resource,
  including field modules, relationship queries, and belongs-to typeaheads.
- Keep repeated child field components and typeahead searches scoped to their
  persistent row identity while entries are reordered.

## [v0.1.11]

### Fixes

- Remove the unused runtime Igniter dependency and its transitive `ex_ast`
  dependency.

## [v0.1.10]

### Updates

- Add opt-in, server-backed `typeahead true` support for `belongs_to` fields,
  including a configurable result limit, debouncing, and a Backpex-style
  searchable single-select dropdown.

## [v0.1.9]

### Updates

- Update Backpex to 0.19.6.
- Add opt-in `Backpex.Fields.InlineCRUD` support for `has_many`
  relationships, including `type` and a nested `child_fields` DSL.
- Add accessible move-up and move-down controls to InlineCRUD, repeat labels
  for every child form, and keep unsaved rows stable while reordering.
- Translate InlineCRUD add/delete/order parameters into ordered
  `manage_relationship` input and preserve existing child primary keys.
- Add a complete InlineCRUD demo and guide using article comments.

### Fixes

- Enforce Ash policies when the adapter persists create and update changesets.
- Restrict derived Backpex relationship options through an authorized Ash read
  when the destination resource has authorizers.

## [v0.1.8]

### Updates

- Derive Backpex relationship option queries from Ash relationship filters and sorts.
- Add a demo proof of concept with filtered topic and audience tag relationships.

### Fixes

- Handle Backpex option queries that already carry an Ecto root binding alias.

## [v0.1.7]

### Updates

- Add automatic `:many_to_many` relationship field derivation using `Backpex.Fields.HasMany`.
- Update the demo with article tags modeled as an Ash `many_to_many` relationship generated through Ash migrations.

## [v0.1.6]

### Fixes

- Remove the root Decimal override/dependency so the package can be published and consumers can resolve Decimal at the application level.
- Remove `mix_audit` because the current Backpex/number dependency graph requires top-level applications to own the Decimal 3 override.

## [v0.1.5]

### Fixes

- Add a Decimal 3 override to the demo app so its top-level dependency resolution matches the library audit fix.

## [v0.1.4]

### Updates

- Add `mix_audit` and run dependency auditing as part of `mix ci`.
- Refresh locked Ash dependencies and override Decimal to 3.x so dependency audits pass.

### Fixes

- Normalize blank list form values submitted by Backpex `HasMany` and `MultiSelect` fields before passing params into Ash changesets.

## [v0.1.3]

### Updates

- Bump Backpex dependency to 0.19.0.

### Fixes

- Fix index-editable fields by routing Backpex index updates through the configured AshBackpex changeset.

## [v0.1.2]

### Fixes

- Fix MultiSelect filters for SQLite-backed Ash array attributes.

## [v0.1.1]

### Updates

- Bump Backpex dependency to 0.18.0 and update AshBackpex for Backpex 0.18 filter and adapter compatibility.
- Add usage rules to the package for LLM-assisted development workflows.
- Expand the demo app with authors, comments, relationships, item actions, panels, filters, and richer sample data.

## [v0.1.0]

### Updates

- Bump Backpex dependency to 0.17.0. Backpex has dropped its built-in Ash integration in favor of this community project.
- Add Getting Started guide

## [v0.0.13]

### Fixes

- [fix: fix: one more init_order fix](https://github.com/enoonan/ash_backpex/pull/18) by [kepi](https://github.com/kepi)

### Fixes

- [fix: add catch-all can?/3 clause for custom item actions](https://github.com/enoonan/ash_backpex/pull/13) by [psoukry](https://github.com/pshoukry) 

## [v0.0.12]

### Updates

- Add missing ability to specify primary_key

## [v0.0.11]

### Fixes

- [fix: add catch-all can?/3 clause for custom item actions](https://github.com/enoonan/ash_backpex/pull/13) by [psoukry](https://github.com/pshoukry) 🎉

## [v0.0.10]

- fix: can?/3 returns false for missing actions instead of crashing. Thank you [psoukry](https://github.com/pshoukry)!

## [v0.0.9]

### Updates

- Bump Backpex version to 0.16
- Fix [adapter load bug](https://github.com/enoonan/ash_backpex/issues/6)
- Add sorting support. [Closes pull request #4](https://github.com/enoonan/ash_backpex/pull/4/files)
- Update demo to use an expression calculation.

## [v0.0.8]

### Updates

Implement changes required for upgrading Backpex to version 0.15.0 within AshBackpex and demo

- Can now use `layout &DemoWeb.Layouts.admin/1` when declaring Resource layout
- Updated resource adapter function signatures and incorporate it.
- Other v15 updates happen transparently

Return `{:ok, nil}` from `AshBackpex.Adapter.get\4` when item is not found.

## [v0.0.7]

### Updates

Just use main Backpex Hex repo. Still learning about Hex!

## [v0.0.6]

### Updates

Improve support for Ash `{:array, type}` parameters including MultiSelect

Ensure errors display correctly

Use up-to-date fork of main Backpex repo with AshBackpex-specific fixes (temporary!)

## [v0.0.5]

### Updates

Update to Backpex 0.14.0

## [v0.0.4]

### Improvements

Add `demo` app

Add `credo`, `ex_check`, `dialyxir`, `sobelow`, with various code-quality refactors.

## [v0.0.3]

### Improvements

Learn more about `ex_doc` and get main docs to land on README.md.

## [v0.0.2]

### Improvements

Generate documentation with `ex_doc`.

## [v0.0.1]

### Initial Release

Spark DSL with ability to derive Backpex configuration from an Ash resource. Currently supports top-level configurations, fields and filters.
