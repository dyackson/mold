defmodule Anal.ListSpecTest do
  alias Anal.SpecError
  alias Anal.Spec
  alias Anal.ListSpec
  alias Anal.StringSpec
  alias Anal.IntegerSpec

  use ExUnit.Case

  describe "ListSpec.new()" do
    test "creates a list spec" do
      assert ListSpec.new(of: StringSpec.new()) == %ListSpec{
               nullable: false,
               of: %StringSpec{},
               min_len: nil,
               max_len: nil,
               also: nil
             }

      assert %ListSpec{
               nullable: true,
               of: %StringSpec{},
               min_len: 1,
               max_len: 10,
               also: also
             } =
               ListSpec.new(
                 nullable: true,
                 of: StringSpec.new(),
                 min_len: 1,
                 max_len: 10,
                 also: &(rem(&1, 2) == 0)
               )

      assert is_function(also, 1)

      assert_raise ArgumentError, ~r/the following keys must also be given.* \[:of\]/, fn ->
        ListSpec.new()
      end

      assert_raise SpecError, ":of must be a spec", fn ->
        ListSpec.new(of: "foo")
      end

      assert_raise SpecError, ":also must be a 1-arity function, got \"foo\"", fn ->
        ListSpec.new(of: StringSpec.new(), also: "foo")
      end

      assert_raise SpecError, ":min_len must be a non-negative integer", fn ->
        ListSpec.new(of: StringSpec.new(), min_len: "foo")
      end

      assert_raise SpecError, ":max_len must be a non-negative integer", fn ->
        ListSpec.new(of: StringSpec.new(), max_len: -4)
      end

      assert_raise SpecError, ":min_len cannot be greater than :max_len", fn ->
        ListSpec.new(of: StringSpec.new(), max_len: 1, min_len: 2)
      end

      assert %ListSpec{min_len: 1, max_len: nil} = ListSpec.new(of: StringSpec.new(), min_len: 1)

      assert %ListSpec{min_len: nil, max_len: 1} = ListSpec.new(of: StringSpec.new(), max_len: 1)
    end

    test "validates using a list spec" do
      spec = ListSpec.new(of: StringSpec.new())

      assert :ok = Spec.validate([], spec)
      assert Spec.validate(nil, spec) == {:error, "cannot be nil"}

      min_len_spec = ListSpec.new(of: StringSpec.new(), min_len: 1)
      assert Spec.validate([], min_len_spec) == {:error, "length must be at least 1"}
      assert :ok = Spec.validate(["a"], min_len_spec)
      assert :ok = Spec.validate(["a", "b"], min_len_spec)

      max_len_spec = ListSpec.new(of: StringSpec.new(), max_len: 1)
      assert :ok = Spec.validate(["a"], max_len_spec)
      assert :ok = Spec.validate(["a"], max_len_spec)
      assert Spec.validate(["a", "b"], max_len_spec) == {:error, "length cannot exceed 1"}

      spec = ListSpec.new(of: StringSpec.new())
      assert :ok = Spec.validate(["a", "b"], spec)

      assert Spec.validate([1, "a", true], spec) ==
               {:error, %{[0] => "must be a string", [2] => "must be a string"}}

      also = fn ints ->
        sum = Enum.sum(ints)
        if sum > 5, do: {:error, "sum is too high"}, else: :ok
      end

      also_spec = ListSpec.new(of: IntegerSpec.new(nullable: false), also: also)

      assert :ok = Spec.validate([1, 0, 0, 0, 0, 3], also_spec)
      assert Spec.validate([1, 6], also_spec) == {:error, "sum is too high"}
    end
  end
end
