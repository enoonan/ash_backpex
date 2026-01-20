# Research: Auto-Derived Ash-Native Filters

**Feature**: 001-ash-native-filters
**Date**: 2026-01-20

## R1: Backpex Filter Architecture

### Question
How do Backpex filters work, and can we reuse their UI components?

### Findings
Backpex filters are modules that implement:
- `render/1` - LiveView component for filter UI
- `query/4` - Returns `Ecto.Query.dynamic/2` expression

Each filter type (Boolean, Select, Range, MultiSelect) has a corresponding module in `Backpex.Filters.*`.

### Decision
Reuse Backpex filter UI by using `use Backpex.Filters.*` in our modules. This gives us:
- Proven UI components (checkboxes, dropdowns, range inputs)
- Consistent styling with other Backpex components
- No need to build custom LiveView components

### Rationale
Writing custom filter UI would duplicate effort and risk inconsistency. Backpex filters are well-tested and match the admin interface styling.

### Alternatives Considered
1. **Build custom filter components**: Rejected - significant effort, maintenance burden
2. **Fork Backpex filters**: Rejected - creates divergence, harder to stay updated

---

## R2: Ash.Expr vs Ecto.Query

### Question
Why can't we use Backpex's `query/4` callback directly?

### Findings
Backpex filters return `Ecto.Query.dynamic/2` expressions like:
```elixir
dynamic([x], ^x.field == ^value)
```

Ash queries require `Ash.Expr` expressions:
```elixir
Ash.Expr.expr(^Ash.Expr.ref(field) == ^value)
```

These are fundamentally different:
- Ecto.Query.dynamic compiles to SQL fragments
- Ash.Expr is an AST that Ash validates and transforms

### Decision
Create new `to_ash_expr/3` callback that returns Ash.Expr expressions instead of Ecto dynamics.

### Rationale
Ash.Expr provides:
- Type validation against the resource
- Policy/authorization integration
- Support for calculations and aggregates
- Data layer abstraction (works with any Ash data layer)

### Alternatives Considered
1. **Convert Ecto.Query to Ash.Expr**: Rejected - no clean conversion path
2. **Bypass Ash.Query**: Rejected - loses Ash benefits, security risks

---

## R3: Existing Field Derivation Pattern

### Question
How does AshBackpex currently derive field types?

### Findings
The transformer in `generate_backpex.ex` uses:
1. `derive_type/1` - Gets Ash type from attribute/relationship/calculation/aggregate
2. `try_derive_module/1` - Maps type to Backpex.Fields.* module
3. `maybe_derive_options/2` - Extracts one_of constraints for Select/MultiSelect

Pattern:
```elixir
try_derive_module = fn attribute_name ->
  type = derive_type.(attribute_name)
  case type do
    Ash.Type.Boolean -> Backpex.Fields.Boolean
    Ash.Type.String -> select_or.(attribute_name, Backpex.Fields.Text)
    # ... etc
  end
end
```

### Decision
Mirror this pattern for filter derivation. Create `derive_filter_module/1` and `derive_filter_options/2` functions.

### Rationale
Consistent patterns make the codebase easier to understand and maintain. Developers familiar with field derivation will immediately understand filter derivation.

---

## R4: Filter Value Parsing

### Question
How should filter values from the UI be parsed?

### Findings
Filter values arrive from Phoenix params as strings:
- Boolean: `"true"` / `"false"` or list `["true", "false"]`
- Select: `"value"` string
- MultiSelect: `["value1", "value2"]` list of strings
- Range: `%{"start" => "10", "end" => "20"}` map of strings

Each filter type needs appropriate parsing:
- Boolean: String to boolean
- Select: May need atom conversion for atom fields
- Range: String to number/date/datetime based on field type

### Decision
Each filter module's `to_ash_expr/3` handles its own value parsing. Parse failures return `nil` (no filter applied).

### Rationale
- Encapsulates parsing logic with the filter that understands the value format
- Graceful degradation on invalid input (show all records vs error)
- Simple validation - if it parses, it's valid

---

## R5: Security Considerations

### Question
How do we ensure filter values can't be used for injection attacks?

### Findings
Ash.Expr with pinned values (`^value`) is safe:
```elixir
Ash.Expr.expr(^Ash.Expr.ref(field) == ^user_input)
```

The `^` pin operator ensures values are treated as data, not code. This is similar to Ecto's parameterized queries.

Additional protections:
1. **Whitelist by design**: Only filters defined in DSL are processed
2. **Type coercion**: Values are parsed to expected types before use
3. **Ash validation**: Ash validates expressions against the resource schema

### Decision
Always use pinned values in Ash.Expr. Filter modules return `nil` for unparseable values.

### Rationale
Defense in depth - multiple layers of validation ensure safety even if one layer fails.

---

## Summary

All research questions resolved. Key decisions:
1. Use Backpex filter UI via `use Backpex.Filters.*`
2. Implement `to_ash_expr/3` callback for Ash-native query generation
3. Mirror existing field derivation patterns
4. Parse values in filter modules, return nil on failure
5. Always pin values in Ash.Expr for security
