defmodule Dammit.StringSpecTest do
  alias Dammit.SpecError
  alias Dammit.Spec
  alias Dammit.StringSpec

  use ExUnit.Case

  describe "StringSpec.new/1" do
    test "creates a string spec" do
      a_regex = ~r/^\d+$/
      assert StringSpec.new() == %StringSpec{nullable: false}
      assert StringSpec.new(nullable: false) == %StringSpec{nullable: false}
      assert StringSpec.new(regex: a_regex) == %StringSpec{nullable: false, regex: a_regex}
      assert StringSpec.new(one_of: ["foo", "bar"]) == %StringSpec{nullable: false, one_of: ["foo", "bar"]}

      assert StringSpec.new(one_of_ci: ["foo", "bar"]) == %StringSpec{
               nullable: false,
               one_of_ci: ["foo", "bar"]
             }

      assert %StringSpec{nullable: false, and: and_fn} =
               StringSpec.new(nullable: false, and: fn str -> String.contains?(str, "x") end)

      assert is_function(and_fn, 1)

      assert_raise SpecError, ":and must be a 1-arity function, got \"foo\"", fn ->
        StringSpec.new(nullable: false, and: "foo")
      end

      assert_raise SpecError, ~r/and must be a 1-arity function, got/, fn ->
        StringSpec.new(nullable: false, and: fn _x, _y -> nil end)
      end

      assert_raise SpecError, ":nullable must be a boolean, got \"foo\"", fn ->
        StringSpec.new(nullable: "foo")
      end

      assert_raise SpecError, ":foo is not a field of Dammit.Spec.String", fn ->
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

      nullable_spec = StringSpec.new(nullable: true)
      assert :ok = Spec.validate("foo", nullable_spec)
      assert :ok = Spec.validate(nil, nullable_spec)

      re_spec = StringSpec.new(regex: ~r/^\d+$/)
      assert :ok = Spec.validate("1", re_spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, re_spec)

      and_spec = StringSpec.new(nullable: false, and: fn str -> String.contains?(str, "x") end)
      assert :ok = Spec.validate("box", and_spec)
      assert {:error, "invalid"} = Spec.validate("bocks", and_spec)

      nullable_and_spec = StringSpec.new(nullable: true, and: fn str -> String.contains?(str, "x") end)
      assert :ok = Spec.validate(nil, nullable_and_spec)
      assert {:error, "invalid"} = Spec.validate("bocks", nullable_and_spec)

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

    test "various allowed return vals for and_fn" do
      ret_ok = fn str ->
        if String.contains?(str, "x"), do: :ok, else: {:error, "need an x"}
      end

      assert :ok = Spec.validate("box", StringSpec.new(and: ret_ok))
      assert {:error, "need an x"} = Spec.validate("bo", StringSpec.new(and: ret_ok))

      ret_bool = &String.contains?(&1, "x")
      assert :ok = Spec.validate("box", StringSpec.new(and: ret_bool))

      assert {:error, "no good"} = Spec.validate("bo", StringSpec.new(and: fn _str -> "no good" end))
    end
  end
end