defmodule Mold.LstTest do
  alias Mold.Error
  alias Mold.Lst
  alias Mold.Str

  use ExUnit.Case

  describe "Mold.prep! a Lst raises a Error when the mold has bad" do
    test "nil_ok?" do
      assert_raise(Error, ":nil_ok? must be a boolean", fn ->
        Mold.prep!(%Lst{nil_ok?: "yuh"})
      end)
    end

    test ":but" do
      assert_raise(Error, ":but must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Lst{but: &(&1 + &2)})
      end)
    end

    test ":min_length" do
      assert_raise(Error, ":min_length must be a non-negative integer", fn ->
        Mold.prep!(%Lst{min_length: -1})
      end)

      assert_raise(Error, ":min_length must be a non-negative integer", fn ->
        Mold.prep!(%Lst{min_length: "9"})
      end)
    end

    test ":max_length" do
      assert_raise(Error, ":max_length must be a positive integer", fn ->
        Mold.prep!(%Lst{max_length: 0})
      end)

      assert_raise(Error, ":max_length must be a positive integer", fn ->
        Mold.prep!(%Lst{max_length: "5"})
      end)
    end

    test ":min_length - :max_length combo" do
      assert_raise(Error, ":min_length must be less than or equal to :max_length", fn ->
        Mold.prep!(%Lst{min_length: 5, max_length: 4})
      end)
    end

    test ":of" do
      assert_raise(Error, ":of is required and must implement the Mold protocol", fn ->
        Mold.prep!(%Lst{of: "farts"})
      end)
    end
  end

  describe "Mold.prep!/1 a valid Lst" do
    test "adds a default error message" do
      assert %Lst{error_message: "must be a list in which each element must be a string"} =
               Mold.prep!(%Lst{of: %Str{}})

      assert %Lst{
               error_message: "if not nil, must be a list in which each element must be a string"
             } =
               Mold.prep!(%Lst{of: %Str{}, nil_ok?: true})

      assert %Lst{
               error_message:
                 "must be a list with at least 5 elements, each of which must be a string"
             } = Mold.prep!(%Lst{of: %Str{}, min_length: 5})

      assert %Lst{
               error_message:
                 "must be a list with at most 5 elements, each of which must be a string"
             } = Mold.prep!(%Lst{of: %Str{}, max_length: 5})

      assert %Lst{
               error_message:
                 "must be a list with at least 1 and at most 5 elements, each of which must be a string"
             } = Mold.prep!(%Lst{of: %Str{}, min_length: 1, max_length: 5})
    end

    test "accepts an error message" do
      assert %Lst{error_message: "wrong"} = Mold.prep!(%Lst{of: %Str{}, error_message: "wrong"})
    end
  end

  describe "Mold.exam a Lst" do
    test "Error if the mold isn't prepped" do
      assert_raise(
        Error,
        "you must call Mold.prep/1 on the mold before calling Mold.exam/2",
        fn ->
          Mold.exam(%Lst{}, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_not_ok_mold = Mold.prep!(%Lst{of: %Str{}, error_message: "wrong"})
      nil_ok_mold = %Lst{nil_not_ok_mold | nil_ok?: true}

      :ok = Mold.exam(nil_ok_mold, nil)
      {:error, "wrong"} = Mold.exam(nil_not_ok_mold, nil)
    end

    test "error if not a list" do
      mold = Mold.prep!(%Lst{of: %Str{}, error_message: "wrong"})

      {:error, "wrong"} = Mold.exam(mold, 5)
      {:error, "wrong"} = Mold.exam(mold, %{})
      {:error, "wrong"} = Mold.exam(mold, "foo")
    end

    test ":min_length" do
      mold = Mold.prep!(%Lst{of: %Str{}, min_length: 2, error_message: "wrong"})

      :ok = Mold.exam(mold, ["foo", "bar"])
      :ok = Mold.exam(mold, ["foo", "bar", "deez"])
      {:error, "wrong"} = Mold.exam(mold, ["foo"])
    end

    test ":max_length" do
      mold = Mold.prep!(%Lst{of: %Str{}, max_length: 3, error_message: "wrong"})

      :ok = Mold.exam(mold, ["foo", "bar"])
      :ok = Mold.exam(mold, ["foo", "bar", "deez"])
      {:error, "wrong"} = Mold.exam(mold, ["foo", "bar", "deez", "nuts"])
    end

    test ":of violations" do
      mold = Mold.prep!(%Lst{of: %Str{error_message: "bad string"}, error_message: "wrong"})

      {:error, %{0 => "bad string", 2 => "bad string"}} = Mold.exam(mold, [1, "bar", true])
    end

    test ":but" do
      mold =
        Mold.prep!(%Lst{of: %Str{}, but: &(rem(length(&1), 2) == 0), error_message: "wrong"})

      :ok = Mold.exam(mold, ["foo", "bar"])
      :ok = Mold.exam(mold, ["foo", "bar", "nuf", "sed"])
      {:error, "wrong"} = Mold.exam(mold, ["foo", "bar", "nuf"])
    end
  end
end
