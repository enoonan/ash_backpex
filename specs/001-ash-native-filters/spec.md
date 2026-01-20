# Feature Specification: Auto-Derived Ash-Native Filters

**Feature Branch**: `001-ash-native-filters`
**Created**: 2026-01-20
**Status**: Draft
**Input**: User description: "Auto-derived Ash-native filters for AshBackpex - add support for auto-derived filter modules that use Ash.Query.filter with Ash.Expr for safe, validated filtering. Users can define filters in the DSL without creating custom modules - the system derives appropriate filter types from Ash attribute types."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Filter Declaration (Priority: P1)

As a developer building an admin interface with AshBackpex, I want to declare filters on my LiveResource by simply specifying the attribute name, so that the system automatically determines the appropriate filter type and UI without me needing to create custom filter modules.

**Why this priority**: This is the core value proposition - reducing boilerplate and developer effort. Without this, developers must create custom filter modules for every filterable attribute.

**Independent Test**: Can be fully tested by declaring a filter on a boolean attribute (e.g., `filter :published`) and verifying that a checkbox-style filter appears in the admin UI and correctly filters records.

**Acceptance Scenarios**:

1. **Given** a LiveResource with a `filter :published` declaration where `published` is a boolean attribute, **When** the developer loads the admin index page, **Then** a boolean filter UI (checkboxes for true/false) appears in the filter panel.

2. **Given** a filter is declared on an attribute with a `one_of` constraint (e.g., status with values [:draft, :published, :archived]), **When** the developer loads the admin index page, **Then** a dropdown/select filter appears with options derived from the constraint values.

3. **Given** a filter is declared on a numeric attribute (integer or float), **When** the developer loads the admin index page, **Then** a range filter UI (min/max inputs) appears in the filter panel.

---

### User Story 2 - Filter Type Override (Priority: P2)

As a developer, I want to explicitly specify a filter module when the auto-derived type doesn't match my needs, so that I have full control over filter behavior when required.

**Why this priority**: While auto-derivation handles most cases, developers need an escape hatch for custom requirements.

**Independent Test**: Can be tested by declaring a filter with an explicit module (e.g., `filter :title, module: AshBackpex.Filters.Select`) and verifying the specified module is used instead of the auto-derived one.

**Acceptance Scenarios**:

1. **Given** a filter declaration with an explicit module specified, **When** the system processes the filter, **Then** the specified module is used regardless of the attribute type.

2. **Given** a filter declaration on an attribute type that cannot be auto-derived (e.g., a custom Ash type), **When** no module is specified, **Then** the system raises a helpful compile-time error explaining how to specify a module.

---

### User Story 3 - Date/DateTime Range Filtering (Priority: P2)

As an admin user, I want to filter records by date ranges, so that I can find records created or modified within specific time periods.

**Why this priority**: Date filtering is extremely common in admin interfaces for auditing and data management.

**Independent Test**: Can be tested by declaring a filter on a datetime attribute and using the date range picker to select a range, verifying only records within that range are returned.

**Acceptance Scenarios**:

1. **Given** a filter declared on a Date attribute, **When** the user selects a date range, **Then** only records with dates within that range are displayed.

2. **Given** a filter declared on a DateTime attribute, **When** the user selects start and end dates, **Then** records are filtered inclusively (start <= value <= end).

3. **Given** a range filter where only the start date is specified, **When** the filter is applied, **Then** all records with dates on or after the start date are displayed.

---

### User Story 4 - Multi-Select Array Filtering (Priority: P3)

As an admin user, I want to filter records by selecting multiple values from an array field's allowed options, so that I can find records matching any of the selected values.

**Why this priority**: Array fields with constrained values are common for tags, categories, and multi-value attributes.

**Independent Test**: Can be tested by declaring a filter on an array attribute with `one_of` constraints and selecting multiple checkbox options, verifying matching records are returned.

**Acceptance Scenarios**:

1. **Given** a filter declared on an array attribute with `one_of` constraints, **When** the admin selects multiple values, **Then** records containing any of the selected values are displayed.

---

### Edge Cases

- What happens when a filter is declared on an attribute that doesn't exist on the resource? The system should raise a compile-time error with a helpful message.
- How does the system handle null/nil filter values? Empty or nil filter values should result in no filter being applied (show all records).
- What happens when both start and end of a range filter are empty? No filter should be applied.
- How does the system handle invalid filter input (e.g., non-numeric text in a number range)? Invalid values should be ignored or sanitized, with the filter not applied rather than causing errors.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST auto-derive filter types from Ash attribute types (Boolean -> boolean filter, Integer/Float -> range filter, Date/DateTime -> date range filter)
- **FR-002**: System MUST auto-derive dropdown/select filters for attributes with `one_of` constraints (both Atom and String types)
- **FR-003**: System MUST auto-derive multi-select filters for array attributes with `one_of` constraints
- **FR-004**: System MUST allow developers to override auto-derived filter modules by specifying an explicit module in the filter declaration
- **FR-005**: System MUST raise a compile-time error when a filter cannot be auto-derived and no module is specified
- **FR-006**: System MUST generate filter labels from attribute names by default (e.g., `inserted_at` -> "Inserted At")
- **FR-007**: System MUST allow developers to override filter labels via a `label` option
- **FR-008**: System MUST auto-derive select/multi-select options from `one_of` constraints when options are not explicitly provided
- **FR-009**: Filters MUST use Ash.Expr expressions for safe, validated query filtering (not raw Ecto queries)
- **FR-010**: Filter values MUST be sanitized and validated before being applied to queries
- **FR-011**: Empty or invalid filter values MUST result in no filter being applied (not errors)

### Key Entities

- **Filter Configuration**: Represents a filter declaration in the DSL with attribute name, optional module override, label, options, and type hints
- **Filter Module**: A module implementing the filter behavior with UI rendering (delegated to Backpex) and query expression generation (using Ash.Expr)

### Assumptions

- Backpex filter modules handle UI rendering; AshBackpex filter modules will delegate to Backpex for rendering and implement Ash.Expr generation for queries
- The existing field type derivation pattern in the transformer can be extended for filter type derivation
- Filter values from the UI arrive as strings and need type-appropriate parsing (boolean strings, date strings, numeric strings)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can declare a filter with just an attribute name (e.g., `filter :published`) and have a working filter without creating any custom modules
- **SC-002**: 100% of supported Ash types (Boolean, Integer, Float, Date, DateTime, Atom with one_of, String with one_of, arrays with one_of) are correctly auto-derived to appropriate filter types
- **SC-003**: Filters produce correct query results - filtered lists contain only records matching the filter criteria
- **SC-004**: All filter operations use Ash.Expr expressions, ensuring query safety and validation
- **SC-005**: Invalid filter inputs (malformed dates, non-numeric values in number fields) do not cause runtime errors
