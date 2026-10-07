# Architecture and boundaries

AshBackpex has two main phases: a Spark DSL is compiled into a Backpex LiveResource, then Backpex callbacks are translated into Ash operations at runtime. The source and tests named below are authoritative; package-facing examples live in [`usage-rules.md`](../usage-rules.md).

## DSL compilation flow

1. A consumer `use`s `AshBackpex.LiveResource` and declares a `backpex` block in `lib/ash_backpex/live_resource.ex`.
2. `lib/ash_backpex/live_resource/dsl.ex` defines the Spark sections, entities, option schemas, and transformer order.
3. `lib/ash_backpex/live_resource/transformers/generate_backpex.ex` reads the persisted DSL, derives field/filter configuration, validates resource metadata, and injects Backpex callbacks.
4. `lib/ash_backpex/live_resource/info.ex` exposes generated accessors for stored DSL values.

Compile-time behavior belongs in the transformer and must be covered by `test/ash_backpex/live_resource/transformer_test.exs` or `error_cases_test.exs`. Tests define small LiveResource modules in `test/support/test_live.ex`, `test/support/index_edit_live.ex`, and `test/support/context_assigns_live.ex`; use those patterns instead of booting the demo.

Keep the boundary sharp: DSL modules describe configuration, the transformer derives code, and runtime adapter modules execute work. A new DSL option normally requires a schema/entity change, transformer or generated-callback handling, focused compile-time tests, module documentation, and `usage-rules.md` updates.

## Runtime boundaries

`lib/ash_backpex/adapter.ex` implements the Backpex adapter callbacks. It resolves the configured Ash actions, builds authorized Ash queries and changesets, normalizes submitted parameters, applies search/filter/sort behavior, and returns the shapes Backpex expects. Its primary contract test is `test/ash_backpex/adapter_test.exs`; authorization paths also live in `test/ash_backpex/authz_test.exs`.

Supporting modules have narrower ownership:

- `basic_search.ex` builds Ash search expressions; `basic_search_test.exs` owns its behavior.
- `load_select_resolver.ex` decides which selected fields and loads an Ash query needs; `load_select_test.exs` covers failures and resolution.
- `relationship_options.ex` derives relationship queries without discarding Ash filters, sorts, context, tenant, actor, or authorization; `relationship_options_test.exs` is the focused contract.
- `config.ex` validates global and application-scoped type mappings; `config_test.exs` and the custom-mapping integration tests cover precedence.

Do not let Backpex or Phoenix structs leak into the Ash resource definitions, and do not bypass Ash actions, authorization, or relationship metadata with data-layer-specific queries.

## Forms and nested resources

`lib/ash_backpex/ash_changeset_to_phoenix_form.ex` implements the Phoenix form-data bridge for Ash changesets. It owns field values, validations, errors, nested form construction, stable child identity, and hidden primary keys. `test/ash_backpex/ash_changeset_to_phoenix_form_test.exs` is the focused contract.

InlineCRUD spans three boundaries:

- the transformer derives child fields against the related Ash resource;
- the adapter normalizes add, delete, move, and order parameters into the array-of-maps shape accepted by Ash;
- `lib/ash_backpex/fields/inline_crud.ex` renders repeated child forms and stable controls.

Use `TestInlineCrudLive` plus the Post/Comment fixtures in `test/support/` for changes here. Nested-resource context and preserved primary keys are compatibility-sensitive parameter contracts.

## Fields, filters, and relationships

Custom field integrations live in `lib/ash_backpex/fields/` and should remain thin Backpex field implementations. Field derivation itself belongs in the transformer. The typeahead belongs-to implementation is exercised by `test/ash_backpex/fields/belongs_to_test.exs` with representative relationship and authorization fixtures, and its inline index edits by `test/ash_backpex/fields/belongs_to_index_edit_test.exs`.

Ash-native filters live in `lib/ash_backpex/filters/`. They reuse Backpex UI behavior but return Ash expressions through the `AshBackpex.Filters.Filter` contract. Filter expression tests live beside each module; transformer tests own type derivation, and adapter tests own configuration and request-value plumbing.

When changing relationship fields, preserve the relationship's read action, filter, sort, context, tenant, actor, and authorization. Test both derivation and query execution.

## Public API boundary

Treat documented modules, `AshBackpex.LiveResource` DSL options, adapter callbacks, generated callbacks, field/filter configuration, and accepted form parameter shapes as public. Modules grouped as internals in `mix.exs` may change internally, but their documented observable behavior still requires compatibility care. Prefer additive options, deterministic defaults, and actionable compile-time errors. Record intentional breaking changes in the changelog and migration guidance.
