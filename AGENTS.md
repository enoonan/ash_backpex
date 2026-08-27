# AshBackpex agent guide

AshBackpex integrates Ash resources with Backpex admin LiveViews. Its Spark DSL derives Backpex configuration and callbacks at compile time; `AshBackpex.Adapter` translates Backpex operations into Ash queries and changesets.

## Start here

- Work on one bounded, approved issue. Task tracking or orchestration may be supplied by the invoking environment; follow that context and do not invent or mutate a second tracker.
- Read [`usage-rules.md`](usage-rules.md) before changing library behavior, examples, or public configuration.
- Use [`docs/README.md`](docs/README.md) to select the relevant subsystem guide. Find the closest implementation and test before editing.
- Preserve unrelated working-tree changes. Do not commit, push, publish packages, create releases, or mutate external systems unless explicitly authorized.

## Repository map

- DSL entry point: `lib/ash_backpex/live_resource.ex`
- DSL schema and entities: `lib/ash_backpex/live_resource/dsl.ex`
- compile-time generation: `lib/ash_backpex/live_resource/transformers/generate_backpex.ex`
- generated DSL accessors: `lib/ash_backpex/live_resource/info.ex`
- Backpex/Ash adapter: `lib/ash_backpex/adapter.ex`
- Ash changeset/Phoenix form bridge: `lib/ash_backpex/ash_changeset_to_phoenix_form.ex`
- custom fields and filters: `lib/ash_backpex/fields/` and `lib/ash_backpex/filters/`
- representative resources and LiveResources: `test/support/test_resources.ex` and `test/support/test_live.ex`
- package guides: `guides/`; runnable consumer: `demo/`

Read [`docs/architecture.md`](docs/architecture.md) for boundaries and data flow, [`docs/testing.md`](docs/testing.md) for the test/fixture map and focused commands, and [`docs/maintenance.md`](docs/maintenance.md) for documentation, demo, compatibility, changelog, and release responsibilities.

## Change contract

- Treat documented modules, DSL options, callbacks, generated behavior, and accepted parameter shapes as public API. Prefer additive changes and preserve backward compatibility unless a breaking change is explicitly approved.
- Develop from a focused failing test. Extend the nearest fixture only when it makes the invariant clearer and reusable.
- Keep compile-time DSL failures actionable: identify the resource, field or option, the violated invariant, and the correction when practical.
- Update module docs, `usage-rules.md`, guides, README examples, and the demo when their public behavior changes. Add a changelog entry for user-visible changes; package metadata and release notes are maintainer-owned release work.

## Verification

Install dependencies with `mix deps.get`. During iteration, run the closest test file or a focused alias documented in [`docs/testing.md`](docs/testing.md). Format touched code with `mix format`.

Before handing off a completed change, run:

```bash
mix ci
```

This is the repository completion gate and the same contract used by CI. Review `git diff`, `git diff --check`, and `git status --short` before finishing.
