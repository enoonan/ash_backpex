defmodule AshBackpex.LiveResource.TransformerTest do
  use ExUnit.Case, async: true

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
end
