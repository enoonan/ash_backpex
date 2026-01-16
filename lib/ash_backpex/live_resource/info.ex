defmodule AshBackpex.LiveResource.Info do
  @moduledoc """
  Auto-generated introspection functions for AshBackpex LiveResources.

  This module uses `Spark.InfoGenerator` to create helper functions for
  inspecting the DSL configuration of AshBackpex LiveResources at runtime.

  ## Available Functions

  The generated functions allow you to introspect a LiveResource's configuration:

  - `backpex_resource/1` - Get the configured Ash resource module
  - `backpex_layout/1` - Get the layout configuration
  - `backpex_load/1` - Get the load configuration
  - `backpex_create_action/1` - Get the create action name
  - `backpex_read_action/1` - Get the read action name
  - `backpex_update_action/1` - Get the update action name
  - `backpex_destroy_action/1` - Get the destroy action name
  - `backpex_singular_name/1` - Get the singular display name
  - `backpex_plural_name/1` - Get the plural display name
  - `backpex_fields/1` - Get all configured fields
  - `backpex_filters/1` - Get all configured filters
  - `backpex_item_actions/1` - Get all configured item actions
  - And more for each DSL option...

  ## Usage

  ```elixir
  # Get the Ash resource for a LiveResource
  AshBackpex.LiveResource.Info.backpex_resource(MyAppWeb.Admin.PostLive)
  # => MyApp.Blog.Post

  # Get configured fields
  AshBackpex.LiveResource.Info.backpex_fields(MyAppWeb.Admin.PostLive)
  # => [%AshBackpex.LiveResource.Dsl.Field{attribute: :title, ...}, ...]
  ```

  These functions are primarily useful for debugging, testing, or building
  tools that need to inspect LiveResource configurations.
  """
  use Spark.InfoGenerator, extension: AshBackpex.LiveResource.Dsl, sections: [:backpex]
end
