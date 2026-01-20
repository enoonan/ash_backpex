defmodule AshBackpex.LiveResource.CustomFieldMappingsIntegrationTest do
  @moduledoc """
  Integration tests for custom field type mappings feature.

  These tests verify the full flow: configure mapping → define LiveResource →
  verify generated field uses custom module.

  Test coverage includes:
  - Default type override (map and function)
  - Custom/unusual Ash types
  - Array type mappings
  - Function-based mappings with constraint inspection
  - Explicit DSL module precedence over custom config
  - Multiple mapped types in a single LiveResource
  """
  use ExUnit.Case, async: false

  # Clean up config between tests
  setup do
    Application.delete_env(:ash_backpex, :field_type_mappings)
    Application.delete_env(:my_test_app, AshBackpex)

    on_exit(fn ->
      Application.delete_env(:ash_backpex, :field_type_mappings)
      Application.delete_env(:my_test_app, AshBackpex)
    end)

    :ok
  end

  describe "default type override integration" do
    test "map-based config overrides default String -> Text mapping" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => Backpex.Fields.Textarea
      })

      defmodule StringOverrideLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:title)
          end
        end
      end

      fields = StringOverrideLive.fields()
      # title is Ash.Type.String - should use custom Textarea instead of default Text
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
    end

    test "map-based config overrides default Boolean -> Boolean mapping" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.Boolean => Backpex.Fields.Select
      })

      defmodule BooleanOverrideLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:published)
          end
        end
      end

      fields = BooleanOverrideLive.fields()
      # published is Ash.Type.Boolean - should use custom Select
      assert Keyword.get(fields, :published).module == Backpex.Fields.Select
    end

    test "map-based config overrides default Integer -> Number mapping" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.Integer => Backpex.Fields.Text
      })

      defmodule IntegerOverrideLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:view_count)
          end
        end
      end

      fields = IntegerOverrideLive.fields()
      # view_count is Ash.Type.Integer - should use custom Text
      assert Keyword.get(fields, :view_count).module == Backpex.Fields.Text
    end

    test "map-based config overrides default Float -> Number mapping" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.Float => Backpex.Fields.Text
      })

      defmodule FloatOverrideLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:rating)
          end
        end
      end

      fields = FloatOverrideLive.fields()
      # rating is Ash.Type.Float - should use custom Text
      assert Keyword.get(fields, :rating).module == Backpex.Fields.Text
    end

    test "map-based config overrides default DateTime -> DateTime mapping" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.DateTime => Backpex.Fields.Text
      })

      defmodule DateTimeOverrideLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:published_at)
          end
        end
      end

      fields = DateTimeOverrideLive.fields()
      # published_at is Ash.Type.DateTime - should use custom Text
      assert Keyword.get(fields, :published_at).module == Backpex.Fields.Text
    end
  end

  describe "explicit module precedence integration" do
    test "DSL module option takes precedence over map-based custom config" do
      # Configure String to use Textarea
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => Backpex.Fields.Textarea
      })

      defmodule ExplicitModulePrecedenceLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # title with no explicit module - should use custom Textarea
            field(:title)

            # content with explicit module - should use the explicit one
            field :content do
              module(Backpex.Fields.Text)
            end
          end
        end
      end

      fields = ExplicitModulePrecedenceLive.fields()
      # title uses custom config mapping
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
      # content uses explicit DSL module, ignoring custom config
      assert Keyword.get(fields, :content).module == Backpex.Fields.Text
    end

    test "DSL module option takes precedence over function-based custom config" do
      # Configure function that maps String to Textarea
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        Ash.Type.String, _constraints -> Backpex.Fields.Textarea
        _type, _constraints -> nil
      end)

      defmodule ExplicitModulePrecedenceFnLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # title with no explicit module - should use function mapping
            field(:title)

            # content with explicit module - should use the explicit one
            field :content do
              module(Backpex.Fields.Number)
            end
          end
        end
      end

      fields = ExplicitModulePrecedenceFnLive.fields()
      # title uses function mapping
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
      # content uses explicit DSL module, ignoring function config
      assert Keyword.get(fields, :content).module == Backpex.Fields.Number
    end
  end

  describe "function-based mapping integration" do
    test "function-based config maps types correctly" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        Ash.Type.String, _constraints -> Backpex.Fields.Textarea
        Ash.Type.Integer, _constraints -> Backpex.Fields.Text
        _type, _constraints -> nil
      end)

      defmodule FunctionMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:title)
            field(:view_count)
            field(:published)
          end
        end
      end

      fields = FunctionMappingLive.fields()
      # String -> Textarea (function)
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
      # Integer -> Text (function)
      assert Keyword.get(fields, :view_count).module == Backpex.Fields.Text
      # Boolean -> Boolean (default, function returned nil)
      assert Keyword.get(fields, :published).module == Backpex.Fields.Boolean
    end

    test "function-based config can use constraints to determine field type" do
      # This function maps strings with one_of constraints to Select
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        Ash.Type.Atom, constraints ->
          case Keyword.get(constraints, :one_of) do
            [_ | _] -> Backpex.Fields.MultiSelect
            _ -> nil
          end

        _type, _constraints ->
          nil
      end)

      defmodule ConstraintFunctionMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # status has one_of constraint
            field(:status)
          end
        end
      end

      fields = ConstraintFunctionMappingLive.fields()
      # status is Atom with one_of constraint - should use MultiSelect from function
      assert Keyword.get(fields, :status).module == Backpex.Fields.MultiSelect
    end

    test "function returns nil and falls back to default mapping" do
      # Function that returns nil for everything
      Application.put_env(:ash_backpex, :field_type_mappings, fn _type, _constraints -> nil end)

      defmodule FallbackDefaultLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:title)
            field(:published)
            field(:view_count)
          end
        end
      end

      fields = FallbackDefaultLive.fields()
      # All should use default mappings since function returns nil
      assert Keyword.get(fields, :title).module == Backpex.Fields.Text
      assert Keyword.get(fields, :published).module == Backpex.Fields.Boolean
      assert Keyword.get(fields, :view_count).module == Backpex.Fields.Number
    end
  end

  describe "array type mapping integration" do
    test "map-based config maps array types correctly" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        {:array, Ash.Type.String} => Backpex.Fields.Textarea
      })

      defmodule ArrayMapLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # tags is {:array, Ash.Type.String}
            field(:tags)
          end
        end
      end

      fields = ArrayMapLive.fields()
      assert Keyword.get(fields, :tags).module == Backpex.Fields.Textarea
    end

    test "function-based config maps array types correctly" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        {:array, Ash.Type.String}, _constraints -> Backpex.Fields.Text
        _type, _constraints -> nil
      end)

      defmodule ArrayFunctionLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:tags)
          end
        end
      end

      fields = ArrayFunctionLive.fields()
      assert Keyword.get(fields, :tags).module == Backpex.Fields.Text
    end

    test "scalar and array mappings are independent" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => Backpex.Fields.Textarea,
        {:array, Ash.Type.String} => Backpex.Fields.Text
      })

      defmodule ScalarArrayIndependentIntegrationLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:title)
            field(:tags)
          end
        end
      end

      fields = ScalarArrayIndependentIntegrationLive.fields()
      # Scalar string -> Textarea
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
      # Array string -> Text
      assert Keyword.get(fields, :tags).module == Backpex.Fields.Text
    end

    test "function-based config can inspect array item constraints" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        {:array, Ash.Type.String}, constraints ->
          # Check for items constraints (Post.tags has items with match constraint)
          case Keyword.get(constraints, :items) do
            items when is_list(items) and length(items) > 0 -> Backpex.Fields.Text
            _ -> nil
          end

        _type, _constraints ->
          nil
      end)

      defmodule ArrayConstraintsLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:tags)
          end
        end
      end

      fields = ArrayConstraintsLive.fields()
      # tags has items constraints - function should map it to Text
      assert Keyword.get(fields, :tags).module == Backpex.Fields.Text
    end
  end

  describe "multiple field types in single LiveResource" do
    test "multiple fields use correct mappings from config" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => Backpex.Fields.Textarea,
        Ash.Type.Boolean => Backpex.Fields.Select,
        Ash.Type.Integer => Backpex.Fields.Text,
        {:array, Ash.Type.String} => Backpex.Fields.Text
      })

      defmodule MultiFieldMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:title)
            field(:content)
            field(:published)
            field(:view_count)
            field(:tags)
            # rating uses default since Float not in config
            field(:rating)
          end
        end
      end

      fields = MultiFieldMappingLive.fields()
      # String -> Textarea
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
      assert Keyword.get(fields, :content).module == Backpex.Fields.Textarea
      # Boolean -> Select
      assert Keyword.get(fields, :published).module == Backpex.Fields.Select
      # Integer -> Text
      assert Keyword.get(fields, :view_count).module == Backpex.Fields.Text
      # Array String -> Text
      assert Keyword.get(fields, :tags).module == Backpex.Fields.Text
      # Float -> Number (default, not in config)
      assert Keyword.get(fields, :rating).module == Backpex.Fields.Number
    end

    test "mix of custom mappings, defaults, and explicit modules" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        Ash.Type.String, _constraints -> Backpex.Fields.Textarea
        Ash.Type.Integer, _constraints -> Backpex.Fields.Text
        _type, _constraints -> nil
      end)

      defmodule MixedMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # title - custom function mapping (String -> Textarea)
            field(:title)

            # content - explicit module overrides custom mapping
            field :content do
              module(Backpex.Fields.Text)
            end

            # published - default mapping (Boolean -> Boolean)
            field(:published)

            # view_count - custom function mapping (Integer -> Text)
            field(:view_count)

            # rating - default mapping (Float -> Number)
            field(:rating)
          end
        end
      end

      fields = MixedMappingLive.fields()
      # Custom function mapping
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
      # Explicit module
      assert Keyword.get(fields, :content).module == Backpex.Fields.Text
      # Default mapping
      assert Keyword.get(fields, :published).module == Backpex.Fields.Boolean
      # Custom function mapping
      assert Keyword.get(fields, :view_count).module == Backpex.Fields.Text
      # Default mapping
      assert Keyword.get(fields, :rating).module == Backpex.Fields.Number
    end
  end

  describe "calculations and aggregates with custom mappings" do
    test "custom mappings apply to calculation return types" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.Integer => Backpex.Fields.Text
      })

      defmodule CalculationMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # word_count is a calculation returning :integer
            field(:word_count)
          end
        end
      end

      fields = CalculationMappingLive.fields()
      # calculation with integer return type should use custom mapping
      assert Keyword.get(fields, :word_count).module == Backpex.Fields.Text
    end

    test "custom mappings apply to string calculation return types" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => Backpex.Fields.Textarea
      })

      defmodule StringCalculationMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Item)
          layout({TestLayout, :admin})

          fields do
            # name_note is a calculation returning :string
            field(:name_note)
          end
        end
      end

      fields = StringCalculationMappingLive.fields()
      # calculation with string return type should use custom mapping
      assert Keyword.get(fields, :name_note).module == Backpex.Fields.Textarea
    end
  end

  describe "empty and nil config handling" do
    test "empty map config falls back to defaults" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{})

      defmodule EmptyMapConfigLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:title)
            field(:published)
          end
        end
      end

      fields = EmptyMapConfigLive.fields()
      # All should use default mappings
      assert Keyword.get(fields, :title).module == Backpex.Fields.Text
      assert Keyword.get(fields, :published).module == Backpex.Fields.Boolean
    end

    test "no config falls back to defaults (backward compatibility)" do
      # Explicitly ensure no config is set
      Application.delete_env(:ash_backpex, :field_type_mappings)

      defmodule NoConfigLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:title)
            field(:published)
            field(:view_count)
            field(:rating)
            field(:published_at)
            field(:tags)
            field(:status)
          end
        end
      end

      fields = NoConfigLive.fields()
      # All should use default mappings
      assert Keyword.get(fields, :title).module == Backpex.Fields.Text
      assert Keyword.get(fields, :published).module == Backpex.Fields.Boolean
      assert Keyword.get(fields, :view_count).module == Backpex.Fields.Number
      assert Keyword.get(fields, :rating).module == Backpex.Fields.Number
      assert Keyword.get(fields, :published_at).module == Backpex.Fields.DateTime
      assert Keyword.get(fields, :tags).module == Backpex.Fields.MultiSelect
      assert Keyword.get(fields, :status).module == Backpex.Fields.Select
    end
  end
end
