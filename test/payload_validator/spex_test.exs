defmodule PayloadValidator.SpexTest do
  alias PayloadValidator.SpecError
  alias PayloadValidator.Spex
  alias PayloadValidator.Spex.String, as: Str

  # import Str

  use ExUnit.Case

  # TODO: figure out what this is
  doctest PayloadValidator

  describe "StringSpec.string/1" do
    test "creates a string spec" do
      assert Str.new() == %Str{nullable: false}
      assert Str.new(nullable: false) == %Str{nullable: false}
      assert Str.new(regex: ~r/^\d+$/) == %Str{nullable: false, regex: ~r/^\d+$/}

      assert %Str{nullable: false, and: and_fn} =
               Str.new(nullable: false, and: fn str -> String.contains?(str, "x") end)

      assert is_function(and_fn, 1)

      assert_raise SpecError, ":and must be a 1-arity function, got \"foo\"", fn ->
        Str.new(nullable: false, and: "foo")
      end

      assert_raise SpecError, ~r/and must be a 1-arity function, got/, fn ->
        Str.new(nullable: false, and: fn _x, _y  -> nil end)
      end

      assert_raise SpecError, ":nullable must be a boolean, got \"foo\"", fn ->
        Str.new(nullable: "foo")
      end

      assert_raise SpecError, ":foo is not a field of PayloadValidator.Spex.String", fn ->
        Str.new(foo: "bar")
      end

      assert_raise SpecError, ":regex must be a Regex", fn ->
        Str.new(regex: "bar")
      end
    end

    test "validates values" do
      spec = Str.new()
      assert :ok = Spex.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spex.validate(nil, spec)
      assert {:error, "must be a string"} = Spex.validate(5, spec)

      nullable_spec = Str.new(nullable: true)
      assert :ok = Spex.validate("foo", nullable_spec)
      assert :ok = Spex.validate(nil, nullable_spec)

      re_spec = Str.new(regex: ~r/^\d+$/)
      assert :ok = Spex.validate("1", re_spec)
      assert {:error, "cannot be nil"} = Spex.validate(nil, re_spec)

      and_spec = Str.new(nullable: false, and: fn str -> String.contains?(str, "x") end)
      assert :ok = Spex.validate("box", and_spec)
      assert {:error, "invalid"} = Spex.validate("bocks", and_spec)

      nullable_and_spec = Str.new(nullable: true, and: fn str -> String.contains?(str, "x") end)
      assert :ok = Spex.validate(nil, nullable_and_spec)
      assert {:error, "invalid"} = Spex.validate("bocks", nullable_and_spec)

      # TODO: implement and test min_len, max_len, and enum_vals
    end

    test "various allowed return vals for and_fn" do
      ret_ok = fn str ->
        if String.contains?(str, "x"), do: :ok, else: {:error, "need an x"}
      end

      assert :ok = Spex.validate("box", Str.new(and: ret_ok))
      assert {:error, "need an x"} = Spex.validate("bo", Str.new(and: ret_ok))

      ret_bool = &String.contains?(&1, "x")
      assert :ok = Spex.validate("box", Str.new(and: ret_bool))

      assert {:error, "no good"} = Spex.validate("bo", Str.new(and: fn _str -> "no good" end))
    end

    # test "creates a string spec with enum_vals" do
    #   enum_vals = ["a", "b"]

    #   assert string(enum_vals: enum_vals) == %StringSpec{
    #            nullable: false,
    #            required: false,
    #            enum_vals: enum_vals
    #          }

    #   assert string(required: true, nullable: true, case_insensative: true, enum_vals: enum_vals) ==
    #            %StringSpec{
    #              nullable: true,
    #              required: true,
    #              enum_vals: enum_vals,
    #              case_insensative: true
    #            }

    #     assert %StringSpec{and: and_fn} = string(and: fn it -> String.length(it) > 4 end)
    #     assert is_function(and_fn)
    #   end

    #   test "creates a string spec with regex" do
    #     regex = ~r/foo/

    #     assert string(regex: regex) == %StringSpec{
    #              nullable: false,
    #              required: false,
    #              regex: regex
    #            }
    #   end

    #   test "raises if given bad opts" do
    #     fun_name = "PayloadValidator.StringSpec.string/1"

    #     assert_raise SpecError, "for #{fun_name}, :required must be a boolean", fn ->
    #       string(required: "foo")
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :nullable must be a boolean", fn ->
    #       string(nullable: nil)
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :enum_vals must be a list", fn ->
    #       string(enum_vals: "foo")
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :enum_vals cannot be empty", fn ->
    #       string(enum_vals: [])
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :case_insensative must be a boolean", fn ->
    #       string(enum_vals: ["1", "2"], case_insensative: "foo")
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :enum_vals can only contain strings", fn ->
    #       string(case_insensative: true, enum_vals: [:ea, 1])
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :regex must be a Regex", fn ->
    #       string(regex: "foo")
    #     end

    #     assert_raise SpecError,
    #                  "for #{fun_name}, :enum_vals and :regex are not allowed together",
    #                  fn ->
    #                    string(regex: ~r/foo/, enum_vals: ["a", "b"])
    #                  end

    #     assert_raise SpecError,
    #                  "for #{fun_name}, :and must be a function",
    #                  fn ->
    #                    string(and: "something")
    #                  end

    #     assert_raise SpecError,
    #                  "for #{fun_name}, :fart is not an option",
    #                  fn ->
    #                    string(fart: "something")
    #                  end
    #   end
    # end

    # describe "StringSpec.conform/1" do
    #   test "checks a value against a StringSpec" do
    #     assert conform("yes", string()) == :ok
    #     assert conform([], string()) == {:error, "must be a string"}
    #     assert conform(nil, string(nullable: true)) == :ok
    #     assert conform(nil, string()) == {:error, "cannot be nil"} end

    #   test "checks a values against enum_vals" do
    #     enum_vals = ~w[a b]
    #     assert conform("a", string(enum_vals: enum_vals)) == :ok

    #     assert conform("c", string(enum_vals: enum_vals)) ==
    #              {:error, "must be one of: a, b (case sensative)"}

    #     assert conform("A", string(enum_vals: enum_vals)) ==
    #              {:error, "must be one of: a, b (case sensative)"}

    #     assert conform("A", string(enum_vals: enum_vals, case_insensative: true)) == :ok

    #     assert conform("c", string(enum_vals: enum_vals, case_insensative: true)) ==
    #              {:error, "must be one of: a, b (case insensative)"}
    #   end

    #   test "checks a value against a Regex" do
    #     regex = ~r/^foo/

    #     assert conform("fool", string(regex: regex)) == :ok
    #     assert conform("ofoo", string(regex: regex)) == {:error, "must match regex: ^foo"}
    #   end

    #   test "checks a value against a StringSpec and against an 'and' function" do
    #     assert conform("fool", string(and: &(String.length(&1) < 10))) == :ok

    #     assert conform(
    #              "fool",
    #              string(
    #                and: fn it ->
    #                  if String.length(it) < 10, do: :ok, else: {:error, "too long"}
    #                end
    #              )
    #            ) == :ok

    #     assert conform("fool", string(and: &(String.length(&1) < 3))) == {:error, "invalid"}

    #     assert conform(
    #              "fool",
    #              string(
    #                and: fn it ->
    #                  if String.length(it) < 3, do: :ok, else: {:error, "too long"}
    #                end
    #              )
    #            ) == {:error, "too long"}

    #     assert conform(
    #              "fool",
    #              string(
    #                and: fn it ->
    #                  if String.length(it) < 3, do: :ok, else: "too long"
    #                end
    #              )
    #            ) == {:error, "too long"}
    #   end

    #   test "checks the 'and' only if the other validations pass" do
    #     assert conform(4, string(and: &(String.length(&1) < 10))) == {:error, "must be a string"}
    #     assert conform(nil, string(and: &(String.length(&1) < 10))) == {:error, "cannot be nil"}
    #   end
  end
end
