defmodule PayloadValidator.DecimalSpecTest do
  alias PayloadValidator.SpecError
  alias PayloadValidator.DecimalSpec

  import DecimalSpec

  use ExUnit.Case

  # TODO: figure out what this is
  doctest PayloadValidator

  @fun_name "PayloadValidator.DecimalSpec.decimal/1"

  describe "DecimalSpec.decimal/1" do
    test "creates a Decimal spec" do
      assert decimal() == %DecimalSpec{
               nullable: false,
               required: false,
               gt: nil,
               lt: nil,
               gte: nil,
               lte: nil
             }

      assert decimal(required: true, nullable: true) == %DecimalSpec{
               nullable: true,
               required: true
             }

      assert decimal(max_decimal_places: 0) == %DecimalSpec{max_decimal_places: 0}

      assert decimal(max_decimal_places: 3) == %DecimalSpec{max_decimal_places: 3}
    end

    test "coerces valid bound field to Decimal" do
      assert decimal(gt: 2, lt: "5.00") == %DecimalSpec{
               gt: Decimal.new(2),
               lt: Decimal.new("5.00")
             }

      assert decimal(gte: Decimal.new("4.4"), lte: 5) == %DecimalSpec{
               gte: Decimal.new("4.4"),
               lte: Decimal.new(5)
             }
    end

    test "raises if given bad opts" do
      assert_raise SpecError, "for #{@fun_name}, required must be a boolean", fn ->
        decimal(required: "foo")
      end

      assert_raise SpecError, "for #{@fun_name}, nullable must be a boolean", fn ->
        decimal(nullable: nil)
      end

      assert_raise SpecError,
                   "for #{@fun_name}, gt must be an integer, decimal-formatted string, or Decimal",
                   fn ->
                     decimal(gt: "foo")
                   end

      assert_raise SpecError,
                   "for #{@fun_name}, gte must be an integer, decimal-formatted string, or Decimal",
                   fn ->
                     decimal(gte: false)
                   end

      assert_raise SpecError,
                   "for #{@fun_name}, lt must be an integer, decimal-formatted string, or Decimal",
                   fn ->
                     decimal(lt: "12foo")
                   end

      assert_raise SpecError,
                   "for #{@fun_name}, lte must be an integer, decimal-formatted string, or Decimal",
                   fn ->
                     decimal(lte: :infinity)
                   end
    end

    test "raises if given a bad max_decimal_places opt" do
      Enum.each(["5", %{}, -3], fn bad ->
        assert_raise SpecError,
                     "for #{@fun_name}, max_decimal_places must be a non-negative integer",
                     fn ->
                       decimal(max_decimal_places: bad)
                     end
      end)
    end

    test "raises the combination of bound opts don't make sense" do
      assert_raise SpecError, "for #{@fun_name}, cannot specify both gt and gte", fn ->
        decimal(gt: 5, gte: 6)
      end

      assert_raise SpecError, "for #{@fun_name}, cannot specify both lt and lte", fn ->
        decimal(lt: 5, lte: 5)
      end

      assert_raise SpecError, "for #{@fun_name}, gt must be less than lt", fn ->
        decimal(gt: 5, lt: 5)
      end

      assert_raise SpecError, "for #{@fun_name}, gt must be less than lt", fn ->
        decimal(gt: 6, lt: 5)
      end

      assert_raise SpecError, "for #{@fun_name}, gte must be less than lt", fn ->
        decimal(gte: 5, lt: 5)
      end

      assert_raise SpecError, "for #{@fun_name}, gte must be less than lt", fn ->
        decimal(gte: 6, lt: 5)
      end

      assert_raise SpecError, "for #{@fun_name}, gt must be less than lte", fn ->
        decimal(gt: 5, lte: 5)
      end

      assert_raise SpecError, "for #{@fun_name}, gt must be less than lte", fn ->
        decimal(gt: 6, lte: 5)
      end

      assert_raise SpecError, "for #{@fun_name}, gte must be less than or equal to lte", fn ->
        decimal(gte: 6, lte: 5)
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

    test "checks a value against a decimal spec with bounds" do
      assert conform(5, decimal(gt: 0)) == :ok
      assert conform(5, decimal(gt: 5)) == {:error, "must be greater than 5"}

      assert conform("5.00", decimal(gte: "5.00")) == :ok
    end

    test "checks a value against a decimal spec with max_decimal_places" do
      assert conform(5, decimal(max_decimal_places: 0)) == :ok
      assert conform(5, decimal(max_decimal_places: 3)) == :ok
      assert conform("5", decimal(max_decimal_places: 3)) == :ok
      assert conform(".123", decimal(max_decimal_places: 3)) == :ok
      assert conform("4.123", decimal(max_decimal_places: 3)) == :ok

      assert conform("5.0", decimal(max_decimal_places: 0)) ==
               {:error, "cannot have more than 0 digits after the decimal point"}

      assert conform("5.123", decimal(max_decimal_places: 2)) ==
               {:error, "cannot have more than 2 digits after the decimal point"}
    end
  end
end
