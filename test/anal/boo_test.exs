defmodule Anal.BooTest do
  use ExUnit.Case

  alias Anal.Boo
  alias Anal.SpecError

  describe "Anal.prep! a Boo" do
    test "SpecError if nil_ok? not a boolean" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Boo{nil_ok?: "yuh"})
      end)
    end

    test "SpecError if :also not a arity-1 function" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Anal.prep!(%Boo{also: &(&1 + &2)})
      end)
    end

    test "adds the default error message" do
      assert %Boo{error_message: "must be a boolean"} = Anal.prep!(%Boo{})
    end

    test "can use custom error message" do
      assert %Boo{error_message: "dammit"} = Anal.prep!(%Boo{error_message: "dammit"})
    end
  end

  describe "Anal.exam using Boo" do
    test "SpecError if the spec isn't prepped" do
      unprepped = %Boo{}

      assert_raise(
        SpecError,
        "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
        fn ->
          Anal.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_spec = Anal.prep!(%Boo{nil_ok?: true})
      nil_not_ok_spec = Anal.prep!(%Boo{error_message: "dammit"})

      :ok = Anal.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
    end

    test "only allows booleans" do
      spec = Anal.prep!(%Boo{error_message: "dammit"})

      :ok = Anal.exam(spec, true)
      :ok = Anal.exam(spec, false)
      {:error, "dammit"} = Anal.exam(spec, "no")
    end

    test "can use a spec with an :also function" do
      # why you'd do this, who knows?
      spec = Anal.prep!(%Boo{error_message: "dammit", also: &(&1 == true)})

      :ok = Anal.exam(spec, true)
      {:error, "dammit"} = Anal.exam(spec, "false")
    end

    test "SpecError if :also doesn't return a boolean" do
      spec = Anal.prep!(%Boo{error_message: "dammit", also: fn _ -> :some_shit end})

      assert_raise(SpecError, ":also must return a boolean, but it returned :some_shit", fn ->
        Anal.exam(spec, true)
      end)
    end
  end
end
