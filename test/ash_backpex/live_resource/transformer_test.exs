defmodule AshBackpex.LiveResource.TransformerTest do
  use ExUnit.Case, async: false

  describe "generated module callbacks :: it can" do
    test "implement all required Backpex.LiveResource callbacks" do
      # Test required callbacks exist
      assert function_exported?(TestPostLive, :singular_name, 0)
      assert function_exported?(TestPostLive, :plural_name, 0)
      assert function_exported?(TestPostLive, :fields, 0)

      # Test optional callbacks exist
      assert function_exported?(TestPostLive, :filters, 0)
      assert function_exported?(TestPostLive, :item_actions, 1)
      assert function_exported?(TestPostLive, :panels, 0)
      assert function_exported?(TestPostLive, :can?, 3)
      assert function_exported?(TestPostLive, :resource_actions, 0)
      assert function_exported?(TestPostLive, :metrics, 0)
    end

    test "derive singular_name and plural_name are from resource name" do
      assert TestMinimalLive.singular_name() == "User"
      assert TestMinimalLive.plural_name() == "Users"
    end

    test "use custom singular_name and plural_name from DSL" do
      assert TestCustomNamesLive.singular_name() == "Article"
      assert TestCustomNamesLive.plural_name() == "Articles"
    end

    test "return correct field definitions from fields/0" do
      fields = TestPostLive.fields()

      # Check it returns a keyword list
      assert is_list(fields)
      assert Keyword.keyword?(fields)

      # Check specific fields exist
      assert Keyword.has_key?(fields, :title)
      assert Keyword.has_key?(fields, :content)
      assert Keyword.has_key?(fields, :published)

      # Check field configuration
      title_field = Keyword.get(fields, :title)
      assert is_map(title_field)
      assert title_field.label == "Title"

      content_field = Keyword.get(fields, :content)
      assert content_field.module == Backpex.Fields.Textarea
    end

    test "return correct filter definitions from filters/0" do
      filters = TestPostLive.filters()

      assert is_list(filters)
      assert Keyword.keyword?(filters)

      # Check the published filter exists
      assert Keyword.has_key?(filters, :published)
      published_filter = Keyword.get(filters, :published)
      assert published_filter.module == Backpex.Filters.Boolean
      assert published_filter.label == "Published"
    end

    test "return empty list by default from panels/0" do
      assert TestPostLive.panels() == []
    end

    test "return empty list by default from resource_actions/0" do
      assert TestPostLive.resource_actions() == []
    end

    test "return empty list by default from metrics/0" do
      assert TestPostLive.metrics() == []
    end
  end

  describe "field type derivation :: it can" do
    test "derive correct Backpex field types from Ash attributes" do
      fields = TestPostLive.fields()

      # String -> Text
      assert Keyword.get(fields, :title).module == Backpex.Fields.Text

      # Boolean -> Boolean
      assert Keyword.get(fields, :published).module == Backpex.Fields.Boolean

      # DateTime -> DateTime
      assert Keyword.get(fields, :published_at).module == Backpex.Fields.DateTime

      # Integer -> Number
      assert Keyword.get(fields, :view_count).module == Backpex.Fields.Number

      # Float -> Number
      assert Keyword.get(fields, :rating).module == Backpex.Fields.Number

      # Atom with constraints -> Select
      assert Keyword.get(fields, :status).module == Backpex.Fields.Select

      # Array with constraints -> MultiSelect
      assert Keyword.get(fields, :tags).module == Backpex.Fields.MultiSelect

      # Belongs to -> BelongsTo
      assert Keyword.get(fields, :author).module == Backpex.Fields.BelongsTo
    end

    test "derive default and non-default primary key with init_order" do
      assert TestPostLive.config(:primary_key) == :id

      assert TestPostLive.config(:init_order) == %{
               direction: :asc,
               by: :id
             }

      assert TestNonDefaultPrimaryKeyNameLive.config(:primary_key) == :foo_key

      assert TestNonDefaultPrimaryKeyNameLive.config(:init_order) == %{
               direction: :asc,
               by: :foo_key
             }
    end

    test "include calculations as fields" do
      fields = TestPostLive.fields()
      # Calculation
      assert Keyword.has_key?(fields, :word_count)
      word_count_field = Keyword.get(fields, :word_count)
      assert word_count_field.module == Backpex.Fields.Number
    end
  end

  describe "authorization integration :: it can" do
    test "export can?/3 callback" do
      Code.ensure_loaded!(TestPostLive)
      assert function_exported?(TestPostLive, :can?, 3)
    end
  end

  describe "return correct placement for item_actions" do
    test "include :only option in item action config" do
      item_actions = TestCustomItemActionLiveWithOnly.item_actions([])

      assert Keyword.has_key?(item_actions, :promote)
      promote_config = Keyword.get(item_actions, :promote)
      assert promote_config.only == [:row]
    end

    test "include :except option in item action config" do
      item_actions = TestCustomItemActionLiveWithExcept.item_actions([])

      assert Keyword.has_key?(item_actions, :promote)
      promote_config = Keyword.get(item_actions, :promote)
      assert promote_config.except == [:index]
    end

    test "not include :only when not specified" do
      item_actions = TestCustomItemActionLive.item_actions([])

      promote_config = Keyword.get(item_actions, :promote)
      refute Map.has_key?(promote_config, :only)
    end

    test "not include :except when not specified" do
      item_actions = TestCustomItemActionLiveWithOnly.item_actions([])

      promote_config = Keyword.get(item_actions, :promote)
      refute Map.has_key?(promote_config, :except)
    end
  end

  describe "custom field type mappings :: backward compatibility" do
    # These tests verify that modules compiled without custom config still work.
    # Note: The custom field type mappings are read at compile time. Testing
    # compile-time behavior requires compiling modules with config already set.
    # Full integration tests are in a separate test file that sets up config
    # before module compilation.

    test "modules compiled without config use default type mappings" do
      # TestPostLive was compiled without custom mappings set
      fields = TestPostLive.fields()

      # String -> Text (default)
      title_field = Keyword.get(fields, :title)
      assert title_field.module == Backpex.Fields.Text

      # Boolean -> Boolean (default)
      published_field = Keyword.get(fields, :published)
      assert published_field.module == Backpex.Fields.Boolean

      # Integer -> Number (default)
      view_count_field = Keyword.get(fields, :view_count)
      assert view_count_field.module == Backpex.Fields.Number
    end

    test "explicit DSL module option is always preserved" do
      # The content field in TestPostLive has explicit module: Backpex.Fields.Textarea
      # This verifies the precedence: DSL module > custom config > defaults
      fields = TestPostLive.fields()
      content_field = Keyword.get(fields, :content)

      assert content_field.module == Backpex.Fields.Textarea
    end
  end

  describe "function-based field type mappings" do
    # Note: These tests use compile-time evaluation of functions set before module
    # compilation. Since TestPostLive is already compiled, we test the function
    # interface through unit tests of the lookup logic.

    test "function receives type and constraints arguments" do
      # This test verifies the function signature is (type, constraints) -> module | nil
      # We test by setting up a function that tracks its calls
      :persistent_term.put({__MODULE__, :fn_args}, nil)

      mapping_fn = fn type, constraints ->
        :persistent_term.put({__MODULE__, :fn_args}, {type, constraints})
        nil
      end

      Application.put_env(:ash_backpex, :field_type_mappings, mapping_fn)

      # Call the config to get the function
      result = AshBackpex.Config.field_type_mappings()
      assert is_function(result, 2)

      # Test that calling it with specific args stores them
      result.(Ash.Type.String, max_length: 100)
      assert :persistent_term.get({__MODULE__, :fn_args}) == {Ash.Type.String, [max_length: 100]}

      # Clean up
      Application.delete_env(:ash_backpex, :field_type_mappings)
      :persistent_term.erase({__MODULE__, :fn_args})
    end

    test "function returning nil falls back to default mapping" do
      # A function that always returns nil should cause fallback to defaults
      mapping_fn = fn _type, _constraints -> nil end
      Application.put_env(:ash_backpex, :field_type_mappings, mapping_fn)

      # The function returning nil means the transformer will use default mappings
      result = AshBackpex.Config.field_type_mappings()
      assert is_function(result, 2)
      assert result.(Ash.Type.String, []) == nil

      # Clean up
      Application.delete_env(:ash_backpex, :field_type_mappings)
    end

    test "function returning module is used as field type" do
      mapping_fn = fn
        Ash.Type.String, _constraints -> Backpex.Fields.Textarea
        _type, _constraints -> nil
      end

      Application.put_env(:ash_backpex, :field_type_mappings, mapping_fn)

      result = AshBackpex.Config.field_type_mappings()
      assert result.(Ash.Type.String, []) == Backpex.Fields.Textarea
      assert result.(Ash.Type.Integer, []) == nil

      # Clean up
      Application.delete_env(:ash_backpex, :field_type_mappings)
    end

    test "function can use constraints to determine field type" do
      mapping_fn = fn type, constraints ->
        case {type, Keyword.get(constraints, :max_length)} do
          {Ash.Type.String, max} when is_integer(max) and max > 500 ->
            Backpex.Fields.Textarea

          _ ->
            nil
        end
      end

      Application.put_env(:ash_backpex, :field_type_mappings, mapping_fn)

      result = AshBackpex.Config.field_type_mappings()
      # Long string -> Textarea
      assert result.(Ash.Type.String, max_length: 1000) == Backpex.Fields.Textarea
      # Short string -> nil (use default)
      assert result.(Ash.Type.String, max_length: 100) == nil
      # No max_length -> nil (use default)
      assert result.(Ash.Type.String, []) == nil

      # Clean up
      Application.delete_env(:ash_backpex, :field_type_mappings)
    end
  end
end
