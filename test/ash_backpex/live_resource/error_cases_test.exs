defmodule AshBackpex.LiveResource.ErrorCasesTest do
  use ExUnit.Case, async: false

  # Clean up config between tests
  setup do
    Application.delete_env(:ash_backpex, :field_type_mappings)

    on_exit(fn ->
      Application.delete_env(:ash_backpex, :field_type_mappings)
    end)

    :ok
  end

  describe "DSL validation errors :: it can" do
    test "raise error when resource is not specified" do
      assert_raise Spark.Error.DslError, ~r/required :resource option not found/, fn ->
        defmodule MissingResourceLive do
          use AshBackpex.LiveResource

          backpex do
            layout({TestLayout, :admin})
          end
        end
      end
    end

    test "raise error when layout is not specified" do
      assert_raise Spark.Error.DslError, ~r/required :layout option not found/, fn ->
        defmodule MissingLayoutLive do
          use AshBackpex.LiveResource

          backpex do
            resource(AshBackpex.TestDomain.Post)
          end
        end
      end
    end

    test "raise error for invalid field configuration" do
      assert_raise RuntimeError, ~r/Unable to derive the `Backpex.Field` module/, fn ->
        defmodule InvalidFieldLive do
          use AshBackpex.LiveResource

          backpex do
            resource(AshBackpex.TestDomain.Post)
            layout({TestLayout, :admin})

            fields do
              field(:non_existent_field)
            end
          end
        end
      end
    end
  end

  describe "custom field type mapping validation :: it can" do
    test "raise error when mapped module does not exist" do
      # Set up a mapping to a non-existent module
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => NonExistent.Fake.Module
      })

      assert_raise RuntimeError,
                   ~r/The module NonExistent\.Fake\.Module could not be loaded/,
                   fn ->
                     defmodule NonExistentModuleLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:title)
                         end
                       end
                     end
                   end
    end

    test "raise error when mapped module does not implement Backpex.Field behavior" do
      # GenServer is a valid module but doesn't implement Backpex.Field
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => GenServer
      })

      assert_raise RuntimeError,
                   ~r/does not implement the Backpex\.Field behavior/,
                   fn ->
                     defmodule InvalidBehaviorLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:title)
                         end
                       end
                     end
                   end
    end

    test "raise error with function-based mapping returning non-existent module" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        Ash.Type.String, _constraints -> NonExistent.Field.Module
        _type, _constraints -> nil
      end)

      assert_raise RuntimeError,
                   ~r/The module NonExistent\.Field\.Module could not be loaded/,
                   fn ->
                     defmodule FnNonExistentModuleLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:title)
                         end
                       end
                     end
                   end
    end

    test "raise error with function-based mapping returning module without Backpex.Field behavior" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        Ash.Type.String, _constraints -> String
        _type, _constraints -> nil
      end)

      assert_raise RuntimeError,
                   ~r/does not implement the Backpex\.Field behavior/,
                   fn ->
                     defmodule FnInvalidBehaviorLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:title)
                         end
                       end
                     end
                   end
    end

    test "pass validation silently when module implements Backpex.Field behavior" do
      # Backpex.Fields.Textarea is a valid Backpex field module
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => Backpex.Fields.Textarea
      })

      # This should not raise - module is valid
      defmodule ValidMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:title)
          end
        end
      end

      # Verify the mapping was applied
      fields = ValidMappingLive.fields()
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
    end

    test "raise error when function-based mapping throws an exception" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn _type, _constraints ->
        raise "Intentional error in mapping function"
      end)

      assert_raise RuntimeError,
                   ~r/Error in custom field_type_mappings function.*Intentional error in mapping function/s,
                   fn ->
                     defmodule FnExceptionLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:title)
                         end
                       end
                     end
                   end
    end

    test "raise error when function-based mapping returns invalid value (string)" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        Ash.Type.String, _constraints -> "not_a_module"
        _type, _constraints -> nil
      end)

      assert_raise RuntimeError,
                   ~r/Invalid return value from custom field_type_mappings function.*Expected: a module atom or nil.*Got: "not_a_module"/s,
                   fn ->
                     defmodule FnInvalidReturnStringLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:title)
                         end
                       end
                     end
                   end
    end

    test "raise error when function-based mapping returns invalid value (integer)" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        Ash.Type.String, _constraints -> 42
        _type, _constraints -> nil
      end)

      assert_raise RuntimeError,
                   ~r/Invalid return value from custom field_type_mappings function.*Expected: a module atom or nil.*Got: 42/s,
                   fn ->
                     defmodule FnInvalidReturnIntLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:title)
                         end
                       end
                     end
                   end
    end

    test "raise error when function-based mapping returns invalid value (tuple)" do
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        Ash.Type.String, _constraints -> {:error, "something"}
        _type, _constraints -> nil
      end)

      assert_raise RuntimeError,
                   ~r/Invalid return value from custom field_type_mappings function.*Expected: a module atom or nil/s,
                   fn ->
                     defmodule FnInvalidReturnTupleLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:title)
                         end
                       end
                     end
                   end
    end
  end

  describe "array type mapping support :: it can" do
    test "map {:array, Type} to custom field with map-based config" do
      # Configure array string type to use a specific field
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        {:array, Ash.Type.String} => Backpex.Fields.Text
      })

      defmodule ArrayMapMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # keywords is {:array, Ash.Type.String} without constraints
            field(:keywords)
          end
        end
      end

      # Verify the mapping was applied
      fields = ArrayMapMappingLive.fields()
      assert Keyword.get(fields, :keywords).module == Backpex.Fields.Text
    end

    test "use scalar and array mappings independently" do
      # Configure both scalar and array string types differently
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => Backpex.Fields.Textarea,
        {:array, Ash.Type.String} => Backpex.Fields.Text
      })

      defmodule ScalarArrayIndependentLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # title is Ash.Type.String (scalar)
            field(:title)
            # keywords is {:array, Ash.Type.String} without constraints
            field(:keywords)
          end
        end
      end

      fields = ScalarArrayIndependentLive.fields()
      # Scalar string should use Textarea
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
      # Array string should use Text
      assert Keyword.get(fields, :keywords).module == Backpex.Fields.Text
    end

    test "fall back to default when no array mapping configured" do
      # Only configure scalar mapping, not array
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        Ash.Type.String => Backpex.Fields.Textarea
      })

      defmodule ArrayFallbackLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # title is Ash.Type.String (scalar) - should use custom mapping
            field(:title)
            # keywords is {:array, Ash.Type.String} - should use default MultiSelect for arrays
            field(:keywords)
          end
        end
      end

      fields = ArrayFallbackLive.fields()
      # Scalar string uses custom mapping
      assert Keyword.get(fields, :title).module == Backpex.Fields.Textarea
      # Array string falls back to default (MultiSelect for arrays)
      assert Keyword.get(fields, :keywords).module == Backpex.Fields.MultiSelect
    end

    test "map {:array, Type} to custom field with function-based config" do
      # Configure using function that handles array types
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        {:array, Ash.Type.String}, _constraints -> Backpex.Fields.Text
        _type, _constraints -> nil
      end)

      defmodule ArrayFunctionMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            field(:keywords)
          end
        end
      end

      fields = ArrayFunctionMappingLive.fields()
      assert Keyword.get(fields, :keywords).module == Backpex.Fields.Text
    end

    test "function-based mapping can use constraints for array types" do
      # Function that uses constraints to decide field type
      Application.put_env(:ash_backpex, :field_type_mappings, fn
        {:array, Ash.Type.Atom}, constraints ->
          # Check if the array has items constraints with one_of
          case get_in(constraints, [:items, :one_of]) do
            list when is_list(list) -> Backpex.Fields.Text
            _ -> nil
          end

        _type, _constraints ->
          nil
      end)

      defmodule ArrayConstraintsMappingLive do
        use AshBackpex.LiveResource

        backpex do
          resource(AshBackpex.TestDomain.Post)
          layout({TestLayout, :admin})

          fields do
            # tags has items constraints with one_of
            field(:tags)
          end
        end
      end

      fields = ArrayConstraintsMappingLive.fields()
      # Should use our custom mapping based on constraints
      assert Keyword.get(fields, :tags).module == Backpex.Fields.Text
    end

    test "raise error for non-existent module with array type mapping" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        {:array, Ash.Type.String} => NonExistent.Array.Field
      })

      assert_raise RuntimeError,
                   ~r/The module NonExistent\.Array\.Field could not be loaded/,
                   fn ->
                     defmodule ArrayNonExistentModuleLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:keywords)
                         end
                       end
                     end
                   end
    end

    test "raise error when array-mapped module does not implement Backpex.Field behavior" do
      Application.put_env(:ash_backpex, :field_type_mappings, %{
        {:array, Ash.Type.String} => GenServer
      })

      assert_raise RuntimeError,
                   ~r/does not implement the Backpex\.Field behavior/,
                   fn ->
                     defmodule ArrayInvalidBehaviorLive do
                       use AshBackpex.LiveResource

                       backpex do
                         resource(AshBackpex.TestDomain.Post)
                         layout({TestLayout, :admin})

                         fields do
                           field(:keywords)
                         end
                       end
                     end
                   end
    end
  end
end
