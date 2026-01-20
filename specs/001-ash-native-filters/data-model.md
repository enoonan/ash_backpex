# Data Model: Auto-Derived Ash-Native Filters

**Feature**: 001-ash-native-filters
**Date**: 2026-01-20

## Overview

This feature adds new modules and extends existing DSL structures. No database changes are required - all data is compile-time configuration.

## Entities

### Filter Configuration (DSL Entity)

Represents a filter declaration in the `backpex` DSL.

**Location**: `AshBackpex.LiveResource.Dsl.Filter` struct

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `attribute` | `atom` | Yes | - | The Ash attribute to filter on |
| `module` | `module` | No | Auto-derived | Filter module implementing behavior |
| `label` | `string` | No | Title-cased attribute | Display label for the filter |
| `options` | `list \| fun/1` | No | From one_of | Options for Select/MultiSelect |
| `prompt` | `string` | No | "Select..." | Prompt text for empty selection |
| `type` | `atom` | No | Auto-derived | Range type: `:number`, `:date`, `:datetime` |

**Validation Rules**:
- `attribute` must exist on the Ash resource (validated at compile time)
- If `module` not provided, must be derivable from attribute type
- `options` required for Select/MultiSelect if no one_of constraint

**State Transitions**: N/A (immutable compile-time configuration)

---

### Filter Behavior

Defines the contract for AshBackpex filter modules.

**Location**: `AshBackpex.Filters.Filter` behavior

| Callback | Signature | Required | Description |
|----------|-----------|----------|-------------|
| `to_ash_expr/3` | `(atom, any, map) -> Ash.Expr.t \| nil` | Yes | Generate Ash.Expr from filter value |
| `validate_value/2` | `(any, keyword) -> {:ok, any} \| {:error, String.t}` | No | Optional value validation |

---

### Compiled Filter Map

The transformer generates a filter configuration map at compile time.

**Structure** (runtime value of `@filters` module attribute):

```elixir
[
  published: %{
    module: AshBackpex.Filters.Boolean,
    label: "Published"
  },
  status: %{
    module: AshBackpex.Filters.Select,
    label: "Status",
    options: [{"Draft", :draft}, {"Published", :published}],
    prompt: "Select..."
  },
  rating: %{
    module: AshBackpex.Filters.Range,
    label: "Rating",
    type: :number
  }
]
```

## Relationships

```
┌─────────────────────┐
│  LiveResource DSL   │
│  (backpex block)    │
└──────────┬──────────┘
           │ contains
           ▼
┌─────────────────────┐
│  Filter Entity      │
│  (filter :attr)     │
└──────────┬──────────┘
           │ references
           ▼
┌─────────────────────┐
│  Filter Module      │
│  (AshBackpex.       │
│   Filters.*)        │
└──────────┬──────────┘
           │ implements
           ▼
┌─────────────────────┐
│  Filter Behavior    │
│  (to_ash_expr/3)    │
└─────────────────────┘
```

## Type Derivation Rules

| Ash Type | Constraint | Derived Filter | Derived Type |
|----------|------------|----------------|--------------|
| `Ash.Type.Boolean` | - | `AshBackpex.Filters.Boolean` | - |
| `Ash.Type.Atom` | `one_of: [...]` | `AshBackpex.Filters.Select` | - |
| `Ash.Type.Atom` | none | Error: undecidable | - |
| `Ash.Type.String` | `one_of: [...]` | `AshBackpex.Filters.Select` | - |
| `Ash.Type.String` | none | Error: undecidable | - |
| `Ash.Type.Integer` | - | `AshBackpex.Filters.Range` | `:number` |
| `Ash.Type.Float` | - | `AshBackpex.Filters.Range` | `:number` |
| `Ash.Type.Date` | - | `AshBackpex.Filters.Range` | `:date` |
| `Ash.Type.DateTime` | - | `AshBackpex.Filters.Range` | `:datetime` |
| `Ash.Type.UtcDatetime` | - | `AshBackpex.Filters.Range` | `:datetime` |
| `Ash.Type.UtcDatetimeUsec` | - | `AshBackpex.Filters.Range` | `:datetime` |
| `Ash.Type.NaiveDateTime` | - | `AshBackpex.Filters.Range` | `:datetime` |
| `{:array, _}` | `one_of: [...]` | `AshBackpex.Filters.MultiSelect` | - |
| `{:array, _}` | none | Error: undecidable | - |
| Other | - | Error: undecidable | - |

## Filter Value Formats

Values received from Backpex UI:

| Filter Type | Input Format | Example |
|-------------|--------------|---------|
| Boolean | `list(string)` | `["true"]`, `["false"]`, `["true", "false"]` |
| Select | `string` | `"draft"`, `"published"` |
| MultiSelect | `list(string)` | `["tag1", "tag2"]` |
| Range | `map` | `%{"start" => "10", "end" => "20"}` |
