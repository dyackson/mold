defmodule Anal.DecTest do
  use ExUnit.Case

  alias Anal.Dec
  alias Anal.SpecError

  describe "Anal.prep! a Dec" do
    test "SpecError if nil_ok? not a boolean" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Dec{nil_ok?: "yuh"})
      end)
    end

    test "SpecError if :also not a arity-1 function" do
      assert_raise(SpecError, ":also must be an arity-1 function", fn ->
        Anal.prep!(%Dec{also: &(&1 + &2)})
      end)
    end

    test "adds the default error message" do
      assert %Dec{error_message: "must be a decimal-formatted string"} = Anal.prep!(%Dec{})

      assert %Dec{error_message: "must be a decimal-formatted string with up to 0 decimal places"} =
               Anal.prep!(%Dec{max_decimal_places: 0})

      assert %Dec{
               error_message: "must be a decimal-formatted string with up to 10 decimal places"
             } = Anal.prep!(%Dec{max_decimal_places: 10})

      assert %Dec{
               error_message: "must be a decimal-formatted string less than 5.5"
             } = Anal.prep!(%Dec{lt: "5.5"})

      assert %Dec{
               error_message: "must be a decimal-formatted string greater than 5.5"
             } = Anal.prep!(%Dec{gt: "5.5"})

      assert %Dec{
               error_message: "must be a decimal-formatted string less than or equal to 5.5"
             } = Anal.prep!(%Dec{lte: "5.5"})

      assert %Dec{
               error_message: "must be a decimal-formatted string greater than or equal to 5.5"
             } = Anal.prep!(%Dec{gte: "5.5"})

      assert %Dec{
               error_message:
                 "must be a decimal-formatted string greater than or equal to 5.5 and less than 20"
             } = Anal.prep!(%Dec{gte: "5.5", lt: 20})

      assert %Dec{
               error_message:
                 "must be a decimal-formatted string greater than 5.5 and less than or equal to 20"
             } = Anal.prep!(%Dec{gt: "5.5", lte: 20})

      assert %Dec{
               error_message:
                 "must be a decimal-formatted string with up to 10 decimal places, greater than 5.5, and less than or equal to 20"
             } = Anal.prep!(%Dec{gt: "5.5", lte: 20, max_decimal_places: 10})
     end

    test "uses provieded error message" do
      assert %Dec{error_message: "dammit"} = Anal.prep!(%Dec{error_message: "dammit"})
    end
  end

  #   describe "DecimalSpec.new/1" do
  #     test "creates a decimal spec" do
  #       assert %DecimalSpec{__error_message__: "must be a decimal formatted string"} =
  #                DecimalSpec.new()

  #       assert %DecimalSpec{__error_message__: "if not null, must be a decimal formatted string"} =
  #                DecimalSpec.new(can_be_null: true)

  #       assert %DecimalSpec{
  #                gt: Decimal.new("5"),
  #                lt: Decimal.new("10.01"),
  #                __error_message__:
  #                  "must be a decimal-formatted string greater than 5 and less than 10.01"
  #              } = DecimalSpec.new(gt: 5, lt: "10.01")

  #       assert %DecimalSpec{
  #                gt: Decimal.new("5"),
  #                lt: Decimal.new("10.01"),
  #                __error_message__:
  #                  "if not null, must be a decimal-formatted string greater than 5 and less than 10.01"
  #              } = DecimalSpec.new(gt: 5, lt: "10.01", can_be_null: true)

  #       assert %DecimalSpec{
  #                gte: Decimal.new("5"),
  #                lte: Decimal.new("10.01"),
  #                __error_message__:
  #                  "must be a decimal-formatted string greater than 5 and less than 10.01"
  #              } = DecimalSpec.new(gte: 5, lte: "10.01")

  #       # overwrite the default get_error_message function 
  #       get_error_message = fn spec ->
  #         how_null_is = if spec.can_be_null, do: "fine", else: "not cool"
  #         "null is #{how_null_is}, gotta be at least #{spec.gte} and at most #{spec.lte}"
  #       end

  #       assert %DecimalSpec{
  #                gte: Decimal.new("1"),
  #                lte: Decimal.new("5"),
  #                __error_message__: "null is not cool, gotta be at least 1 and at most 5"
  #              } = DecimalSpec.new(gte: 1, lte: 5, get_error_message: get_error_message)

  #       assert %DecimalSpec{
  #                gte: Decimal.new("1"),
  #                lte: Decimal.new("5"),
  #                __error_message__: "null is fine, gotta be at least 1 and at most 5"
  #              } =
  #                DecimalSpec.new(
  #                  can_be_null: true,
  #                  gte: 1,
  #                  lte: 5,
  #                  get_error_message: get_error_message
  #                )

  #       Enum.each([:lt, :lte, :gt, :gte], fn comp ->
  #         assert_raise SpecError,
  #                      "#{inspect(comp)} must be a Decimal, a decimal-formatted string, or an integer",
  #                      fn ->
  #                        DecimalSpec.new([{comp, "f00py"}])
  #                      end
  #       end)

  #       assert_raise SpecError, "cannot use both :gt and :gte", fn ->
  #         DecimalSpec.new(gt: 5, gte: 3)
  #       end

  #       assert_raise SpecError, "cannot use both :lt and :lte", fn ->
  #         DecimalSpec.new(lt: 5, lte: 3)
  #       end

  #       for lower <- [:gt, :gte], upper <- [:lt, :lte] do
  #         assert_raise SpecError, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
  #           DecimalSpec.new([{lower, 5}, {upper, 4}])
  #         end

  #         assert_raise SpecError, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
  #           DecimalSpec.new([{lower, 5}, {upper, 5}])
  #         end
  #       end

  #       assert_raise SpecError, ":max_decimal_places must be a positive integer", fn ->
  #         DecimalSpec.new(max_decimal_places: "3")
  #       end

  #       assert_raise SpecError, ":max_decimal_places must be a positive integer", fn ->
  #         DecimalSpec.new(max_decimal_places: -3)
  #       end
  #     end

  #     test "validates a decimal, basic test" do
  #       spec = assert DecimalSpec.new()

  #       assert :ok = Anal.check("4", spec)
  #       assert :ok = Anal.check(" 4 ", spec)
  #       assert :ok = Anal.check("-14", spec)
  #       assert :ok = Anal.check(" -14 ", spec)
  #       assert :ok = Anal.check("4.00", spec)
  #       assert :ok = Anal.check("-4.00", spec)
  #       assert :ok = Anal.check("-47.00", spec)
  #       assert :ok = Anal.check(".47", spec)
  #       assert :ok = Anal.check(" .47 ", spec)
  #       assert :ok = Anal.check("-.47", spec)
  #       assert :ok = Anal.check(" -.47 ", spec)
  #       assert {:error, _} = Anal.check("foo", spec)
  #       assert {:error, _} = Anal.check("1.1.", spec)
  #       assert {:error, _} = Anal.check(".1.1", spec)
  #       assert {:error, _} = Anal.check(" ", spec)
  #       assert {:error, _} = Anal.check(".", spec)
  #       assert {:error, _} = Anal.check("..", spec)
  #       assert {:error, _} = Anal.check(1, spec)
  #       assert {:error, _} = Anal.check(Decimal.new(4), spec)
  #       assert {:error, _} = Anal.check(nil, spec)
  #     end

  #     test "a decimal spec with exclusive bounds" do
  #       spec = assert DecimalSpec.new(gt: 1, lt: 3)
  #       assert {:error, _} = Spec.validate("1", spec)
  #       assert :ok = Spec.validate("2", spec)
  #       assert {:error, _} = Spec.validate("3", spec)
  #     end

  #     test "a decimal spec with inclusive bounds" do
  #       spec = assert DecimalSpec.new(gte: 1, lte: 3)
  #       assert {:error, _} = Spec.validate("0.999", spec)
  #       assert :ok = Spec.validate("1", spec)
  #       assert :ok = Spec.validate("2", spec)
  #       assert :ok = Spec.validate("3", spec)
  #       assert {:error, _} = Spec.validate("3.001", spec)
  #     end

  #     test "a decimal spec with max_decimal_places" do
  #       spec = assert DecimalSpec.new(max_decimal_places: 2)
  #       assert :ok = Spec.validate("1.0", spec)
  #       assert :ok = Spec.validate("1.00", spec)
  #       assert {:error, _} = Spec.validate("1.000", spec)
  #     end
  # end
end
