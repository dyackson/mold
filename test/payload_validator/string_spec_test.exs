defmodule PayloadValidator.StringSpecTest do
  alias PayloadValidator.SpecError
  alias PayloadValidator.StringSpec

  import StringSpec

  use ExUnit.Case

  # TODO: figure out what this is
  doctest PayloadValidator

  describe "StringSpec.string/1" do
    test "creates a string spec" do
      assert string() == %StringSpec{nullable: false, required: false}
      assert string(required: true, nullable: true) == %StringSpec{nullable: true, required: true}
    end

    test "creates a string spec with enum_vals" do
      enum_vals = ["a", "b"]

      assert string(enum_vals: enum_vals) == %StringSpec{
               nullable: false,
               required: false,
               enum_vals: enum_vals
             }

      assert string(required: true, nullable: true, case_insensative: true, enum_vals: enum_vals) ==
               %StringSpec{
                 nullable: true,
                 required: true,
                 enum_vals: enum_vals,
                 case_insensative: true
               }

      assert %StringSpec{and: and_fn} = string(and: fn it -> String.length(it) > 4 end)
      assert is_function(and_fn)
    end

    test "creates a string spec with regex" do
      regex = ~r/foo/

      assert string(regex: regex) == %StringSpec{
               nullable: false,
               required: false,
               regex: regex
             }
    end

    test "raises if given bad opts" do
      fun_name = "PayloadValidator.StringSpec.string/1"

      assert_raise SpecError, "for #{fun_name}, required must be a boolean", fn ->
        string(required: "foo")
      end

      assert_raise SpecError, "for #{fun_name}, nullable must be a boolean", fn ->
        string(nullable: nil)
      end

      assert_raise SpecError, "for #{fun_name}, enum_vals must be a list", fn ->
        string(enum_vals: "foo")
      end

      assert_raise SpecError, "for #{fun_name}, enum_vals cannot be empty", fn ->
        string(enum_vals: [])
      end

      assert_raise SpecError, "for #{fun_name}, case_insensative must be a boolean", fn ->
        string(enum_vals: ["1", "2"], case_insensative: "foo")
      end

      assert_raise SpecError, "for #{fun_name}, enum_vals can only contain strings", fn ->
        string(case_insensative: true, enum_vals: [:ea, 1])
      end

      assert_raise SpecError, "for #{fun_name}, regex must be a Regex", fn ->
        string(regex: "foo")
      end

      assert_raise SpecError,
                   "for #{fun_name}, enum_vals and regex are not allowed together",
                   fn ->
                     string(regex: ~r/foo/, enum_vals: ["a", "b"])
                   end

      assert_raise SpecError,
                   "for #{fun_name}, and opt must be a function",
                   fn ->
                     string(and: "something")
                   end
    end
  end

  describe "StringSpec.conform/1" do
    test "checks a value against a StringSpec" do
      assert conform("yes", string()) == :ok
      assert conform([], string()) == {:error, "must be a string"}
      assert conform(nil, string(nullable: true)) == :ok
      assert conform(nil, string()) == {:error, "cannot be nil"}
    end

    test "checks a values against enum_vals" do
      enum_vals = ~w[a b]
      assert conform("a", string(enum_vals: enum_vals)) == :ok

      assert conform("c", string(enum_vals: enum_vals)) ==
               {:error, "must be one of: a, b (case sensative)"}

      assert conform("A", string(enum_vals: enum_vals)) ==
               {:error, "must be one of: a, b (case sensative)"}

      assert conform("A", string(enum_vals: enum_vals, case_insensative: true)) == :ok

      assert conform("c", string(enum_vals: enum_vals, case_insensative: true)) ==
               {:error, "must be one of: a, b (case insensative)"}
    end

    test "checks a value against a Regex" do
      regex = ~r/^foo/

      assert conform("fool", string(regex: regex)) == :ok
      assert conform("ofoo", string(regex: regex)) == {:error, "must match regex: ^foo"}
    end

    test "checks a value against a StringSpec and against an 'and' function" do
      assert conform("fool", string(and: &(String.length(&1) < 10))) == :ok

      assert conform(
               "fool",
               string(
                 and: fn it ->
                   if String.length(it) < 10, do: :ok, else: {:error, "too long"}
                 end
               )
             ) == :ok

      assert conform("fool", string(and: &(String.length(&1) < 3))) == {:error, "invalid"}

      assert conform(
               "fool",
               string(
                 and: fn it ->
                   if String.length(it) < 3, do: :ok, else: {:error, "too long"}
                 end
               )
             ) == {:error, "too long"}

      assert conform(
               "fool",
               string(
                 and: fn it ->
                   if String.length(it) < 3, do: :ok, else: "too long"
                 end
               )
             ) == {:error, "too long"}
    end

    test "checks the 'and' only if the other validations pass" do
      assert conform(4, string(and: &(String.length(&1) < 10))) == {:error, "must be a string"}
      assert conform(nil, string(and: &(String.length(&1) < 10))) == {:error, "cannot be nil"}
    end
  end
end
