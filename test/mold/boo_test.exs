defmodule Mold.BooTest do
  use ExUnit.Case

  alias Mold.Boo
  alias Mold.Error

  describe "Mold.prep! a Boo" do
    test "Error if nil_ok? not a boolean" do
      assert_raise(Error, ":nil_ok? must be a boolean", fn ->
        Mold.prep!(%Boo{nil_ok?: "yuh"})
      end)
    end

    test "Error if :but not a arity-1 function" do
      assert_raise(Error, ":but must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Boo{but: &(&1 + &2)})
      end)
    end

    test "adds the default error message" do
      assert %Boo{error_message: "must be a boolean"} = Mold.prep!(%Boo{})
    end

    test "can use custom error message" do
      assert %Boo{error_message: "wrong"} = Mold.prep!(%Boo{error_message: "wrong"})
    end
  end

  describe "Mold.exam using Boo" do
    test "Error if the mold isn't prepped" do
      unprepped = %Boo{}

      assert_raise(
        Error,
        "you must call Mold.prep/1 on the mold before calling Mold.exam/2",
        fn ->
          Mold.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_mold = Mold.prep!(%Boo{nil_ok?: true})
      nil_not_ok_mold = Mold.prep!(%Boo{error_message: "wrong"})

      :ok = Mold.exam(nil_ok_mold, nil)
      {:error, "wrong"} = Mold.exam(nil_not_ok_mold, nil)
    end

    test "only allows booleans" do
      mold = Mold.prep!(%Boo{error_message: "wrong"})

      :ok = Mold.exam(mold, true)
      :ok = Mold.exam(mold, false)
      {:error, "wrong"} = Mold.exam(mold, "no")
    end

    test "can use a mold with an :but function" do
      # why you'd do this, who knows?
      mold = Mold.prep!(%Boo{error_message: "wrong", but: &(&1 == true)})

      :ok = Mold.exam(mold, true)
      {:error, "wrong"} = Mold.exam(mold, "false")
    end

    test "Error if :but doesn't return a boolean" do
      mold = Mold.prep!(%Boo{error_message: "wrong", but: fn _ -> :poo end})

      assert_raise(Error, ":but must return a boolean, but it returned :poo", fn ->
        Mold.exam(mold, true)
      end)
    end
  end
end
