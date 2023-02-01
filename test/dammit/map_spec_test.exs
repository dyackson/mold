defmodule Dammit.MapSpecTest do
  alias Dammit.SpecError
  alias Dammit.Spec
  alias Dammit.MapSpec
  alias Dammit.StringSpec 
  alias Dammit.IntegerSpec 
  alias Dammit.BooleanSpec 

  use ExUnit.Case

  describe "MapSpec.new/1" do
    test "creates a map spec" do
      assert MapSpec.new() == %MapSpec{
               nullable: false,
               required: %{},
               optional: %{},
               exclusive: false,
               and: nil
             }

      assert MapSpec.new(nullable: true) == %MapSpec{nullable: true}
    end

    test "validate with a map Spec" do
      spec =
        MapSpec.new(
          required: [my_str: StringSpec.new(), my_int: IntegerSpec.new()],
          optional: %{my_bool: BooleanSpec.new(nullable: true)}
        )

      assert :ok = Spec.validate(%{my_str: "foo", my_int: 1}, spec)
      assert :ok = Spec.validate(%{my_str: "foo", my_int: 1, my_bool: true}, spec)
      assert :ok = Spec.validate(%{my_str: "foo", my_int: 1, my_bool: nil}, spec)
      assert :ok = Spec.validate(%{my_str: "foo", my_int: 1, some_other_field: "foopy"}, spec)

      assert Spec.validate(%{my_str: "foo"}, spec) == {:error, %{[:my_int] => "is required"}}

      assert Spec.validate(%{}, spec) ==
               {:error, %{[:my_int] => "is required", [:my_str] => "is required"}}

      assert Spec.validate(%{my_str: "foo", my_int: "foo"}, spec) ==
               {:error, %{[:my_int] => "must be an integer"}}

      assert Spec.validate(%{my_str: 1, my_int: "foo"}, spec) ==
               {:error, %{[:my_int] => "must be an integer", [:my_str] => "must be a string"}}

      assert Spec.validate(%{my_str: 1, my_int: "foo"}, spec) ==
               {:error, %{[:my_int] => "must be an integer", [:my_str] => "must be a string"}}

      assert Spec.validate(%{my_str: 1, my_int: "foo", my_bool: "foo"}, spec) ==
               {:error,
                %{
                  [:my_int] => "must be an integer",
                  [:my_str] => "must be a string",
                  [:my_bool] => "must be a boolean"
                }}

      exclusive_spec = Map.put(spec, :exclusive, true)

      assert Spec.validate(%{my_str: "foo", my_int: 1, some_other_field: "foopy"}, exclusive_spec) ==
               {:error, %{[:some_other_field] => "is not allowed"}}

      empty_map_spec = MapSpec.new()

      assert :ok = Spec.validate(%{}, empty_map_spec)
      assert :ok = Spec.validate(%{some_other_field: [1, 2, 3]}, empty_map_spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, empty_map_spec)

      assert Spec.validate(
               %{some_other_field: [1, 2, 3]},
               Map.put(empty_map_spec, :exclusive, true)
             ) ==
               {:error, %{[:some_other_field] => "is not allowed"}}
    end

    test "validate a nested map spec" do
      nested_spec =
        MapSpec.new(
          required: %{my_str: StringSpec.new(), my_int: IntegerSpec.new()},
          optional: [my_bool: BooleanSpec.new(nullable: true)]
        )

      spec = MapSpec.new(required: [nested: nested_spec])

      :ok = Spec.validate(%{nested: %{my_int: 1, my_str: "foo"}}, spec)

      assert Spec.validate(%{nested: %{my_str: "foo"}}, spec) ==
               {:error, %{[:nested, :my_int] => "is required"}}

      # exclucivity applies to nested specs
      # TODO: allow explicit overwrite in child spec 
      exclusive_spec = Map.put(spec, :exclusive, true)

      map = %{nested: %{my_str: 1, my_bool: 1}, some_other_field: "foo"}

      expected =
        {:error,
         %{
           [:some_other_field] => "is not allowed",
           [:nested, :my_str] => "must be a string",
           [:nested, :my_int] => "is required",
           [:nested, :my_bool] => "must be a boolean"
         }}

      assert Spec.validate(map, exclusive_spec) == expected
    end
  end
end
