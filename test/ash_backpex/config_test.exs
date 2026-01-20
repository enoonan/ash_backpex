defmodule AshBackpex.ConfigTest do
  use ExUnit.Case, async: false

  alias AshBackpex.Config

  # Since we're modifying Application env, we can't run async
  setup do
    # Clean up any existing config before each test
    Application.delete_env(:ash_backpex, :field_type_mappings)
    Application.delete_env(:my_test_app, AshBackpex)

    on_exit(fn ->
      # Clean up after tests
      Application.delete_env(:ash_backpex, :field_type_mappings)
      Application.delete_env(:my_test_app, AshBackpex)
    end)

    :ok
  end

  describe "field_type_mappings/1" do
    test "returns nil when no config exists" do
      assert Config.field_type_mappings() == nil
      assert Config.field_type_mappings(:my_test_app) == nil
    end

    test "returns global config when only global is set" do
      global_mappings = %{Ash.Type.String => Backpex.Fields.Textarea}
      Application.put_env(:ash_backpex, :field_type_mappings, global_mappings)

      assert Config.field_type_mappings() == global_mappings
      assert Config.field_type_mappings(:my_test_app) == global_mappings
    end

    test "returns app-scoped config when both are set" do
      global_mappings = %{Ash.Type.String => Backpex.Fields.Text}
      app_mappings = %{Ash.Type.String => Backpex.Fields.Textarea}

      Application.put_env(:ash_backpex, :field_type_mappings, global_mappings)
      Application.put_env(:my_test_app, AshBackpex, field_type_mappings: app_mappings)

      # Global should be returned when no app specified
      assert Config.field_type_mappings() == global_mappings

      # App-scoped should take precedence
      assert Config.field_type_mappings(:my_test_app) == app_mappings
    end

    test "returns app-scoped config when only app-scoped is set" do
      app_mappings = %{Ash.Type.Integer => Backpex.Fields.Text}
      Application.put_env(:my_test_app, AshBackpex, field_type_mappings: app_mappings)

      assert Config.field_type_mappings(:my_test_app) == app_mappings
    end

    test "works with function-based mappings" do
      mapping_fn = fn _type, _constraints -> Backpex.Fields.Text end
      Application.put_env(:ash_backpex, :field_type_mappings, mapping_fn)

      result = Config.field_type_mappings()
      assert is_function(result, 2)
    end

    test "returns nil for nil otp_app with no global config" do
      assert Config.field_type_mappings(nil) == nil
    end

    test "returns global config for nil otp_app when global is set" do
      global_mappings = %{Ash.Type.Boolean => Backpex.Fields.Toggle}
      Application.put_env(:ash_backpex, :field_type_mappings, global_mappings)

      assert Config.field_type_mappings(nil) == global_mappings
    end
  end

  describe "validate_field_type_mappings!/1" do
    test "accepts a valid map with atom keys" do
      mappings = %{Ash.Type.String => Backpex.Fields.Textarea}
      assert Config.validate_field_type_mappings!(mappings) == mappings
    end

    test "accepts a valid map with tuple type keys" do
      mappings = %{{:array, Ash.Type.String} => Backpex.Fields.MultiSelect}
      assert Config.validate_field_type_mappings!(mappings) == mappings
    end

    test "accepts a valid map with nested array type keys" do
      mappings = %{{:array, {:array, Ash.Type.Integer}} => Backpex.Fields.Text}
      assert Config.validate_field_type_mappings!(mappings) == mappings
    end

    test "accepts a valid map with mixed key types" do
      mappings = %{
        Ash.Type.String => Backpex.Fields.Textarea,
        {:array, Ash.Type.Integer} => Backpex.Fields.MultiSelect
      }

      assert Config.validate_field_type_mappings!(mappings) == mappings
    end

    test "accepts an empty map" do
      assert Config.validate_field_type_mappings!(%{}) == %{}
    end

    test "accepts a valid function with arity 2" do
      fun = fn _type, _constraints -> Backpex.Fields.Text end
      assert Config.validate_field_type_mappings!(fun) == fun
    end

    test "raises for invalid config type - string" do
      assert_raise ArgumentError, ~r/Invalid field_type_mappings configuration/, fn ->
        Config.validate_field_type_mappings!("invalid")
      end
    end

    test "raises for invalid config type - list" do
      assert_raise ArgumentError, ~r/Invalid field_type_mappings configuration/, fn ->
        Config.validate_field_type_mappings!([Ash.Type.String])
      end
    end

    test "raises for invalid config type - integer" do
      assert_raise ArgumentError, ~r/Invalid field_type_mappings configuration/, fn ->
        Config.validate_field_type_mappings!(123)
      end
    end

    test "raises for function with wrong arity (arity 1)" do
      fun = fn _type -> Backpex.Fields.Text end

      assert_raise ArgumentError, ~r/Expected a function with arity 2.*got a function with arity 1/s, fn ->
        Config.validate_field_type_mappings!(fun)
      end
    end

    test "raises for function with wrong arity (arity 3)" do
      fun = fn _type, _constraints, _extra -> Backpex.Fields.Text end

      assert_raise ArgumentError, ~r/Expected a function with arity 2.*got a function with arity 3/s, fn ->
        Config.validate_field_type_mappings!(fun)
      end
    end

    test "raises for function with wrong arity (arity 0)" do
      fun = fn -> Backpex.Fields.Text end

      assert_raise ArgumentError, ~r/Expected a function with arity 2.*got a function with arity 0/s, fn ->
        Config.validate_field_type_mappings!(fun)
      end
    end

    test "raises for map with invalid string key" do
      mappings = %{"Ash.Type.String" => Backpex.Fields.Text}

      assert_raise ArgumentError, ~r/Invalid key in field_type_mappings configuration/, fn ->
        Config.validate_field_type_mappings!(mappings)
      end
    end

    test "raises for map with invalid integer key" do
      mappings = %{123 => Backpex.Fields.Text}

      assert_raise ArgumentError, ~r/Invalid key in field_type_mappings configuration/, fn ->
        Config.validate_field_type_mappings!(mappings)
      end
    end

    test "raises for map with invalid tuple key (not :array)" do
      mappings = %{{:map, Ash.Type.String} => Backpex.Fields.Text}

      assert_raise ArgumentError, ~r/Invalid key in field_type_mappings configuration/, fn ->
        Config.validate_field_type_mappings!(mappings)
      end
    end

    test "raises for map with invalid nested tuple key" do
      mappings = %{{:array, "not_an_atom"} => Backpex.Fields.Text}

      assert_raise ArgumentError, ~r/Invalid key in field_type_mappings configuration/, fn ->
        Config.validate_field_type_mappings!(mappings)
      end
    end
  end

  describe "field_type_mappings/1 with validation" do
    test "raises when global config has invalid format" do
      Application.put_env(:ash_backpex, :field_type_mappings, "invalid")

      assert_raise ArgumentError, ~r/Invalid field_type_mappings configuration/, fn ->
        Config.field_type_mappings()
      end
    end

    test "raises when app-scoped config has invalid format" do
      Application.put_env(:my_test_app, AshBackpex, field_type_mappings: [invalid: :list])

      assert_raise ArgumentError, ~r/Invalid field_type_mappings configuration/, fn ->
        Config.field_type_mappings(:my_test_app)
      end
    end

    test "validates and returns valid global config" do
      valid_mappings = %{Ash.Type.String => Backpex.Fields.Textarea}
      Application.put_env(:ash_backpex, :field_type_mappings, valid_mappings)

      assert Config.field_type_mappings() == valid_mappings
    end

    test "validates and returns valid app-scoped config" do
      valid_mappings = %{{:array, Ash.Type.Integer} => Backpex.Fields.MultiSelect}
      Application.put_env(:my_test_app, AshBackpex, field_type_mappings: valid_mappings)

      assert Config.field_type_mappings(:my_test_app) == valid_mappings
    end
  end
end
