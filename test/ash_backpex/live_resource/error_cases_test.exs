defmodule AshBackpex.LiveResource.ErrorCasesTest do
  use ExUnit.Case, async: true

  describe "DSL validation errors" do
    test "raises error when resource is not specified" do
      assert_raise Spark.Error.DslError, ~r/required :resource option not found/, fn ->
        defmodule MissingResourceLive do
          use AshBackpex.LiveResource

          backpex do
            layout({TestLayout, :admin})
          end
        end
      end
    end

    test "raises error when layout is not specified" do
      assert_raise Spark.Error.DslError, ~r/required :layout option not found/, fn ->
        defmodule MissingLayoutLive do
          use AshBackpex.LiveResource

          backpex do
            resource(TestDomain.Post)
          end
        end
      end
    end

    test "raises error for invalid field configuration" do
      # TODO: We might want to improve the error message here
      assert_raise RuntimeError, ~r/Unable to derive the field type for/, fn ->
        defmodule InvalidFieldLive do
          use AshBackpex.LiveResource

          backpex do
            resource(TestDomain.Post)
            layout({TestLayout, :admin})

            fields do
              field(:non_existent_field)
            end
          end
        end
      end
    end
  end
end
