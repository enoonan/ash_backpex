defmodule AshBackpex.LiveResource.TransformerTest do
  use ExUnit.Case, async: true

  describe "generated module callbacks" do
    test "implements all required Backpex.LiveResource callbacks" do
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

    test "singular_name and plural_name are derived from resource name" do
      assert TestMinimalLive.singular_name() == "User"
      assert TestMinimalLive.plural_name() == "Users"
    end

    test "custom singular_name and plural_name from DSL" do
      assert TestCustomNamesLive.singular_name() == "Article"
      assert TestCustomNamesLive.plural_name() == "Articles"
    end

    test "fields callback returns correct field definitions" do
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

    test "filters callback returns filter definitions" do
      filters = TestPostLive.filters()

      assert is_list(filters)
      assert Keyword.keyword?(filters)

      # Check the published filter exists
      assert Keyword.has_key?(filters, :published)
      published_filter = Keyword.get(filters, :published)
      assert published_filter.module == Backpex.Filters.Boolean
      assert published_filter.label == "Published"
    end

    test "panels callback returns empty list by default" do
      assert TestPostLive.panels() == []
    end

    test "resource_actions callback returns empty list by default" do
      assert TestPostLive.resource_actions() == []
    end

    test "metrics callback returns empty list by default" do
      assert TestPostLive.metrics() == []
    end
  end

  describe "field type derivation" do
    test "derives correct Backpex field types from Ash attributes" do
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

      # Array -> MultiSelect (should be derived correctly)
      # assert Keyword.get(fields, :tags).module == Backpex.Fields.MultiSelect

      # Belongs to -> BelongsTo
      assert Keyword.get(fields, :author).module == Backpex.Fields.BelongsTo
    end

    test "includes calculations as fields" do
      fields = TestPostLive.fields()

      # Calculation
      assert Keyword.has_key?(fields, :word_count)
      word_count_field = Keyword.get(fields, :word_count)
      assert word_count_field.module == Backpex.Fields.Number
    end
  end

  describe "authorization integration" do
    test "can? callback exists and has correct arity" do
      Code.ensure_loaded!(TestPostLive)
      assert function_exported?(TestPostLive, :can?, 3)
    end

    test "can? defaults to true for index, show if no user is present" do
      # Without user - should allow index
      assigns = %{}
      assert TestPostLive.can?(assigns, :index, nil) == true
      assert TestPostLive.can?(assigns, :show, nil) == true
    end

    test "can? defaults to false for edit, delete if no user is present" do
      # Without user - should deny edit, delete
      assigns = %{}
      assert TestPostLive.can?(assigns, :edit, nil) == false
      assert TestPostLive.can?(assigns, :delete, nil) == false
      assert TestPostLive.can?(assigns, :new, nil) == false
    end
  end
end
