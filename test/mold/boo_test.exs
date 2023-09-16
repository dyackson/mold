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

    test "Error if :also not a arity-1 function" do
      assert_raise(Error, ":also must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Boo{also: &(&1 + &2)})
      end)
    end

    test "adds the default error message" do
      assert %Boo{error_message: "must be a boolean"} = Mold.prep!(%Boo{})
    end

    test "can use custom error message" do
      assert %Boo{error_message: "dammit"} = Mold.prep!(%Boo{error_message: "dammit"})
    end
  end

  describe "Mold.exam using Boo" do
    test "Error if the spec isn't prepped" do
      unprepped = %Boo{}

      assert_raise(
        Error,
        "you must call Mold.prep/1 on the spec before calling Mold.exam/2",
        fn ->
          Mold.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_spec = Mold.prep!(%Boo{nil_ok?: true})
      nil_not_ok_spec = Mold.prep!(%Boo{error_message: "dammit"})

      :ok = Mold.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Mold.exam(nil_not_ok_spec, nil)
    end

    test "only allows booleans" do
      spec = Mold.prep!(%Boo{error_message: "dammit"})

      :ok = Mold.exam(spec, true)
      :ok = Mold.exam(spec, false)
      {:error, "dammit"} = Mold.exam(spec, "no")
    end

    test "can use a spec with an :also function" do
      # why you'd do this, who knows?
      spec = Mold.prep!(%Boo{error_message: "dammit", also: &(&1 == true)})

      :ok = Mold.exam(spec, true)
      {:error, "dammit"} = Mold.exam(spec, "false")
    end

    test "Error if :also doesn't return a boolean" do
      spec = Mold.prep!(%Boo{error_message: "dammit", also: fn _ -> :some_shit end})

      assert_raise(Error, ":also must return a boolean, but it returned :some_shit", fn ->
        Mold.exam(spec, true)
      end)
    end
  end
end
