defmodule Mold.LstTest do
  alias Mold.Error
  alias Mold.Lst
  alias Mold.Str

  use ExUnit.Case

  describe "Mold.prep! a Lst raises a Error when the spec has bad" do
    test "nil_ok?" do
      assert_raise(Error, ":nil_ok? must be a boolean", fn ->
        Mold.prep!(%Lst{nil_ok?: "yuh"})
      end)
    end

    test ":also" do
      assert_raise(Error, ":also must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Lst{also: &(&1 + &2)})
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
      assert %Lst{error_message: "dammit"} = Mold.prep!(%Lst{of: %Str{}, error_message: "dammit"})
    end
  end

  describe "Mold.exam a Lst" do
    test "Error if the spec isn't prepped" do
      assert_raise(
        Error,
        "you must call Mold.prep/1 on the spec before calling Mold.exam/2",
        fn ->
          Mold.exam(%Lst{}, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_not_ok_spec = Mold.prep!(%Lst{of: %Str{}, error_message: "dammit"})
      nil_ok_spec = %Lst{nil_not_ok_spec | nil_ok?: true}

      :ok = Mold.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Mold.exam(nil_not_ok_spec, nil)
    end

    test "error if not a list" do
      spec = Mold.prep!(%Lst{of: %Str{}, error_message: "dammit"})

      {:error, "dammit"} = Mold.exam(spec, 5)
      {:error, "dammit"} = Mold.exam(spec, %{})
      {:error, "dammit"} = Mold.exam(spec, "foo")
    end

    test ":min_length" do
      spec = Mold.prep!(%Lst{of: %Str{}, min_length: 2, error_message: "dammit"})

      :ok = Mold.exam(spec, ["foo", "bar"])
      :ok = Mold.exam(spec, ["foo", "bar", "deez"])
      {:error, "dammit"} = Mold.exam(spec, ["foo"])
    end

    test ":max_length" do
      spec = Mold.prep!(%Lst{of: %Str{}, max_length: 3, error_message: "dammit"})

      :ok = Mold.exam(spec, ["foo", "bar"])
      :ok = Mold.exam(spec, ["foo", "bar", "deez"])
      {:error, "dammit"} = Mold.exam(spec, ["foo", "bar", "deez", "nuts"])
    end

    test ":of violations" do
      spec = Mold.prep!(%Lst{of: %Str{error_message: "bad string"}, error_message: "dammit"})

      {:error, %{0 => "bad string", 2 => "bad string"}} = Mold.exam(spec, [1, "bar", true])
    end

    test ":also" do
      spec =
        Mold.prep!(%Lst{of: %Str{}, also: &(rem(length(&1), 2) == 0), error_message: "dammit"})

      :ok = Mold.exam(spec, ["foo", "bar"])
      :ok = Mold.exam(spec, ["foo", "bar", "nuf", "sed"])
      {:error, "dammit"} = Mold.exam(spec, ["foo", "bar", "nuf"])
    end
  end
end
