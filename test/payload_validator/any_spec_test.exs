defmodule PayloadValidator.AnySpecTest do
  alias PayloadValidator.SpecError
  alias PayloadValidator.AnySpec

  import AnySpec

  use ExUnit.Case

  doctest PayloadValidator

  describe "AnySpec.any/1" do
    test "creates an any spec" do
      assert any() == %AnySpec{nullable: false, required: false}
      assert any(required: true, nullable: true) == %AnySpec{nullable: true, required: true}
    end

    test "raises if given bad opts" do
      fun_name = "PayloadValidator.AnySpec.any/1"

      assert_raise SpecError, "for #{fun_name}, required must be a boolean", fn ->
        any(required: "foo")
      end

      assert_raise SpecError, "for #{fun_name}, nullable must be a boolean", fn ->
        any(nullable: nil)
      end

      assert_raise SpecError, "for #{fun_name}, unknown is not an option", fn ->
        any(unknown: nil)
      end
    end
  end

  describe "AnySpec.conform/1" do
    test "checks a value against an AnySpec" do
      assert conform("foo", any()) == :ok
      assert conform([], any()) == :ok
      assert conform(nil, any(nullable: true)) == :ok
      assert conform(nil, any()) == {:error, "cannot be nil"}
    end
  end
end
