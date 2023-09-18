defmodule Mold.StrTest do
  alias Mold.Error
  alias Mold.Str

  use ExUnit.Case

  describe "Mold.prep! a Str raises a Error when" do
    test "nil_ok? not a boolean" do
      assert_raise(Error, ":nil_ok? must be a boolean", fn ->
        Mold.prep!(%Str{nil_ok?: "yuh"})
      end)
    end

    test ":but is not an arity-1 function" do
      assert_raise(Error, ":but must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Str{but: &(&1 + &2)})
      end)
    end

    test ":regex is not a Regex" do
      assert_raise(Error, ":regex must be a Regex", fn ->
        Mold.prep!(%Str{regex: "meh"})
      end)
    end

    test ":one_of is not a list of strings" do
      assert_raise(Error, ":one_of must be a non-empty list of strings", fn ->
        Mold.prep!(%Str{one_of: "meh"})
      end)
    end

    test ":one_of_ci is not a list of strings" do
      assert_raise(Error, ":one_of_ci must be a non-empty list of strings", fn ->
        Mold.prep!(%Str{one_of_ci: "meh"})
      end)
    end

    test ":min is not a positive integer" do
      assert_raise(Error, ":min must be a positive integer", fn ->
        Mold.prep!(%Str{min: 0})
      end)
    end

    test ":max is not a positive integer" do
      assert_raise(Error, ":max must be a positive integer", fn ->
        Mold.prep!(%Str{max: 0})
      end)
    end

    test ":max is less than min" do
      assert_raise(Error, ":max must be greater than or equal to :min", fn ->
        Mold.prep!(%Str{max: 1, min: 2})
      end)
    end

    test "using both :one_of and :one_of_ci" do
      assert_raise(Error, "cannot use both :one_of and :one_of_ci", fn ->
        Mold.prep!(%Str{one_of: ["foo", "bar"], one_of_ci: ["pooh", "bear"]})
      end)
    end

    test "using both :one_of and :regex" do
      assert_raise(Error, "cannot use both :regex and :one_of", fn ->
        Mold.prep!(%Str{one_of: ["foo", "bar"], regex: ~r/^(foo|bar)$/})
      end)
    end

    test "using both :one_of_ci and :regex" do
      assert_raise(Error, "cannot use both :regex and :one_of_ci", fn ->
        Mold.prep!(%Str{one_of_ci: ["foo", "bar"], regex: ~r/^(foo|bar)$/})
      end)
    end

    test "using both min/max and an regex/one_of/one_of_ci" do
      assert_raise(Error, "cannot use both :regex and :min", fn ->
        Mold.prep!(%Str{min: 5, regex: ~r/^(foo|bar)$/})
      end)

      assert_raise(Error, "cannot use both :one_of and :min", fn ->
        Mold.prep!(%Str{min: 5, one_of: ["fool", "bart"]})
      end)

      assert_raise(Error, "cannot use both :one_of_ci and :max", fn ->
        Mold.prep!(%Str{max: 5, one_of_ci: ["fool", "bart"]})
      end)
    end
  end

  describe "Mold.prep!/1 a valid Int" do
    test "adds a default error message" do
      assert %Str{error_message: "must be a string"} = Mold.prep!(%Str{})
      assert %Str{error_message: "if not nil, must be a string"} = Mold.prep!(%Str{nil_ok?: true})

      assert %Str{
               error_message:
                 "must be one of these strings (with matching case): \"Simon\", \"Garfunkel\""
             } = Mold.prep!(%Str{one_of: ["Simon", "Garfunkel"]})

      assert %Str{
               error_message:
                 "must be one of these strings (case doesn't have to match): \"simon\", \"garfunkel\""
             } = Mold.prep!(%Str{one_of_ci: ["Simon", "Garfunkel"]})

      assert %Str{error_message: "must be a string matching the regex ~r/^\\d+$/"} =
               Mold.prep!(%Str{regex: ~r/^\d+$/})

      assert %Str{error_message: "must be a string with at least 5 characters"} =
               Mold.prep!(%Str{min: 5})

      assert %Str{error_message: "must be a string with at most 10 characters"} =
               Mold.prep!(%Str{max: 10})

      assert %Str{error_message: "must be a string with at least 5 and at most 10 characters"} =
               Mold.prep!(%Str{min: 5, max: 10})
    end

    test "accepts an error message" do
      assert %Str{error_message: "wrong"} = Mold.prep!(%Str{error_message: "wrong"})
    end
  end

  describe "Mold.exam using Str" do
    test "Error if the mold isn't prepped" do
      unprepped = %Str{}

      assert_raise(
        Error,
        "you must call Mold.prep/1 on the mold before calling Mold.exam/2",
        fn ->
          Mold.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_mold = Mold.prep!(%Str{nil_ok?: true})
      nil_not_ok_mold = Mold.prep!(%Str{error_message: "wrong"})

      :ok = Mold.exam(nil_ok_mold, nil)
      {:error, "wrong"} = Mold.exam(nil_not_ok_mold, nil)
    end

    test "fail if not a string" do
      mold = Mold.prep!(%Str{error_message: "wrong"})
      assert :ok = Mold.exam(mold, "yes")
      assert :ok = Mold.exam(mold, "")

      [1, true, %{}, Decimal.new(1)]
      |> Enum.each(&assert {:error, "wrong"} = Mold.exam(mold, &1))
    end

    test "takes an :but function" do
      mold = Mold.prep!(%Str{error_message: "wrong", but: &(&1 == String.reverse(&1))})

      :ok = Mold.exam(mold, "able was i ere i saw elba")
      {:error, "wrong"} = Mold.exam(mold, "anagram")
    end

    test "Error if :but doesn't return a boolean" do
      mold = Mold.prep!(%Str{error_message: "wrong", but: fn _ -> :poo end})

      assert_raise(Error, ":but must return a boolean, but it returned :poo", fn ->
        Mold.exam(mold, "pow")
      end)
    end

    test "checks :regex" do
      mold = Mold.prep!(%Str{error_message: "wrong", regex: ~r/^\d+$/})
      assert :ok = Mold.exam(mold, "123")
      assert {:error, "wrong"} = Mold.exam(mold, "1 2 3")
    end

    test "checks :one_of" do
      mold = Mold.prep!(%Str{error_message: "wrong", one_of: ["Paul", "Art"]})
      assert :ok = Mold.exam(mold, "Art")
      assert {:error, "wrong"} = Mold.exam(mold, "art")
      assert {:error, "wrong"} = Mold.exam(mold, "steve")
    end

    test "checks :one_of_ci" do
      mold = Mold.prep!(%Str{error_message: "wrong", one_of_ci: ["Paul", "Art"]})
      assert :ok = Mold.exam(mold, "Art")
      assert :ok = Mold.exam(mold, "art")
      assert {:error, "wrong"} = Mold.exam(mold, "steve")
    end

    test "checks :min" do
      mold = Mold.prep!(%Str{error_message: "wrong", min: 4})
      assert :ok = Mold.exam(mold, "12345")
      assert :ok = Mold.exam(mold, "1234")
      assert {:error, "wrong"} = Mold.exam(mold, "123")
    end

    test "checks :max" do
      mold = Mold.prep!(%Str{error_message: "wrong", max: 4})
      assert {:error, "wrong"} = Mold.exam(mold, "12345")
      assert :ok = Mold.exam(mold, "1234")
      assert :ok = Mold.exam(mold, "123")
    end

    test "checks both :min and :max" do
      mold = Mold.prep!(%Str{error_message: "wrong", min: 3, max: 4})
      assert {:error, "wrong"} = Mold.exam(mold, "12345")
      assert :ok = Mold.exam(mold, "1234")
      assert :ok = Mold.exam(mold, "123")
      assert {:error, "wrong"} = Mold.exam(mold, "12")
    end
  end
end
