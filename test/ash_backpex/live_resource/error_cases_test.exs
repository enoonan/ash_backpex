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
  end
end
