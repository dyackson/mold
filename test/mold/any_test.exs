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

    test "Error if :also not a arity-1 function" do
      assert_raise(Error, ":also must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Any{also: &(&1 + &2)})
      end)
    end

    test "adds the default error message" do
      assert %Any{error_message: "must be something"} = Mold.prep!(%Any{})
    end

    test "can use custom error message" do
      assert %Any{error_message: "dammit"} = Mold.prep!(%Any{error_message: "dammit"})
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
      nil_not_ok_mold = Mold.prep!(%Any{error_message: "dammit"})

      :ok = Mold.exam(nil_ok_mold, nil)
      {:error, "dammit"} = Mold.exam(nil_not_ok_mold, nil)
    end

    test "allows anything" do
      mold = Mold.prep!(%Any{error_message: "dammit"})

      :ok = Mold.exam(mold, true)
      :ok = Mold.exam(mold, "yay")
      :ok = Mold.exam(mold, %{"hi" => "mom"})
    end

    test "can use a mold with an :also function" do
      mold = Mold.prep!(%Any{error_message: "dammit", also: &(&1 != "")})

      :ok = Mold.exam(mold, "x")
      {:error, "dammit"} = Mold.exam(mold, "")
    end

    test "Error if :also doesn't return a boolean" do
      mold = Mold.prep!(%Any{error_message: "dammit", also: fn _ -> :woops end})

      assert_raise(Error, ":also must return a boolean, but it returned :woops", fn ->
        Mold.exam(mold, true)
      end)
    end
  end
end
