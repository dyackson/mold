# defmodule Anal.IntTest do
#   alias Anal.SpecError
#   alias Anal.Spec
#   alias Anal.Int

#   use ExUnit.Case

#   describe "Int.new/1" do
#     test "creates as integer spec" do
#       default_error_message = "must be an integer"

#       assert Int.new(can_be_nil: true) == %Int{
#                can_be_nil: true,
#                error_message: default_error_message
#              }

#       assert Int.new() == %Int{
#                can_be_nil: false,
#                error_message: default_error_message
#              }

#       Enum.each([:gt, :lt, :gte, :lte], fn comp ->
#         assert_raise SpecError, ":#{comp} must be an integer", fn ->
#           Int.new([{comp, "5"}])
#         end
#       end)

#       assert_raise SpecError, "cannot use both :gt and :gte", fn ->
#         Int.new(gt: 5, gte: 3)
#       end

#       assert_raise SpecError, "cannot use both :lt and :lte", fn ->
#         Int.new(lt: 5, lte: 3)
#       end

#       # lt/gt
#       assert_raise SpecError, ":gt must be less than :lt", fn ->
#         Int.new(lt: 0, gt: 3)
#       end

#       assert_raise SpecError, ":gt must be less than :lt", fn ->
#         Int.new(lt: 0, gt: 0)
#       end

#       # lte/gt
#       assert_raise SpecError, ":gt must be less than :lte", fn ->
#         Int.new(lte: 0, gt: 3)
#       end

#       assert_raise SpecError, ":gt must be less than :lte", fn ->
#         Int.new(lte: 0, gt: 0)
#       end

#       # lt/gte
#       assert_raise SpecError, ":gte must be less than :lt", fn ->
#         Int.new(lt: 0, gte: 3)
#       end

#       assert_raise SpecError, ":gte must be less than :lt", fn ->
#         Int.new(lt: 0, gte: 0)
#       end

#       # lte/gte
#       assert_raise SpecError, ":gte must be less than :lte", fn ->
#         Int.new(lte: 0, gte: 3)
#       end

#       assert_raise SpecError, ":gte must be less than :lte", fn ->
#         Int.new(lte: 0, gte: 0)
#       end
#     end

#     test "validate with an integer Spec" do
#       spec = Int.new()
#       assert :ok = Spec.validate(9, spec)
#       assert {:error, "must be an integer"} = Spec.validate("foo", spec)
#       assert {:error, "cannot be nil"} = Spec.validate(nil, spec)
#       assert :ok = Spec.validate(nil, Int.new(can_be_nil: true))

#       bounds_spec = Int.new(gt: 0, lt: 10)
#       assert :ok = Spec.validate(5, bounds_spec)
#       assert {:error, "must be less than 10"} = Spec.validate(10, bounds_spec)
#       assert {:error, "must be greater than 0"} = Spec.validate(0, bounds_spec)

#       bounds_spec = Int.new(gte: 0, lte: 10)
#       assert :ok = Spec.validate(5, bounds_spec)
#       assert :ok = Spec.validate(0, bounds_spec)
#       assert :ok = Spec.validate(10, bounds_spec)
#       assert {:error, "must be less than or equal to 10"} = Spec.validate(11, bounds_spec)
#       assert {:error, "must be greater than or equal to 0"} = Spec.validate(-1, bounds_spec)
#     end
#   end
# end
