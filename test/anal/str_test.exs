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

      assert %Str{
               error_message:
                 "must be one of these strings (with matching case): \"Simon\", \"Garfunkel\""
             } = Anal.prep!(%Str{one_of: ["Simon", "Garfunkel"]})

      assert %Str{
               error_message:
                 "must be one of these strings (case doesn't have to match): \"simon\", \"garfunkel\""
             } = Anal.prep!(%Str{one_of_ci: ["Simon", "Garfunkel"]})

      assert %Str{error_message: "must be a string matching the regex ~r/^\\d+$/"} =
               Anal.prep!(%Str{regex: ~r/^\d+$/})

      assert %Str{error_message: "must be a string with at least 5 characters"} =
               Anal.prep!(%Str{min_length: 5})

      assert %Str{error_message: "must be a string with at most 10 characters"} =
               Anal.prep!(%Str{max_length: 10})

      assert %Str{error_message: "must be a string with at least 5 and at most 10 characters"} =
               Anal.prep!(%Str{min_length: 5, max_length: 10})
    end

    test "accepts an error message" do
      assert %Str{error_message: "dammit"} = Anal.prep!(%Str{error_message: "dammit"})
    end
  end

  describe "Anal.exam using Str" do
    test "SpecError if the spec isn't prepped" do
      unprepped = %Str{}

      assert_raise(
        SpecError,
        "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
        fn ->
          Anal.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_spec = Anal.prep!(%Str{nil_ok?: true})
      nil_not_ok_spec = Anal.prep!(%Str{error_message: "dammit"})

      :ok = Anal.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
    end

    test "fail if not a string" do
      spec = Anal.prep!(%Str{error_message: "dammit"})
      assert :ok = Anal.exam(spec, "yes")
      assert :ok = Anal.exam(spec, "")

      [1, true, %{}, Decimal.new(1)]
      |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "takes an :also function" do
      spec = Anal.prep!(%Str{error_message: "dammit", also: &(&1 == String.reverse(&1))})

      :ok = Anal.exam(spec, "able was i ere i saw elba")
      {:error, "dammit"} = Anal.exam(spec, "anagram")
    end

    test "SpecError if :also doesn't return a boolean" do
      spec = Anal.prep!(%Str{error_message: "dammit", also: fn _ -> :some_shit end})

      assert_raise(SpecError, ":also must return a boolean, but it returned :some_shit", fn ->
        Anal.exam(spec, "pow")
      end)
    end

    test "checks :regex" do
      spec = Anal.prep!(%Str{error_message: "dammit", regex: ~r/^\d+$/})
      assert :ok = Anal.exam(spec, "123")
      assert {:error, "dammit"} = Anal.exam(spec, "1 2 3")
    end

    test "checks :one_of" do
      spec = Anal.prep!(%Str{error_message: "dammit", one_of: ["Paul", "Art"]})
      assert :ok = Anal.exam(spec, "Art")
      assert {:error, "dammit"} = Anal.exam(spec, "art")
      assert {:error, "dammit"} = Anal.exam(spec, "steve")
    end

    test "checks :one_of_ci" do
      spec = Anal.prep!(%Str{error_message: "dammit", one_of_ci: ["Paul", "Art"]})
      assert :ok = Anal.exam(spec, "Art")
      assert :ok = Anal.exam(spec, "art")
      assert {:error, "dammit"} = Anal.exam(spec, "steve")
    end

    test "checks :min_length" do
      spec = Anal.prep!(%Str{error_message: "dammit", min_length: 4})
      assert :ok = Anal.exam(spec, "12345")
      assert :ok = Anal.exam(spec, "1234")
      assert {:error, "dammit"} = Anal.exam(spec, "123")
    end

    test "checks :max_length" do
      spec = Anal.prep!(%Str{error_message: "dammit", max_length: 4})
      assert {:error, "dammit"} = Anal.exam(spec, "12345")
      assert :ok = Anal.exam(spec, "1234")
      assert :ok = Anal.exam(spec, "123")
    end

    test "checks both :min_length and :max_length" do
      spec = Anal.prep!(%Str{error_message: "dammit", min_length: 3, max_length: 4})
      assert {:error, "dammit"} = Anal.exam(spec, "12345")
      assert :ok = Anal.exam(spec, "1234")
      assert :ok = Anal.exam(spec, "123")
      assert {:error, "dammit"} = Anal.exam(spec, "12")
    end
  end
end
