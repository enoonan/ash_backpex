# Changelog

<!-- changelog -->

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
