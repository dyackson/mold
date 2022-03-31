defmodule PayloadValidator.IntegerSpecTest do
  alias PayloadValidator.SpecError
  alias PayloadValidator.IntegerSpec

  import IntegerSpec

  use ExUnit.Case

  # TODO: figure out what this is
  doctest PayloadValidator

  describe "IntegerSpec.integer/1" do
    test "creates an Integer spec" do
      assert integer() == %IntegerSpec{nullable: false, required: false}

      assert integer(required: true, nullable: true) == %IntegerSpec{
               nullable: true,
               required: true
             }
    end

    test "raises if given bad opts" do
      fun_name = "PayloadValidator.IntegerSpec.integer/1"

      assert_raise SpecError, "for #{fun_name}, :required must be a boolean", fn ->
        integer(required: "foo")
      end

      assert_raise SpecError, "for #{fun_name}, :nullable must be a boolean", fn ->
        integer(nullable: nil)
      end
    end
  end

  describe "IntegerSpec.conform/2" do
    test "conforms a value against an integer spec" do
      assert conform(5, integer()) == :ok
      assert conform("foo", integer()) == {:error, "must be an integer"}
      assert conform(nil, integer()) == {:error, "cannot be nil"}
      assert conform(nil, integer(nullable: true)) == :ok
    end
  end
end
