defmodule PayloadValidator.DecimalSpecTest do
  alias PayloadValidator.SpecError
  alias PayloadValidator.DecimalSpec

  import DecimalSpec

  use ExUnit.Case

  # TODO: figure out what this is
  doctest PayloadValidator

  describe "DecimalSpec.decimal/1" do
    test "creates a Decimal spec" do
      assert decimal() == %DecimalSpec{nullable: false, required: false}

      assert decimal(required: true, nullable: true) == %DecimalSpec{
               nullable: true,
               required: true
             }
    end

    test "raises if given bad opts" do
      fun_name = "PayloadValidator.DecimalSpec.decimal/1"

      assert_raise SpecError, "for #{fun_name}, required must be a boolean", fn ->
        decimal(required: "foo")
      end

      assert_raise SpecError, "for #{fun_name}, nullable must be a boolean", fn ->
        decimal(nullable: nil)
      end
    end
  end

  describe "DecimalSpec.conform/1" do
    test "checks a value against a decimal spec" do
      assert conform(nil, decimal(nullable: true)) == :ok
      assert conform(nil, decimal()) == {:error, "cannot be nil"}

      good = [5, "1", ".1", "0.1", "12.12"]
      Enum.each(good, fn it -> assert conform(it, decimal()) == :ok end)

      bad = [12.12, "", "foo", "12.12.12", "1.", "1.1e3"]
      error_msg = "must be a decimal-formatted string or an integer"

      Enum.each(bad, fn it -> assert conform(it, decimal()) == {:error, error_msg} end)
    end
  end
end
