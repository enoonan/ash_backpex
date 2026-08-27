# Contributing to AshBackpex

Thank you for helping improve AshBackpex. GitHub issues and pull requests are the public collaboration interface for this project.

## Setup

AshBackpex requires Elixir 1.18 or later. The CI baseline uses Erlang/OTP 26.

```bash
git clone https://github.com/enoonan/ash_backpex.git
cd ash_backpex
mix deps.get
mix test
```

The included dev container is optional and provides the same repository tools without requiring a particular editor or agent runner.

The Phoenix demo is a separate application that depends on the local package:

```bash
cd demo
mix setup
mix phx.server
```

## Choose and develop a change

Open or select a GitHub issue before substantial work so scope and compatibility expectations are clear. Keep each pull request focused on one issue.

Read [`usage-rules.md`](usage-rules.md) before changing library behavior or examples. The [`docs/README.md`](docs/README.md) knowledge map links each subsystem to its authoritative source, tests, and fixtures.

Start with the closest focused test and add a failing case for behavior changes. Useful commands include:

```bash
mix test test/ash_backpex/adapter_test.exs
mix test.dsl
mix test.fields
mix test.forms
mix test.filters
```

Run `mix format` as you work. Avoid opportunistic refactors that make a behavior change harder to review.

## Completion checks

Run the same completion gate used by GitHub Actions:

```bash
mix ci
```

It verifies formatting, warning-free library compilation, strict Credo, generated package documentation, the full test suite (including repository contracts), and a warning-free demo compile against the local AshBackpex checkout.

## Documentation and compatibility

Document user-visible behavior where users will encounter it:

- update module docs and `usage-rules.md` for DSL, adapter, field, or form behavior;
- update a guide or README example for a workflow-level change;
- update the demo when it is the clearest executable example;
- add an entry to `CHANGELOG.md` for user-visible additions, fixes, deprecations, or breaking changes.

AshBackpex and Backpex are still evolving, but existing documented DSL options, callbacks, generated behavior, and parameter shapes should remain compatible unless the issue explicitly approves a breaking change. Prefer additive APIs and document deprecations before removal.

## Commits and pull requests

Use clear, focused commits; Conventional Commit prefixes such as `feat:`, `fix:`, `docs:`, `test:`, and `chore:` are welcome. Do not include generated build output or local tool state.

Pull requests should link the issue, explain the user-facing effect and compatibility impact, list the verification performed, and call out follow-up work that is intentionally out of scope.
