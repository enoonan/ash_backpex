# Testing and verification

AshBackpex tests run against deterministic in-memory SQLite tables. Start at the closest test, use the shared fixtures, and run the full gate only after focused feedback is green.

## Focused commands

| Area | Command |
| --- | --- |
| One test or line | `mix test path/to/test.exs` or `mix test path/to/test.exs:LINE` |
| DSL and transformer | `mix test.dsl` |
| Adapter normalization and Ash operations | `mix test.adapter` |
| Custom fields and relationship queries | `mix test.fields` |
| Phoenix form protocol and nested forms | `mix test.forms` |
| Ash-native filters | `mix test.filters` |
| Repository documentation/CI/demo contracts | `mix test.harness` |
| Entire repository | `mix ci` |

`mix ci` is the completion contract used by GitHub Actions. It checks formatting, warning-free compilation, strict Credo, Sobelow security analysis, package documentation, all tests, locked demo dependencies, and a warning-free demo compile against the local package.

## Fixture map

- `test/support/data_case.ex` owns the SQLite sandbox and table schema. Add a table only for behavior that truly needs persistence.
- `test/support/test_resources.ex` contains representative Ash resources: attributes and policies, aggregates, read-only actions, non-default primary keys, and many-to-many relationships.
- `test/support/test_domain.ex` registers those resources with the test domain.
- `test/support/test_live.ex` contains small DSL consumers for transformer, adapter, authorization, typeahead, InlineCRUD, and filter tests.
- `test/support/test_generators.ex` seeds reusable records. Pass explicit values when a test asserts ordering, filtering, or normalization; do not depend on generated prose.

Prefer extending the smallest existing fixture over creating a new domain. Name unusual fixture fields for the invariant they represent and keep setup local when sharing it would hide the behavior under test.

## Test patterns by change

- DSL transformation: define or extend a LiveResource fixture, then assert generated callbacks in `transformer_test.exs`. Put invalid declarations in `error_cases_test.exs` and assert the corrective part of the compile-time message.
- Adapter normalization: use table-driven cases in `adapter_test.exs` for blank values, string/atom keys, order/delete/move combinations, and custom changeset callbacks. Assert the normalized Ash parameters, not private helper calls.
- Custom field: test Backpex callbacks and rendered behavior in `test/ash_backpex/fields/`; add transformer coverage if module or options are derived.
- Phoenix form behavior: build an Ash changeset and exercise `Phoenix.HTML.FormData` through the public form API. Cover loaded defaults, submitted params, errors, and hidden IDs at each supported nesting level.
- Filter: test the filter module's Ash expression, transformer derivation, and adapter application separately.

## Common failures

- A DSL compile failure should name the resource and field or option. Check `dsl.ex` for schema validation and `generate_backpex.ex` for derivation before changing runtime code.
- Missing columns or sandbox ownership usually belong to `DataCase`, not the production adapter.
- A nested form with the wrong resource or lost ID crosses transformer, form-data, and adapter boundaries; reproduce it with `TestInlineCrudLive` before editing.
- A relationship query that returns too much data may have lost its filter, actor, tenant, or authorization context. Start with `relationship_options_test.exs` or `belongs_to_test.exs`.
- Documentation-gate failures include the source document and unresolved target. Fix the link or remove stale prose rather than weakening the check.
- Demo failures must be reproduced from `demo/`; its `mix.exs` intentionally points to `path: "../"` so it validates the checkout under test.
