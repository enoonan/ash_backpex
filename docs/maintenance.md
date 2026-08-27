# Maintenance, compatibility, and releases

Repository maintenance keeps the package documentation, executable examples, demo consumer, and release metadata aligned with source behavior.

## Update responsibilities

| Change | Also review |
| --- | --- |
| DSL option, generated callback, field/filter behavior | Module docs, `usage-rules.md`, transformer/error tests |
| Workflow-level user feature | README and the relevant file in `guides/` |
| Demo-visible behavior or integration assumption | `demo/lib/`, `demo/README.md`, and `mix demo.check` |
| User-visible addition, fix, deprecation, or breaking change | `CHANGELOG.md` |
| New guide included in published HexDocs | `docs/0` extras and package files in `mix.exs` |
| Dependency or compatibility range | Root and demo lockfiles, CI baseline, changelog |

The demo is a consumer, not a second implementation. Keep `{:ash_backpex, path: "../"}` in `demo/mix.exs`; do not copy library code into it. The completion gate compiles the demo in its configured development environment without starting a server, database, or external service.

## Compatibility and release boundary

Before changing a documented DSL option, generated callback, adapter parameter shape, or form protocol behavior, identify existing callers and tests. Prefer additions and deprecations over removal. A breaking change needs explicit issue scope, migration guidance, and a changelog entry.

Version changes, package publication, tags, and GitHub releases are maintainer actions. Contributors may prepare changelog or metadata changes when requested, but must not publish or create releases without explicit authorization.

## Review-to-harness loop

Repeated review feedback is evidence that repository guidance or enforcement is missing. When the same class of problem recurs:

1. identify the owning subsystem and the smallest stable invariant;
2. encode it in the nearest ExUnit test, repository-contract test, Mix alias, or CI step;
3. add a fixture only when it makes future tests clearer;
4. update this knowledge map or `AGENTS.md` only with the shortest routing guidance needed;
5. remove superseded instructions so there is one authoritative path.

Do not turn one-off preferences into global rules. Favor executable checks with corrective failure messages over prose that can silently drift.

## Pre-release review

Run `mix ci`, review the rendered HexDocs result, verify README installation and usage examples against the intended version, confirm changelog coverage, inspect package contents with `mix hex.build`, and review both lockfiles. Publishing, tagging, pushing, and release creation require explicit maintainer authorization.
