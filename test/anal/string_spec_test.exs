defmodule Anal.StringSpecTest do
  alias Anal.SpecError
  alias Anal.Spec
  alias Anal.StringSpec

  use ExUnit.Case

  describe "StringSpec.new/1" do
    test "creates a string spec" do
      a_regex = ~r/^\d+$/
      assert StringSpec.new() == %StringSpec{can_be_nil: false}
      assert StringSpec.new(can_be_nil: false) == %StringSpec{can_be_nil: false}
      assert StringSpec.new(regex: a_regex) == %StringSpec{can_be_nil: false, regex: a_regex}

      assert StringSpec.new(one_of: ["foo", "bar"]) == %StringSpec{
               can_be_nil: false,
               one_of: ["foo", "bar"]
             }

      assert StringSpec.new(one_of_ci: ["foo", "bar"]) == %StringSpec{
               can_be_nil: false,
               one_of_ci: ["foo", "bar"]
             }

      assert %StringSpec{can_be_nil: false, also: also} =
               StringSpec.new(can_be_nil: false, also: fn str -> String.contains?(str, "x") end)

      assert is_function(also, 1)

      assert_raise SpecError, ":also must be a 1-arity function, got \"foo\"", fn ->
        StringSpec.new(can_be_nil: false, also: "foo")
      end

      assert_raise SpecError, ~r/also must be a 1-arity function, got/, fn ->
        StringSpec.new(can_be_nil: false, also: fn _x, _y -> nil end)
      end

      assert_raise SpecError, ":can_be_nil must be a boolean, got \"foo\"", fn ->
        StringSpec.new(can_be_nil: "foo")
      end

      assert_raise KeyError, ~r/key :foo not found/, fn ->
        StringSpec.new(foo: "bar")
      end

      assert_raise SpecError, ":regex must be a Regex", fn ->
        StringSpec.new(regex: "bar")
      end

      assert_raise SpecError, ":one_of must be a non-empty list of strings", fn ->
        StringSpec.new(one_of: "foo")
      end

      assert_raise SpecError, ":one_of must be a non-empty list of strings", fn ->
        StringSpec.new(one_of: [])
      end

      assert_raise SpecError, ":one_of_ci must be a non-empty list of strings", fn ->
        StringSpec.new(one_of_ci: "foo")
      end

      assert_raise SpecError, ":one_of_ci must be a non-empty list of strings", fn ->
        StringSpec.new(one_of_ci: [])
      end

      assert_raise SpecError, "cannot use both :regex and :one_of_ci", fn ->
        StringSpec.new(one_of_ci: ["foo"], regex: a_regex)
      end

      assert_raise SpecError, "cannot use both :regex and :one_of", fn ->
        StringSpec.new(one_of: ["foo"], regex: a_regex)
      end

      assert_raise SpecError, "cannot use both :one_of and :one_of_ci", fn ->
        StringSpec.new(one_of: ["foo"], one_of_ci: ["foo"])
      end
    end

    test "validates values" do
      spec = StringSpec.new()
      assert :ok = Spec.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, spec)
      assert {:error, "must be a string"} = Spec.validate(5, spec)

      can_be_nil_spec = StringSpec.new(can_be_nil: true)
      assert :ok = Spec.validate("foo", can_be_nil_spec)
      assert :ok = Spec.validate(nil, can_be_nil_spec)

      re_spec = StringSpec.new(regex: ~r/^\d+$/)
      assert :ok = Spec.validate("1", re_spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, re_spec)

      also = &if String.contains?(&1, "x"), do: :ok, else: {:error, "need an x"}

      also_spec = StringSpec.new(can_be_nil: false, also: also)

      assert :ok = Spec.validate("box", also_spec)
      assert {:error, "need an x"} = Spec.validate("bocks", also_spec)

      can_be_nil_also_spec = StringSpec.new(can_be_nil: true, also: also)

      assert :ok = Spec.validate(nil, can_be_nil_also_spec)
      assert {:error, "need an x"} = Spec.validate("bocks", can_be_nil_also_spec)

      # TODO: implement and test min_len, max_len,
      one_of_spec = StringSpec.new(one_of: ["foo", "bar"])
      assert :ok = Spec.validate("foo", one_of_spec)

      assert {:error, "must be a case-sensative match for one of: foo, bar"} =
               Spec.validate("farts", one_of_spec)

      one_of_ci_spec = StringSpec.new(one_of_ci: ["foo", "BAR"])
      assert :ok = Spec.validate("fOo", one_of_ci_spec)
      assert :ok = Spec.validate("BaR", one_of_ci_spec)

      assert {:error, "must be a case-insensative match for one of: foo, bar"} =
               Spec.validate("farts", one_of_ci_spec)
    end

    test "with also" do
      also = fn str ->
        if String.contains?(str, "x"), do: :ok, else: {:error, "need an x"}
      end

      assert :ok = Spec.validate("box", StringSpec.new(also: also))
      assert {:error, "need an x"} = Spec.validate("bo", StringSpec.new(also: also))
    end
  end
end
