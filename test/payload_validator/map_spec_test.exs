defmodule PayloadValidator.MapSpecTest do
  alias PayloadValidator.SpecError
  alias PayloadValidator.MapSpec
  alias PayloadValidator.StringSpec
  alias PayloadValidator.IntegerSpec

  import MapSpec
  import PayloadValidator.StringSpec, only: [string: 1, string: 0]
  import PayloadValidator.IntegerSpec, only: [integer: 1, integer: 0]

  use ExUnit.Case

  # TODO: figure out what this is
  doctest PayloadValidator

  describe "map/1" do
    test "creates a map spec" do
      assert map() == %MapSpec{nullable: false, required: false, fields: %{}, exclusive: false}

      assert %MapSpec{
               fields: %{
                 name: %StringSpec{required: true},
                 age: %IntegerSpec{nullable: true}
               }
             } = map(fields: %{name: string(required: true), age: integer(nullable: true)})
    end

    test "raises if given bad opts" do
      fun_name = "PayloadValidator.MapSpec.map/1"

      assert_raise SpecError, "for #{fun_name}, required must be a boolean", fn ->
        map(required: "foo")
      end

      assert_raise SpecError, "for #{fun_name}, nullable must be a boolean", fn ->
        map(nullable: nil)
      end

      assert_raise SpecError,
                   "for #{fun_name}, fields must be a map of field names to specs",
                   fn ->
                     map(fields: nil)
                   end

      assert_raise SpecError,
                   "for #{fun_name}, fields must be a map of field names to specs",
                   fn ->
                     map(fields: [])
                   end

      assert_raise SpecError,
                   "for #{fun_name}, fields must be a map of field names to specs",
                   fn ->
                     map(fields: %{foo: %{nullable: true}})
                   end

      assert_raise SpecError,
                   "for #{fun_name}, fields must be a map of field names to specs",
                   fn ->
                     map(fields: %{foo: true})
                   end

      assert_raise SpecError, "for #{fun_name}, bad_opt is not an option", fn ->
        map(bad_opt: true)
      end
    end
  end

  describe "MapSet.conform/2" do
    test "conforms a value against a map spec" do
      assert conform(%{}, map()) == :ok
      assert conform(nil, map(nullable: true)) == :ok
      assert conform(nil, map()) == {:error, "cannot be nil"}
      assert conform("foo", map()) == {:error, "must be a map"}

      map_spec = map(fields: %{name: string(), age: integer()})

      assert conform(%{name: "joe", age: 5}, map_spec) == :ok

      assert conform(%{name: 5, age: "joe"}, map_spec) ==
               {:error, %{[:name] => "must be a string", [:age] => "must be an integer"}}
    end

    test "conforms a value against a map spec with required and nullable fields" do
      fields = %{
        optional_nonnullable: string(required: false, nullable: false),
        optional_nullable: string(required: false, nullable: true),
        required_nonnullable: string(required: true, nullable: false),
        required_nullable: string(required: true, nullable: true)
      }

      assert conform(%{}, map(fields: fields)) ==
               {:error,
                %{
                  [:required_nullable] => "is required",
                  [:required_nonnullable] => "is required"
                }}

      val = %{
        optional_nullable: nil,
        optional_nonnullable: nil,
        required_nullable: nil,
        required_nonnullable: nil
      }

      assert conform(val, map(fields: fields)) ==
               {:error,
                %{
                  [:optional_nonnullable] => "cannot be nil",
                  [:required_nonnullable] => "cannot be nil"
                }}
    end

    test "conforms a value against a map spec with exclusive = true" do
      assert conform(%{unknown: "?"}, map(exclusive: true, fields: %{name: string()})) ==
               {:error, %{[:unknown] => "is not allowed"}}
    end
  end
end
