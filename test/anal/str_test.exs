defmodule Anal.StrTest do
  alias Anal.SpecError
  alias Anal.Str

  use ExUnit.Case

  describe "Anal.prep! a Str raises a SpecError when" do
    test "nil_ok? not a boolean" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Str{nil_ok?: "yuh"})
      end)
    end

    test ":also is not an arity-1 function" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Anal.prep!(%Str{also: &(&1 + &2)})
      end)
    end

    test ":regex is not a Regex" do
      assert_raise(SpecError, ":regex must be a Regex", fn ->
        Anal.prep!(%Str{regex: "meh"})
      end)
    end

    test ":one_of is not a list of strings" do
      assert_raise(SpecError, ":one_of must be a non-empty list of strings", fn ->
        Anal.prep!(%Str{one_of: "meh"})
      end)
    end

    test ":one_of_ci is not a list of strings" do
      assert_raise(SpecError, ":one_of_ci must be a non-empty list of strings", fn ->
        Anal.prep!(%Str{one_of_ci: "meh"})
      end)
    end

    test ":min_length is not a positive integer" do
      assert_raise(SpecError, ":min_length must be a positive integer", fn ->
        Anal.prep!(%Str{min_length: 0})
      end)
    end

    test ":max_length is not a positive integer" do
      assert_raise(SpecError, ":max_length must be a positive integer", fn ->
        Anal.prep!(%Str{max_length: 0})
      end)
    end

    test ":max_length is less than min_length" do
      assert_raise(SpecError, ":max_length must be greater than or equal to :min_length", fn ->
        Anal.prep!(%Str{max_length: 1, min_length: 2})
      end)
    end

    test "using both :one_of and :one_of_ci" do
      assert_raise(SpecError, "cannot use both :one_of and :one_of_ci", fn ->
        Anal.prep!(%Str{one_of: ["foo", "bar"], one_of_ci: ["pooh", "bear"]})
      end)
    end

    test "using both :one_of and :regex" do
      assert_raise(SpecError, "cannot use both :regex and :one_of", fn ->
        Anal.prep!(%Str{one_of: ["foo", "bar"], regex: ~r/^(foo|bar)$/})
      end)
    end

    test "using both :one_of_ci and :regex" do
      assert_raise(SpecError, "cannot use both :regex and :one_of_ci", fn ->
        Anal.prep!(%Str{one_of_ci: ["foo", "bar"], regex: ~r/^(foo|bar)$/})
      end)
    end

    test "using both min_length/max_length and an regex/one_of/one_of_ci" do
      assert_raise(SpecError, "cannot use both :regex and :min_length", fn ->
        Anal.prep!(%Str{min_length: 5, regex: ~r/^(foo|bar)$/})
      end)

      assert_raise(SpecError, "cannot use both :one_of and :min_length", fn ->
        Anal.prep!(%Str{min_length: 5, one_of: ["fool", "bart"]})
      end)

      assert_raise(SpecError, "cannot use both :one_of_ci and :max_length", fn ->
        Anal.prep!(%Str{max_length: 5, one_of_ci: ["fool", "bart"]})
      end)
    end
  end

  describe "Anal.prep!/1 a valid Int" do
    test "adds a default error message" do
      assert %Str{error_message: "must be a string"} = Anal.prep!(%Str{})

      assert %Str{error_message: "must be a string that matches the regex ~r/^\\d+$/"} =
               Anal.prep!(%Str{regex: ~r/^\d+$/})

      assert %Str{error_message: "must be a string with at least 5 and at most 10 characters"} =
               Anal.prep!(%Str{min_length: 5, max_length: 10})
    end
  end

  #   describe "Str.new/1" do
  #     test "creates a string spec" do
  #       a_regex = ~r/^\d+$/
  #       assert Str.new() == %Str{can_be_nil: false}
  #       assert Str.new(can_be_nil: false) == %Str{can_be_nil: false}
  #       assert Str.new(regex: a_regex) == %Str{can_be_nil: false, regex: a_regex}

  #       assert Str.new(one_of: ["foo", "bar"]) == %Str{
  #                can_be_nil: false,
  #                one_of: ["foo", "bar"]
  #              }

  #       assert Str.new(one_of_ci: ["foo", "bar"]) == %Str{
  #                can_be_nil: false,
  #                one_of_ci: ["foo", "bar"]
  #              }

  #       assert %Str{can_be_nil: false, also: also} =
  #                Str.new(can_be_nil: false, also: fn str -> String.contains?(str, "x") end)

  #       assert is_function(also, 1)

  #       assert_raise SpecError, ":also must be a 1-arity function, got \"foo\"", fn ->
  #         Str.new(can_be_nil: false, also: "foo")
  #       end

  #       assert_raise SpecError, ~r/also must be a 1-arity function, got/, fn ->
  #         Str.new(can_be_nil: false, also: fn _x, _y -> nil end)
  #       end

  #       assert_raise SpecError, ":can_be_nil must be a boolean, got \"foo\"", fn ->
  #         Str.new(can_be_nil: "foo")
  #       end

  #       assert_raise KeyError, ~r/key :foo not found/, fn ->
  #         Str.new(foo: "bar")
  #       end

  #       assert_raise SpecError, ":regex must be a Regex", fn ->
  #         Str.new(regex: "bar")
  #       end

  #       assert_raise SpecError, ":one_of must be a non-empty list of strings", fn ->
  #         Str.new(one_of: "foo")
  #       end

  #       assert_raise SpecError, ":one_of must be a non-empty list of strings", fn ->
  #         Str.new(one_of: [])
  #       end

  #       assert_raise SpecError, ":one_of_ci must be a non-empty list of strings", fn ->
  #         Str.new(one_of_ci: "foo")
  #       end

  #       assert_raise SpecError, ":one_of_ci must be a non-empty list of strings", fn ->
  #         Str.new(one_of_ci: [])
  #       end

  #       assert_raise SpecError, "cannot use both :regex and :one_of_ci", fn ->
  #         Str.new(one_of_ci: ["foo"], regex: a_regex)
  #       end

  #       assert_raise SpecError, "cannot use both :regex and :one_of", fn ->
  #         Str.new(one_of: ["foo"], regex: a_regex)
  #       end

  #       assert_raise SpecError, "cannot use both :one_of and :one_of_ci", fn ->
  #         Str.new(one_of: ["foo"], one_of_ci: ["foo"])
  #       end
  #     end

  #     test "validates values" do
  #       spec = Str.new()
  #       assert :ok = Spec.validate("foo", spec)
  #       assert {:error, "cannot be nil"} = Spec.validate(nil, spec)
  #       assert {:error, "must be a string"} = Spec.validate(5, spec)

  #       can_be_nil_spec = Str.new(can_be_nil: true)
  #       assert :ok = Spec.validate("foo", can_be_nil_spec)
  #       assert :ok = Spec.validate(nil, can_be_nil_spec)

  #       re_spec = Str.new(regex: ~r/^\d+$/)
  #       assert :ok = Spec.validate("1", re_spec)
  #       assert {:error, "cannot be nil"} = Spec.validate(nil, re_spec)

  #       also = &if String.contains?(&1, "x"), do: :ok, else: {:error, "need an x"}

  #       also_spec = Str.new(can_be_nil: false, also: also)

  #       assert :ok = Spec.validate("box", also_spec)
  #       assert {:error, "need an x"} = Spec.validate("bocks", also_spec)

  #       can_be_nil_also_spec = Str.new(can_be_nil: true, also: also)

  #       assert :ok = Spec.validate(nil, can_be_nil_also_spec)
  #       assert {:error, "need an x"} = Spec.validate("bocks", can_be_nil_also_spec)

  #       # TODO: implement and test min_len, max_len,
  #       one_of_spec = Str.new(one_of: ["foo", "bar"])
  #       assert :ok = Spec.validate("foo", one_of_spec)

  #       assert {:error, "must be a case-sensative match for one of: foo, bar"} =
  #                Spec.validate("farts", one_of_spec)

  #       one_of_ci_spec = Str.new(one_of_ci: ["foo", "BAR"])
  #       assert :ok = Spec.validate("fOo", one_of_ci_spec)
  #       assert :ok = Spec.validate("BaR", one_of_ci_spec)

  #       assert {:error, "must be a case-insensative match for one of: foo, bar"} =
  #                Spec.validate("farts", one_of_ci_spec)
  #     end

  #     test "with also" do
  #       also = fn str ->
  #         if String.contains?(str, "x"), do: :ok, else: {:error, "need an x"}
  #       end

  #       assert :ok = Spec.validate("box", Str.new(also: also))
  #       assert {:error, "need an x"} = Spec.validate("bo", Str.new(also: also))
  #     end
  #   end
end
