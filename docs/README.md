# Repository knowledge map

This directory is the durable contributor map for AshBackpex. Package usage belongs in [`README.md`](../README.md), [`usage-rules.md`](../usage-rules.md), module documentation, and [`guides/`](../guides/); these documents explain how the repository itself fits together.

| Change area | Read first | Authoritative implementation and tests |
| --- | --- | --- |
| DSL options, validation, or generated callbacks | [`architecture.md`](architecture.md#dsl-compilation-flow) | `lib/ash_backpex/live_resource/`, `test/ash_backpex/live_resource/` |
| Backpex adapter, queries, changesets, or parameter normalization | [`architecture.md`](architecture.md#runtime-boundaries) | `lib/ash_backpex/adapter.ex`, `test/ash_backpex/adapter_test.exs` |
| Phoenix form or InlineCRUD nesting | [`architecture.md`](architecture.md#forms-and-nested-resources) | `lib/ash_backpex/ash_changeset_to_phoenix_form.ex`, form and adapter tests |
| Fields, filters, or relationship options | [`architecture.md`](architecture.md#fields-filters-and-relationships) | `lib/ash_backpex/fields/`, `lib/ash_backpex/filters/`, matching tests |
| Tests or fixtures | [`testing.md`](testing.md) | `test/`, especially `test/support/` |
| Demo, docs, compatibility, changelog, or release work | [`maintenance.md`](maintenance.md) | `demo/`, `guides/`, `mix.exs`, `CHANGELOG.md` |
