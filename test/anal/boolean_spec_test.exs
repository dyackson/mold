defmodule Anal.BoolSpecTest do
  alias Anal.BoolSpec
  alias Anal.SpecError

  use ExUnit.Case

  describe "Anal.prep! a BoolSpec" do
    test "SpecError if nil_ok? not a boolean" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%BoolSpec{nil_ok?: "yuh"})
      end)
    end

    test "SpecError if :also not a arity-1 function" do
      assert_raise(SpecError, ":also must be an arity-1 function", fn ->
        Anal.prep!(%BoolSpec{also: &(&1 + &2)})
      end)
    end

    test "adds the default error message" do
      assert %{error_message: "must be a boolean"} = Anal.prep!(%BoolSpec{})
    end

    test "uses provieded error message" do
      assert %{error_message: "dammit"} = Anal.prep!(%BoolSpec{error_message: "dammit"})
    end
  end

  describe "Anal.exam with BoolSpec" do
    test "SpecError if the spec isn't prepped" do
      unprepped = %BoolSpec{}

      assert_raise(
        SpecError,
        "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
        fn ->
          Anal.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_spec = Anal.prep!(%BoolSpec{nil_ok?: true})
      nil_not_ok_spec = Anal.prep!(%BoolSpec{error_message: "dammit"})

      :ok = Anal.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
    end

    test "only allows booleans" do
      spec = Anal.prep!(%BoolSpec{error_message: "dammit"})

      :ok = Anal.exam(spec, true)
      :ok = Anal.exam(spec, false)
      {:error, "dammit"} = Anal.exam(spec, "no")
    end

    test "can use a spec with an :also function" do
      # why you'd do this, who knows?
      spec = Anal.prep!(%BoolSpec{error_message: "dammit", also: &(&1 == true)})

      :ok = Anal.exam(spec, true)
      {:error, "dammit"} = Anal.exam(spec, "false")
    end
  end
end
