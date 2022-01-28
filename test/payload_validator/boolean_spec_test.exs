defmodule PayloadValidator.BooleanSpecTest do
  alias PayloadValidator.SpecError
  alias PayloadValidator.BooleanSpec

  import BooleanSpec

  use ExUnit.Case

  # TODO: figure out what this is
  doctest PayloadValidator

  describe "BooleanSpec.boolean/1" do
    test "creates a boolea spec" do
      assert boolean() == %BooleanSpec{nullable: false, required: false}

      assert boolean(required: true, nullable: true) == %BooleanSpec{
               nullable: true,
               required: true
             }
    end

    test "raises if given bad opts" do
      fun_name = "PayloadValidator.BooleanSpec.boolean/1"

      assert_raise SpecError, "for #{fun_name}, required must be a boolean", fn ->
        boolean(required: "foo")
      end

      assert_raise SpecError, "for #{fun_name}, nullable must be a boolean", fn ->
        boolean(nullable: nil)
      end

      assert_raise SpecError, "for #{fun_name}, unknown is not an option", fn ->
        boolean(unknown: nil)
      end
    end
  end

  describe "AnySpec.conform/1" do
    test "checks a value against an AnySpec" do
      assert conform(true, boolean()) == :ok
      assert conform([], boolean()) == {:error, "must be a boolean"}
      assert conform(nil, boolean(nullable: true)) == :ok
      assert conform(nil, boolean()) == {:error, "cannot be nil"}
    end
  end
end
