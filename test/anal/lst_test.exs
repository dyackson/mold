# defmodule Anal.LstTest do
#   alias Anal.SpecError
#   alias Anal.Spec
#   alias Anal.Lst
#   alias Anal.Str
#   alias Anal.Int

#   use ExUnit.Case

#   describe "Lst.new()" do
#     test "creates a list spec" do
#       assert Lst.new(of: Str.new()) == %Lst{
#                can_be_nil: false,
#                of: %Str{},
#                min_len: nil,
#                max_len: nil,
#                also: nil
#              }

#       assert %Lst{
#                can_be_nil: true,
#                of: %Str{},
#                min_len: 1,
#                max_len: 10,
#                also: also
#              } =
#                Lst.new(
#                  can_be_nil: true,
#                  of: Str.new(),
#                  min_len: 1,
#                  max_len: 10,
#                  also: &(rem(&1, 2) == 0)
#                )

#       assert is_function(also, 1)

#       assert_raise ArgumentError, ~r/the following keys must also be given.* \[:of\]/, fn ->
#         Lst.new()
#       end

#       assert_raise SpecError, ":of must be a spec", fn ->
#         Lst.new(of: "foo")
#       end

#       assert_raise SpecError, ":also must be a 1-arity function, got \"foo\"", fn ->
#         Lst.new(of: Str.new(), also: "foo")
#       end

#       assert_raise SpecError, ":min_len must be a non-negative integer", fn ->
#         Lst.new(of: Str.new(), min_len: "foo")
#       end

#       assert_raise SpecError, ":max_len must be a non-negative integer", fn ->
#         Lst.new(of: Str.new(), max_len: -4)
#       end

#       assert_raise SpecError, ":min_len cannot be greater than :max_len", fn ->
#         Lst.new(of: Str.new(), max_len: 1, min_len: 2)
#       end

#       assert %Lst{min_len: 1, max_len: nil} = Lst.new(of: Str.new(), min_len: 1)

#       assert %Lst{min_len: nil, max_len: 1} = Lst.new(of: Str.new(), max_len: 1)
#     end

#     test "validates using a list spec" do
#       spec = Lst.new(of: Str.new())

#       assert :ok = Spec.validate([], spec)
#       assert Spec.validate(nil, spec) == {:error, "cannot be nil"}

#       min_len_spec = Lst.new(of: Str.new(), min_len: 1)
#       assert Spec.validate([], min_len_spec) == {:error, "length must be at least 1"}
#       assert :ok = Spec.validate(["a"], min_len_spec)
#       assert :ok = Spec.validate(["a", "b"], min_len_spec)

#       max_len_spec = Lst.new(of: Str.new(), max_len: 1)
#       assert :ok = Spec.validate(["a"], max_len_spec)
#       assert :ok = Spec.validate(["a"], max_len_spec)
#       assert Spec.validate(["a", "b"], max_len_spec) == {:error, "length cannot exceed 1"}

#       spec = Lst.new(of: Str.new())
#       assert :ok = Spec.validate(["a", "b"], spec)

#       assert Spec.validate([1, "a", true], spec) ==
#                {:error, %{[0] => "must be a string", [2] => "must be a string"}}

#       also = fn ints ->
#         sum = Enum.sum(ints)
#         if sum > 5, do: {:error, "sum is too high"}, else: :ok
#       end

#       also_spec = Lst.new(of: Int.new(can_be_nil: false), also: also)

#       assert :ok = Spec.validate([1, 0, 0, 0, 0, 3], also_spec)
#       assert Spec.validate([1, 6], also_spec) == {:error, "sum is too high"}
#     end
#   end
# end
