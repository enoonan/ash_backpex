# Tasks: Auto-Derived Ash-Native Filters

**Input**: Design documents from `/specs/001-ash-native-filters/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: TDD approach required per constitution check in plan.md - tests written before implementation.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Source**: `lib/ash_backpex/` at repository root
- **Tests**: `test/ash_backpex/` at repository root
- **Support**: `test/support/` at repository root

---

## Phase 1: Setup

**Purpose**: Create directory structure for new filter modules

- [ ] T001 Create filters directory at lib/ash_backpex/filters/
- [ ] T002 Create filters test directory at test/ash_backpex/filters/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 Create Filter behavior module with to_ash_expr/3 callback at lib/ash_backpex/filters/filter.ex
- [ ] T004 Extend Filter struct with optional fields (options, prompt, type) in lib/ash_backpex/live_resource/dsl.ex
- [ ] T005 Update filter entity schema to make module optional in lib/ash_backpex/live_resource/dsl.ex
- [ ] T006 Update apply_filters/2 to handle filter_config with module in lib/ash_backpex/adapter.ex
- [ ] T007 Add helper function apply_filter_with_module/5 in lib/ash_backpex/adapter.ex
- [ ] T008 Add filterable test attributes (published, status, rating, inserted_at, tags) to test resources in test/support/test_resources.ex

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Basic Filter Declaration (Priority: P1) MVP

**Goal**: Developers can declare filters by attribute name only and get auto-derived filter types

**Independent Test**: Declare `filter :published` on a boolean attribute and verify checkbox filter appears and correctly filters records

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T009 [P] [US1] Write test for Boolean filter to_ash_expr/3 in test/ash_backpex/filters/boolean_test.exs
- [ ] T010 [P] [US1] Write test for Select filter to_ash_expr/3 in test/ash_backpex/filters/select_test.exs
- [ ] T011 [P] [US1] Write test for Range filter to_ash_expr/3 (number type) in test/ash_backpex/filters/range_test.exs
- [ ] T012 [P] [US1] Write test for filter type derivation (Boolean, Select, Range) in test/ash_backpex/live_resource/transformer_test.exs
- [ ] T013 [P] [US1] Write test for filter integration with adapter in test/ash_backpex/adapter_test.exs

### Implementation for User Story 1

- [ ] T014 [P] [US1] Implement Boolean filter module with to_ash_expr/3 in lib/ash_backpex/filters/boolean.ex
- [ ] T015 [P] [US1] Implement Select filter module with to_ash_expr/3 in lib/ash_backpex/filters/select.ex
- [ ] T016 [P] [US1] Implement Range filter module with to_ash_expr/3 (number type) in lib/ash_backpex/filters/range.ex
- [ ] T017 [US1] Add derive_filter_module/1 function to transformer in lib/ash_backpex/live_resource/transformers/generate_backpex.ex
- [ ] T018 [US1] Add derive_filter_type/1 function to transformer in lib/ash_backpex/live_resource/transformers/generate_backpex.ex
- [ ] T019 [US1] Add derive_filter_options/2 function to transformer in lib/ash_backpex/live_resource/transformers/generate_backpex.ex
- [ ] T020 [US1] Update @filters generation to use derivation functions in lib/ash_backpex/live_resource/transformers/generate_backpex.ex
- [ ] T021 [US1] Run tests and verify US1 passes: mix test test/ash_backpex/filters/boolean_test.exs test/ash_backpex/filters/select_test.exs test/ash_backpex/filters/range_test.exs

**Checkpoint**: User Story 1 complete - Boolean, Select, and numeric Range filters work with auto-derivation

---

## Phase 4: User Story 2 - Filter Type Override (Priority: P2)

**Goal**: Developers can explicitly specify filter modules and get helpful errors for undecidable types

**Independent Test**: Declare `filter :field, module: CustomFilter` and verify the explicit module is used

### Tests for User Story 2

- [ ] T022 [P] [US2] Write test for explicit module override in transformer in test/ash_backpex/live_resource/transformer_test.exs
- [ ] T023 [P] [US2] Write test for compile-time error on undecidable type in test/ash_backpex/live_resource/transformer_test.exs

### Implementation for User Story 2

- [ ] T024 [US2] Add module override logic (use explicit if provided) in lib/ash_backpex/live_resource/transformers/generate_backpex.ex
- [ ] T025 [US2] Add compile-time error with helpful message for undecidable types in lib/ash_backpex/live_resource/transformers/generate_backpex.ex
- [ ] T026 [US2] Run tests and verify US2 passes: mix test test/ash_backpex/live_resource/transformer_test.exs

**Checkpoint**: User Story 2 complete - Explicit overrides work and helpful errors shown

---

## Phase 5: User Story 3 - Date/DateTime Range Filtering (Priority: P2)

**Goal**: Admin users can filter records by date ranges

**Independent Test**: Declare filter on datetime attribute and verify date range picker filters records correctly

### Tests for User Story 3

- [ ] T027 [P] [US3] Write test for Range filter to_ash_expr/3 (date type) in test/ash_backpex/filters/range_test.exs
- [ ] T028 [P] [US3] Write test for Range filter to_ash_expr/3 (datetime type) in test/ash_backpex/filters/range_test.exs
- [ ] T029 [P] [US3] Write test for partial range (start only, end only) in test/ash_backpex/filters/range_test.exs

### Implementation for User Story 3

- [ ] T030 [US3] Add date parsing to Range filter parse_value/2 in lib/ash_backpex/filters/range.ex
- [ ] T031 [US3] Add datetime parsing to Range filter parse_value/2 in lib/ash_backpex/filters/range.ex
- [ ] T032 [US3] Add Date/DateTime type derivation to derive_filter_module/1 in lib/ash_backpex/live_resource/transformers/generate_backpex.ex
- [ ] T033 [US3] Add date/datetime to derive_filter_type/1 in lib/ash_backpex/live_resource/transformers/generate_backpex.ex
- [ ] T034 [US3] Run tests and verify US3 passes: mix test test/ash_backpex/filters/range_test.exs

**Checkpoint**: User Story 3 complete - Date and DateTime range filtering works

---

## Phase 6: User Story 4 - Multi-Select Array Filtering (Priority: P3)

**Goal**: Admin users can filter by selecting multiple values from array field options

**Independent Test**: Declare filter on array attribute with one_of constraint and verify multi-checkbox filter works

### Tests for User Story 4

- [ ] T035 [P] [US4] Write test for MultiSelect filter to_ash_expr/3 in test/ash_backpex/filters/multi_select_test.exs
- [ ] T036 [P] [US4] Write test for array type derivation in test/ash_backpex/live_resource/transformer_test.exs

### Implementation for User Story 4

- [ ] T037 [US4] Implement MultiSelect filter module with to_ash_expr/3 in lib/ash_backpex/filters/multi_select.ex
- [ ] T038 [US4] Add array type derivation to derive_filter_module/1 in lib/ash_backpex/live_resource/transformers/generate_backpex.ex
- [ ] T039 [US4] Run tests and verify US4 passes: mix test test/ash_backpex/filters/multi_select_test.exs

**Checkpoint**: User Story 4 complete - MultiSelect array filtering works

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation

- [ ] T040 Run full test suite: mix test
- [ ] T041 Run code quality checks: mix ci (credo --strict && sobelow)
- [ ] T042 [P] Add moduledoc to all new filter modules
- [ ] T043 [P] Update DSL documentation in lib/ash_backpex/live_resource/dsl.ex
- [ ] T044 Verify quickstart.md scenarios work in demo app

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 (P1): Can proceed first - delivers MVP
  - US2 (P2): Can proceed after US1 or in parallel
  - US3 (P2): Can proceed after US1 or in parallel
  - US4 (P3): Can proceed after US1 or in parallel
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies on other stories - delivers MVP
- **User Story 2 (P2)**: Independent - adds override capability
- **User Story 3 (P2)**: Independent - extends range filter
- **User Story 4 (P3)**: Independent - adds multi-select filter

### Within Each User Story (TDD Order)

1. Write tests FIRST - ensure they FAIL
2. Implement filter modules (can be parallel)
3. Implement transformer changes
4. Run tests to verify story complete

### Parallel Opportunities

**Phase 2 (Foundational)**:
- T003, T004, T005, T006, T007, T008 must be sequential (depend on each other)

**Phase 3 (US1)**:
- Tests T009, T010, T011, T012, T013 can run in parallel
- Filter implementations T014, T015, T016 can run in parallel
- Transformer changes T017-T020 must be sequential

**Phase 4-6 (US2-US4)**:
- Tests within each story can run in parallel
- Different user stories can be worked on in parallel by different developers

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Write test for Boolean filter to_ash_expr/3 in test/ash_backpex/filters/boolean_test.exs"
Task: "Write test for Select filter to_ash_expr/3 in test/ash_backpex/filters/select_test.exs"
Task: "Write test for Range filter to_ash_expr/3 in test/ash_backpex/filters/range_test.exs"

# Launch all filter implementations together:
Task: "Implement Boolean filter module in lib/ash_backpex/filters/boolean.ex"
Task: "Implement Select filter module in lib/ash_backpex/filters/select.ex"
Task: "Implement Range filter module in lib/ash_backpex/filters/range.ex"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (2 tasks)
2. Complete Phase 2: Foundational (6 tasks)
3. Complete Phase 3: User Story 1 (13 tasks)
4. **STOP and VALIDATE**: Test auto-derived Boolean, Select, Range filters
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Test → MVP with basic filters
3. Add User Story 2 → Test → Override capability
4. Add User Story 3 → Test → Date/time filtering
5. Add User Story 4 → Test → Array filtering
6. Polish → Production ready

---

## Summary

| Phase | Story | Task Count | Parallel Tasks |
|-------|-------|------------|----------------|
| 1 | Setup | 2 | 0 |
| 2 | Foundational | 6 | 0 |
| 3 | US1 (P1) | 13 | 8 |
| 4 | US2 (P2) | 5 | 2 |
| 5 | US3 (P2) | 8 | 3 |
| 6 | US4 (P3) | 5 | 2 |
| 7 | Polish | 5 | 2 |
| **Total** | | **44** | **17** |

**MVP Scope**: Phases 1-3 (21 tasks) delivers working auto-derived filters for Boolean, Select, and numeric Range types.
