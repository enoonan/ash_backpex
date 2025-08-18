defmodule AshBackpex.LiveResource.ErrorCasesTest do
  use ExUnit.Case, async: true

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
end
