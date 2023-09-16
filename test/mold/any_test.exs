defmodule Mold.AnyTest do
  use ExUnit.Case

  alias Mold.Any
  alias Mold.Error

  describe "Mold.prep! an Any" do
    test "Error if nil_ok? not a boolean" do
      assert_raise(Error, ":nil_ok? must be a boolean", fn ->
        Mold.prep!(%Any{nil_ok?: "yuh"})
      end)
    end

    test "Error if :but not a arity-1 function" do
      assert_raise(Error, ":but must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Any{but: &(&1 + &2)})
      end)
    end

    test "adds the default error message" do
      assert %Any{error_message: "must not be nil"} = Mold.prep!(%Any{})
      assert %Any{error_message: "invalid"} = Mold.prep!(%Any{nil_ok?: true})
    end

    test "can use custom error message" do
      assert %Any{error_message: "wrong"} = Mold.prep!(%Any{error_message: "wrong"})
    end
  end

  describe "Mold.exam using Any" do
    test "Error if the mold isn't prepped" do
      unprepped = %Any{}

      assert_raise(
        Error,
        "you must call Mold.prep/1 on the mold before calling Mold.exam/2",
        fn ->
          Mold.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_mold = Mold.prep!(%Any{nil_ok?: true})
      nil_not_ok_mold = Mold.prep!(%Any{error_message: "wrong"})

      :ok = Mold.exam(nil_ok_mold, nil)
      {:error, "wrong"} = Mold.exam(nil_not_ok_mold, nil)
    end

    test "allows anything" do
      mold = Mold.prep!(%Any{error_message: "wrong"})

      :ok = Mold.exam(mold, true)
      :ok = Mold.exam(mold, "yay")
      :ok = Mold.exam(mold, %{"hi" => "mom"})
    end

    test "can use a mold with an :but function" do
      mold = Mold.prep!(%Any{error_message: "wrong", but: &(&1 != "")})

      :ok = Mold.exam(mold, "x")
      {:error, "wrong"} = Mold.exam(mold, "")
    end

    test "Error if :but doesn't return a boolean" do
      mold = Mold.prep!(%Any{error_message: "wrong", but: fn _ -> :poo end})

      assert_raise(Error, ":but must return a boolean, but it returned :poo", fn ->
        Mold.exam(mold, true)
      end)
    end
  end
end
