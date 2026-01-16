# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ash Backpex is an Elixir library that integrates the Ash Framework with Backpex to provide admin interface capabilities for Ash resources. It uses Spark DSL for compile-time code generation.

**Status**: Pre-1.0 (v0.0.13), expect breaking API changes. Backpex itself is also pre-1.0.

## Commands

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Run a single test file
mix test test/ash_backpex/adapter_test.exs

# Run a specific test by line number
mix test test/ash_backpex/adapter_test.exs:42

# Code quality (linting + security)
mix ci                    # runs credo --strict && sobelow

# Individual checks
mix credo --strict        # linting
mix sobelow              # security scan

# Format code
mix format

# Generate docs
mix docs
```

### Demo Application

```bash
cd demo
mix deps.get
mix ecto.create && mix ecto.migrate
mix assets.setup
mix phx.server            # http://localhost:4000/
```

## Architecture

### Core Components

- **`AshBackpex.LiveResource`** (`lib/ash_backpex/live_resource.ex`) - Entry point, uses Spark DSL
- **`AshBackpex.LiveResource.Dsl`** (`lib/ash_backpex/live_resource/dsl.ex`) - DSL configuration for fields, filters, actions
- **`AshBackpex.LiveResource.Transformers.GenerateBackpex`** (`lib/ash_backpex/live_resource/transformers/generate_backpex.ex`) - Compile-time transformer that generates Backpex LiveResource code from DSL
- **`AshBackpex.Adapter`** (`lib/ash_backpex/adapter.ex`) - Implements `Backpex.Adapter` behavior, handles CRUD through Ash resources

### Supporting Modules

- **`AshBackpex.LoadSelectResolver`** - Translates Backpex field configs to Ash loads/selects
- **`AshBackpex.BasicSearch`** - Multi-field search filtering via Ash.Expr
- **`AshBackpex.AshChangesetToPhoenixForm`** - FormData protocol implementation for Ash.Changeset

### How It Works

1. User defines a LiveResource module with `use AshBackpex.LiveResource` and a `backpex do ... end` block
2. At compile time, `GenerateBackpex` transformer reads the DSL configuration
3. Transformer generates Backpex-compatible code: derives field types from Ash attributes, handles relationships/calculations/aggregates
4. At runtime, `AshBackpex.Adapter` bridges Backpex operations to Ash resource actions

### Field Type Mapping

The transformer auto-maps Ash types to Backpex fields:
- `:string` → `Backpex.Fields.Text`
- `:boolean` → `Backpex.Fields.Boolean`
- `:datetime` → `Backpex.Fields.DateTime`
- `:integer`/`:float` → `Backpex.Fields.Number`
- Arrays with `one_of` constraints → `Backpex.Fields.MultiSelect`

## Testing

Tests use in-memory SQLite with fixtures defined in `test/support/`:
- `test_resources.ex` - Test Ash resources (Post, User, Comment, Item)
- `test_live.ex` - Test LiveResource definitions
- `test_domain.ex` - Test Ash domain
- `test_repo.ex` - Test Ecto repo (SQLite)
- `test_generators.ex` - Factory functions for test data
