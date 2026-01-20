# Quickstart: Auto-Derived Ash-Native Filters

**Feature**: 001-ash-native-filters
**Date**: 2026-01-20

## Overview

This guide shows how to add filters to your AshBackpex LiveResource using the new auto-derivation feature.

## Basic Usage

### Before (Explicit Module Required)

```elixir
defmodule MyAppWeb.Admin.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource MyApp.Blog.Post
    layout {MyAppWeb.Layouts, :admin}

    filters do
      filter :published do
        module Backpex.Filters.Boolean  # Required
      end

      filter :status do
        module Backpex.Filters.Select   # Required
        # Must manually provide options
      end
    end
  end
end
```

### After (Auto-Derived)

```elixir
defmodule MyAppWeb.Admin.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource MyApp.Blog.Post
    layout {MyAppWeb.Layouts, :admin}

    filters do
      filter :published          # Auto-derives Boolean filter
      filter :status             # Auto-derives Select from one_of constraint
      filter :rating             # Auto-derives Range for integer
      filter :inserted_at        # Auto-derives DateTime range
    end
  end
end
```

## Filter Types

### Boolean Filter

For `Ash.Type.Boolean` attributes:

```elixir
# In your Ash resource
attribute :published, :boolean, default: false

# In your LiveResource
filter :published  # Renders checkboxes for true/false
```

### Select Filter

For attributes with `one_of` constraint:

```elixir
# In your Ash resource
attribute :status, :atom do
  constraints one_of: [:draft, :published, :archived]
end

# In your LiveResource
filter :status  # Renders dropdown with Draft, Published, Archived options
```

### Range Filter

For numeric and date/time attributes:

```elixir
# Numeric range
attribute :rating, :integer

filter :rating  # Renders min/max number inputs

# Date range
attribute :published_at, :utc_datetime

filter :published_at  # Renders date range picker
```

### MultiSelect Filter

For array attributes with `one_of` constraint:

```elixir
# In your Ash resource
attribute :tags, {:array, :atom} do
  constraints items: [one_of: [:elixir, :phoenix, :ash]]
end

# In your LiveResource
filter :tags  # Renders multiple checkboxes
```

## Customization

### Custom Label

```elixir
filter :inserted_at do
  label "Created Date"
end
```

### Custom Options (Select/MultiSelect)

```elixir
filter :status do
  options [
    {"Not Published", :draft},
    {"Live", :published},
    {"Hidden", :archived}
  ]
end
```

### Explicit Module Override

```elixir
filter :custom_field do
  module MyApp.CustomFilter
end
```

## Error Handling

If a filter cannot be auto-derived, you'll see a compile-time error:

```
Unable to derive filter module for :custom_field.

Specify a module explicitly:
  filter :custom_field do
    module AshBackpex.Filters.Select
  end
```

This happens when:
- Attribute type is not in the supported list
- Attribute has no `one_of` constraint (for String/Atom without module)
- Attribute doesn't exist on the resource

## Migration Guide

Existing filters with explicit modules continue to work. To migrate:

1. Remove `module` option for supported types
2. Remove `options` if they match `one_of` constraint
3. Test that filters render and function correctly

```elixir
# Before
filter :status do
  module Backpex.Filters.Select
  options [{"Draft", :draft}, {"Published", :published}]
end

# After (if one_of constraint matches)
filter :status
```
