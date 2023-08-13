defmodule Anal.LstTest do
  alias Anal.SpecError
  alias Anal.Lst
  alias Anal.Str

  use ExUnit.Case

  describe "Anal.prep! a Lst raises a SpecError when the spec has bad" do
    test "nil_ok?" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Lst{nil_ok?: "yuh"})
      end)
    end

    test ":also" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Anal.prep!(%Lst{also: &(&1 + &2)})
      end)
    end

    test ":min_length" do
      assert_raise(SpecError, ":min_length must be a non-negative integer", fn ->
        Anal.prep!(%Lst{min_length: -1})
      end)

      assert_raise(SpecError, ":min_length must be a non-negative integer", fn ->
        Anal.prep!(%Lst{min_length: "9"})
      end)
    end

    test ":max_length" do
      assert_raise(SpecError, ":max_length must be a positive integer", fn ->
        Anal.prep!(%Lst{max_length: 0})
      end)

      assert_raise(SpecError, ":max_length must be a positive integer", fn ->
        Anal.prep!(%Lst{max_length: "5"})
      end)
    end

    test ":min_length - :max_length combo" do
      assert_raise(SpecError, ":min_length must be less than or equal to :max_length", fn ->
        Anal.prep!(%Lst{min_length: 5, max_length: 4})
      end)
    end

    test ":of" do
      assert_raise(SpecError, ":of is required and must implement the Anal protocol", fn ->
        Anal.prep!(%Lst{of: "farts"})
      end)
    end
  end

  describe "Anal.prep!/1 a valid Lst" do
    test "adds a default error message" do
      assert %Lst{error_message: "must be a list in which each element must be a string"} =
               Anal.prep!(%Lst{of: %Str{}})

      assert %Lst{
               error_message:
                 "must be a list with at least 5 elements, each of which must be a string"
             } = Anal.prep!(%Lst{of: %Str{}, min_length: 5})

      assert %Lst{
               error_message:
                 "must be a list with at most 5 elements, each of which must be a string"
             } = Anal.prep!(%Lst{of: %Str{}, max_length: 5})

      assert %Lst{
               error_message:
                 "must be a list with at least 1 and at most 5 elements, each of which must be a string"
             } = Anal.prep!(%Lst{of: %Str{}, min_length: 1, max_length: 5})
    end

    test "accepts an error message" do
      assert %Lst{error_message: "dammit"} = Anal.prep!(%Lst{of: %Str{}, error_message: "dammit"})
    end
  end

  describe "Anal.exam a Lst" do
    test "SpecError if the spec isn't prepped" do
      assert_raise(
        SpecError,
        "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
        fn ->
          Anal.exam(%Lst{}, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_not_ok_spec = Anal.prep!(%Lst{of: %Str{}, error_message: "dammit"})
      nil_ok_spec = %Lst{nil_not_ok_spec | nil_ok?: true}

      :ok = Anal.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
    end

    test "error if not a list" do
      spec = Anal.prep!(%Lst{of: %Str{}, error_message: "dammit"})

      {:error, "dammit"} = Anal.exam(spec, 5)
      {:error, "dammit"} = Anal.exam(spec, %{})
      {:error, "dammit"} = Anal.exam(spec, "foo")
    end

    test ":min_length" do
      spec = Anal.prep!(%Lst{of: %Str{}, min_length: 2, error_message: "dammit"})

      :ok = Anal.exam(spec, ["foo", "bar"])
      :ok = Anal.exam(spec, ["foo", "bar", "deez"])
      {:error, "dammit"} = Anal.exam(spec, ["foo"])
    end

    test ":max_length" do
      spec = Anal.prep!(%Lst{of: %Str{}, max_length: 3, error_message: "dammit"})

      :ok = Anal.exam(spec, ["foo", "bar"])
      :ok = Anal.exam(spec, ["foo", "bar", "deez"])
      {:error, "dammit"} = Anal.exam(spec, ["foo", "bar", "deez", "nuts"])
    end

    test ":of violations" do
      spec = Anal.prep!(%Lst{of: %Str{error_message: "bad string"}, error_message: "dammit"})

      {:error, %{0 => "bad string", 2 => "bad string"}} = Anal.exam(spec, [1, "bar", true])
    end

    test ":also" do
      spec =
        Anal.prep!(%Lst{of: %Str{}, also: &(rem(length(&1), 2) == 0), error_message: "dammit"})

      :ok = Anal.exam(spec, ["foo", "bar"])
      :ok = Anal.exam(spec, ["foo", "bar", "nuf", "sed"])
      {:error, "dammit"} = Anal.exam(spec, ["foo", "bar", "nuf"])
    end
  end
end
