defmodule Anal.IntegerSpecTest do
  alias Anal.SpecError
  alias Anal.Spec
  alias Anal.IntegerSpec

  use ExUnit.Case

  describe "IntegerSpec.new/1" do
    test "creates as integer spec" do
      default_error_message = "must be an integer"

      assert IntegerSpec.new(can_be_nil: true) == %IntegerSpec{
               can_be_nil: true,
               error_message: default_error_message
             }

      assert IntegerSpec.new() == %IntegerSpec{
               can_be_nil: false,
               error_message: default_error_message
             }

      Enum.each([:gt, :lt, :gte, :lte], fn comp ->
        assert_raise SpecError, ":#{comp} must be an integer", fn ->
          IntegerSpec.new([{comp, "5"}])
        end
      end)

      assert_raise SpecError, "cannot use both :gt and :gte", fn ->
        IntegerSpec.new(gt: 5, gte: 3)
      end

      assert_raise SpecError, "cannot use both :lt and :lte", fn ->
        IntegerSpec.new(lt: 5, lte: 3)
      end

      # lt/gt
      assert_raise SpecError, ":gt must be less than :lt", fn ->
        IntegerSpec.new(lt: 0, gt: 3)
      end

      assert_raise SpecError, ":gt must be less than :lt", fn ->
        IntegerSpec.new(lt: 0, gt: 0)
      end

      # lte/gt
      assert_raise SpecError, ":gt must be less than :lte", fn ->
        IntegerSpec.new(lte: 0, gt: 3)
      end

      assert_raise SpecError, ":gt must be less than :lte", fn ->
        IntegerSpec.new(lte: 0, gt: 0)
      end

      # lt/gte
      assert_raise SpecError, ":gte must be less than :lt", fn ->
        IntegerSpec.new(lt: 0, gte: 3)
      end

      assert_raise SpecError, ":gte must be less than :lt", fn ->
        IntegerSpec.new(lt: 0, gte: 0)
      end

      # lte/gte
      assert_raise SpecError, ":gte must be less than :lte", fn ->
        IntegerSpec.new(lte: 0, gte: 3)
      end

      assert_raise SpecError, ":gte must be less than :lte", fn ->
        IntegerSpec.new(lte: 0, gte: 0)
      end
    end

    test "validate with an integer Spec" do
      spec = IntegerSpec.new()
      assert :ok = Spec.validate(9, spec)
      assert {:error, "must be an integer"} = Spec.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, spec)
      assert :ok = Spec.validate(nil, IntegerSpec.new(can_be_nil: true))

      bounds_spec = IntegerSpec.new(gt: 0, lt: 10)
      assert :ok = Spec.validate(5, bounds_spec)
      assert {:error, "must be less than 10"} = Spec.validate(10, bounds_spec)
      assert {:error, "must be greater than 0"} = Spec.validate(0, bounds_spec)

      bounds_spec = IntegerSpec.new(gte: 0, lte: 10)
      assert :ok = Spec.validate(5, bounds_spec)
      assert :ok = Spec.validate(0, bounds_spec)
      assert :ok = Spec.validate(10, bounds_spec)
      assert {:error, "must be less than or equal to 10"} = Spec.validate(11, bounds_spec)
      assert {:error, "must be greater than or equal to 0"} = Spec.validate(-1, bounds_spec)
    end
  end
end
