# Auto-Derived Ash-Native Filters

## Phase 1: Setup

### T001 Create filters directory at lib/ash_backpex/filters/

Create the new filters directory structure for AshBackpex filter modules.

---

### T002 Create filters test directory at test/ash_backpex/filters/

Create the test directory for filter module tests.

---

## Phase 2: Foundational

### T003 Create Filter behavior module at lib/ash_backpex/filters/filter.ex

Create the base behavior module with `to_ash_expr/3` callback and optional `validate_value/2` callback.

---

### T004 Extend Filter struct in lib/ash_backpex/live_resource/dsl.ex

Add optional fields to Filter struct: `options`, `prompt`, `type`.

---

### T005 Update filter entity schema in lib/ash_backpex/live_resource/dsl.ex

Make `module` optional in the filter entity schema to enable auto-derivation.

---

### T006 Update apply_filters/2 in lib/ash_backpex/adapter.ex

Update apply_filters/2 to handle new filter_config format with module.

---

### T007 Add apply_filter_with_module/5 in lib/ash_backpex/adapter.ex

Add helper function to call filter module's to_ash_expr/3 callback.

---

### T008 Add filterable test attributes in test/support/test_resources.ex

Add test attributes: published (boolean), status (atom with one_of), rating (integer), inserted_at (datetime), tags (array with one_of).

---

## Phase 3: User Story 1 - Basic Filter Declaration (MVP)

### T009 Write Boolean filter test in test/ash_backpex/filters/boolean_test.exs

Test Boolean filter to_ash_expr/3 with various inputs: true, false, list of values, empty.

---

### T010 Write Select filter test in test/ash_backpex/filters/select_test.exs

Test Select filter to_ash_expr/3 with string values, nil, empty string.

---

### T011 Write Range filter test (number) in test/ash_backpex/filters/range_test.exs

Test Range filter to_ash_expr/3 with number type: start only, end only, both, neither.

---

### T012 Write filter derivation test in test/ash_backpex/live_resource/transformer_test.exs

Test that Boolean, Select, Range filters are correctly derived from attribute types.

---

### T013 Write filter adapter integration test in test/ash_backpex/adapter_test.exs

Test that filters with modules correctly apply to Ash queries.

---

### T014 Implement Boolean filter in lib/ash_backpex/filters/boolean.ex

Implement Boolean filter with `use Backpex.Filters.Boolean` and `to_ash_expr/3`.

---

### T015 Implement Select filter in lib/ash_backpex/filters/select.ex

Implement Select filter with `use Backpex.Filters.Select` and `to_ash_expr/3`.

---

### T016 Implement Range filter (number) in lib/ash_backpex/filters/range.ex

Implement Range filter with `use Backpex.Filters.Range` and `to_ash_expr/3` for number type.

---

### T017 Add derive_filter_module/1 in lib/ash_backpex/live_resource/transformers/generate_backpex.ex

Add function to derive filter module from Ash attribute type.

---

### T018 Add derive_filter_type/1 in lib/ash_backpex/live_resource/transformers/generate_backpex.ex

Add function to derive filter type (:number, :date, :datetime) from attribute type.

---

### T019 Add derive_filter_options/2 in lib/ash_backpex/live_resource/transformers/generate_backpex.ex

Add function to derive options from one_of constraints.

---

### T020 Update @filters generation in lib/ash_backpex/live_resource/transformers/generate_backpex.ex

Update @filters module attribute generation to use derivation functions.

---

### T021 Verify US1 tests pass

Run: mix test test/ash_backpex/filters/boolean_test.exs test/ash_backpex/filters/select_test.exs test/ash_backpex/filters/range_test.exs

---

## Phase 4: User Story 2 - Filter Type Override

### T022 Write module override test in test/ash_backpex/live_resource/transformer_test.exs

Test that explicit module in filter declaration overrides auto-derivation.

---

### T023 Write undecidable type error test in test/ash_backpex/live_resource/transformer_test.exs

Test that compile-time error is raised for undecidable types without explicit module.

---

### T024 Add module override logic in lib/ash_backpex/live_resource/transformers/generate_backpex.ex

Use explicit module when provided, fall back to derivation.

---

### T025 Add compile-time error for undecidable types in lib/ash_backpex/live_resource/transformers/generate_backpex.ex

Raise helpful compile-time error when filter cannot be auto-derived.

---

### T026 Verify US2 tests pass

Run: mix test test/ash_backpex/live_resource/transformer_test.exs

---

## Phase 5: User Story 3 - Date/DateTime Range Filtering

### T027 Write Range filter test (date) in test/ash_backpex/filters/range_test.exs

Test Range filter to_ash_expr/3 with date type parsing.

---

### T028 Write Range filter test (datetime) in test/ash_backpex/filters/range_test.exs

Test Range filter to_ash_expr/3 with datetime type parsing.

---

### T029 Write partial range test in test/ash_backpex/filters/range_test.exs

Test start-only and end-only range filters for all types.

---

### T030 Add date parsing to Range filter in lib/ash_backpex/filters/range.ex

Add Date.from_iso8601 parsing to parse_value/2.

---

### T031 Add datetime parsing to Range filter in lib/ash_backpex/filters/range.ex

Add DateTime.from_iso8601 parsing to parse_value/2.

---

### T032 Add Date/DateTime derivation in lib/ash_backpex/live_resource/transformers/generate_backpex.ex

Add Date, DateTime, UtcDatetime, etc. to derive_filter_module/1.

---

### T033 Add date/datetime to derive_filter_type/1 in lib/ash_backpex/live_resource/transformers/generate_backpex.ex

Return :date or :datetime for appropriate types.

---

### T034 Verify US3 tests pass

Run: mix test test/ash_backpex/filters/range_test.exs

---

## Phase 6: User Story 4 - Multi-Select Array Filtering

### T035 Write MultiSelect filter test in test/ash_backpex/filters/multi_select_test.exs

Test MultiSelect filter to_ash_expr/3 with list values, empty list, nil.

---

### T036 Write array type derivation test in test/ash_backpex/live_resource/transformer_test.exs

Test that array types with one_of constraints derive to MultiSelect.

---

### T037 Implement MultiSelect filter in lib/ash_backpex/filters/multi_select.ex

Implement MultiSelect filter with `use Backpex.Filters.MultiSelect` and `to_ash_expr/3`.

---

### T038 Add array type derivation in lib/ash_backpex/live_resource/transformers/generate_backpex.ex

Add {:array, _} with one_of to derive_filter_module/1.

---

### T039 Verify US4 tests pass

Run: mix test test/ash_backpex/filters/multi_select_test.exs

---

## Phase 7: Polish

### T040 Run full test suite

Run: mix test

---

### T041 Run code quality checks

Run: mix ci (credo --strict && sobelow)

---

### T042 Add moduledoc to filter modules

Add documentation to all new filter modules in lib/ash_backpex/filters/.

---

### T043 Update DSL documentation in lib/ash_backpex/live_resource/dsl.ex

Update moduledoc to document new filter auto-derivation feature.

---

### T044 Verify quickstart scenarios in demo app

Test quickstart.md scenarios work in demo application.
