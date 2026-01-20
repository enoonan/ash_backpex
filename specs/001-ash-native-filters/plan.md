# Implementation Plan: Auto-Derived Ash-Native Filters

**Branch**: `001-ash-native-filters` | **Date**: 2026-01-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-ash-native-filters/spec.md`

## Summary

Add auto-derived filter modules to AshBackpex that use Ash.Expr for safe query filtering. Developers declare filters by attribute name only (`filter :published`), and the system derives the appropriate filter type (Boolean, Select, Range, MultiSelect) from Ash attribute types. Filter modules delegate UI rendering to Backpex while implementing Ash.Expr-based query generation.

## Technical Context

**Language/Version**: Elixir 1.15+ / OTP 26+
**Primary Dependencies**: Ash Framework (~> 3.0), Backpex (~> 0.9), Spark DSL (~> 2.0)
**Storage**: N/A (library - uses consumer's data layer via Ash)
**Testing**: ExUnit with in-memory SQLite (existing test setup)
**Target Platform**: Elixir/Phoenix applications using Ash Framework
**Project Type**: Elixir library (hex package)
**Performance Goals**: Compile-time filter derivation, no runtime overhead
**Constraints**: Must integrate with existing Backpex filter UI, must use Ash.Expr (not Ecto.Query)
**Scale/Scope**: Library feature - impacts all AshBackpex users

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution file contains template placeholders - no specific gates defined. Proceeding with standard Elixir library development practices:

- [x] Tests written before implementation (TDD per CLAUDE.md)
- [x] No breaking changes to existing API (module option still works)
- [x] Documentation for new features
- [x] Compile-time validation for invalid configurations

## Project Structure

### Documentation (this feature)

```text
specs/001-ash-native-filters/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
lib/
├── ash_backpex/
│   ├── adapter.ex                    # MODIFY: Update apply_filters/2
│   ├── filters/                      # NEW: Filter modules directory
│   │   ├── filter.ex                 # NEW: Base behavior
│   │   ├── boolean.ex                # NEW: Boolean filter
│   │   ├── select.ex                 # NEW: Select filter
│   │   ├── multi_select.ex           # NEW: MultiSelect filter
│   │   └── range.ex                  # NEW: Range filter
│   └── live_resource/
│       ├── dsl.ex                    # MODIFY: Extend Filter struct/schema
│       └── transformers/
│           └── generate_backpex.ex   # MODIFY: Add filter derivation

test/
├── ash_backpex/
│   ├── adapter_test.exs              # MODIFY: Add filter integration tests
│   ├── filters/                      # NEW: Filter module tests
│   │   ├── boolean_test.exs          # NEW
│   │   ├── select_test.exs           # NEW
│   │   ├── multi_select_test.exs     # NEW
│   │   └── range_test.exs            # NEW
│   └── live_resource/
│       └── transformer_test.exs      # MODIFY: Add derivation tests
└── support/
    └── test_resources.ex             # MODIFY: Add filterable attributes
```

**Structure Decision**: Follows existing AshBackpex patterns. New filter modules go in `lib/ash_backpex/filters/` mirroring how Backpex organizes its filters in `lib/backpex/filters/`.

## Complexity Tracking

No constitution violations - feature follows established patterns in the codebase.

## Design Decisions

### D1: AshBackpex Filter Modules vs Backpex Filters

**Decision**: Create new AshBackpex-specific filter modules
**Rationale**: Backpex filters use `Ecto.Query.dynamic/2` which is incompatible with `Ash.Query`. We need `Ash.Expr` expressions for safe, validated filtering through Ash's query system.
**Alternatives Rejected**:
- Using Backpex filters directly: Incompatible query interface
- Wrapping Backpex filters: Would still hit Ecto.Query incompatibility

### D2: Filter Module Architecture

**Decision**: Filter modules use `use Backpex.Filters.*` for UI and implement `to_ash_expr/3` callback
**Rationale**: Reuses Backpex's well-tested UI components while providing Ash-native query generation
**Implementation**:
```elixir
defmodule AshBackpex.Filters.Boolean do
  use Backpex.Filters.Boolean  # UI rendering
  @behaviour AshBackpex.Filters.Filter

  @impl AshBackpex.Filters.Filter
  def to_ash_expr(field, value, assigns) do
    # Return Ash.Expr expression
  end
end
```

### D3: Filter Type Derivation

**Decision**: Derive filter types at compile-time in the transformer
**Rationale**: Follows existing field type derivation pattern, provides compile-time errors for invalid configurations

| Ash Type | Filter Module | Notes |
|----------|---------------|-------|
| `Ash.Type.Boolean` | `AshBackpex.Filters.Boolean` | True/false checkboxes |
| `Ash.Type.Atom` + `one_of` | `AshBackpex.Filters.Select` | Dropdown |
| `Ash.Type.String` + `one_of` | `AshBackpex.Filters.Select` | Dropdown |
| `Ash.Type.Integer` | `AshBackpex.Filters.Range` | Number range |
| `Ash.Type.Float` | `AshBackpex.Filters.Range` | Number range |
| `Ash.Type.Date` | `AshBackpex.Filters.Range` | Date range |
| `Ash.Type.DateTime` | `AshBackpex.Filters.Range` | Datetime range |
| `{:array, _}` + `one_of` | `AshBackpex.Filters.MultiSelect` | Multiple checkboxes |

### D4: DSL Extension

**Decision**: Make `module` optional, add `options`, `prompt`, and `type` fields
**Rationale**: Enables auto-derivation while preserving explicit override capability

```elixir
# Before (required module)
filter :status do
  module Backpex.Filters.Select
end

# After (auto-derived)
filter :status  # Derives Select from one_of constraint

# Override still works
filter :custom_field do
  module MyApp.CustomFilter
end
```
