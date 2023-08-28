defmodule Anal.DicTest do
  alias Anal.SpecError
  alias Anal.Dic
  alias Anal.Str

  use ExUnit.Case

  describe "Anal.prep! a Dic raises a SpecError when the spec has bad" do
    test "nil_ok?" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Dic{nil_ok?: "yuh"})
      end)
    end

    test ":also" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Anal.prep!(%Dic{also: &(&1 + &2)})
      end)
    end

    test ":keys" do
      msg = ":keys must be an %Anal.Str{}, %Anal.Int{}, or %Anal.Dec{}"

      assert_raise(SpecError, msg, fn ->
        Anal.prep!(%Dic{})
      end)

      assert_raise(SpecError, msg, fn ->
        Anal.prep!(%Dic{keys: %{}})
      end)

      assert_raise(SpecError, msg, fn ->
        Anal.prep!(%Dic{keys: %Anal.Boo{}})
      end)
    end

    test ":vals" do
      msg = ":vals must implement the Anal protocol"

      assert_raise(SpecError, msg, fn ->
        Anal.prep!(%Dic{keys: %Anal.Str{}})
      end)

      assert_raise(SpecError, msg, fn ->
        Anal.prep!(%Dic{keys: %Anal.Str{}, vals: %{}})
      end)
    end

    test ":min_size" do
      spec = %Dic{keys: %Anal.Str{}, vals: %Anal.Int{}}

      assert_raise(SpecError, ":min_size must be a non-negative integer", fn ->
        Anal.prep!(%{spec | min_size: -1})
      end)

      assert_raise(SpecError, ":min_size must be a non-negative integer", fn ->
        Anal.prep!(%{spec | min_size: "1"})
      end)

      assert %Dic{} = Anal.prep!(%{spec | min_size: 0})
    end

    test ":max_size" do
      spec = %Dic{keys: %Anal.Str{}, vals: %Anal.Int{}}

      assert_raise(SpecError, ":max_size must be a positive integer", fn ->
        Anal.prep!(%{spec | max_size: 0})
      end)

      assert_raise(SpecError, ":max_size must be a positive integer", fn ->
        Anal.prep!(%{spec | max_size: "5"})
      end)

      assert %Dic{} = Anal.prep!(%{spec | max_size: 5})
    end

    test ":min_size - :max_size combo" do
      spec = %Dic{keys: %Anal.Str{}, vals: %Anal.Int{}}

      assert_raise(SpecError, ":min_size must be less than or equal to :max_size", fn ->
        Anal.prep!(%{spec | min_size: 3, max_size: 2})
      end)

      assert %Dic{} = Anal.prep!(%{spec | min_size: 2, max_size: 2})
      assert %Dic{} = Anal.prep!(%{spec | min_size: 2, max_size: 3})
    end
  end

  # describe "Anal.prep!/1 a valid Dic" do
  #   test "adds a default error message" do
  #     assert %Dic{error_message: "must be a list in which each element must be a string"} =
  #              Anal.prep!(%Dic{of: %Str{}})

  #     assert %Dic{
  #              error_message:
  #                "must be a list with at least 5 elements, each of which must be a string"
  #            } = Anal.prep!(%Dic{of: %Str{}, min_size: 5})

  #     assert %Dic{
  #              error_message:
  #                "must be a list with at most 5 elements, each of which must be a string"
  #            } = Anal.prep!(%Dic{of: %Str{}, max_size: 5})

  #     assert %Dic{
  #              error_message:
  #                "must be a list with at least 1 and at most 5 elements, each of which must be a string"
  #            } = Anal.prep!(%Dic{of: %Str{}, min_size: 1, max_size: 5})
  #   end

  #   test "accepts an error message" do
  #     assert %Dic{error_message: "dammit"} = Anal.prep!(%Dic{of: %Str{}, error_message: "dammit"})
  #   end
  # end

  # describe "Anal.exam a Dic" do
  #   test "SpecError if the spec isn't prepped" do
  #     assert_raise(
  #       SpecError,
  #       "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
  #       fn ->
  #         Anal.exam(%Dic{}, true)
  #       end
  #     )
  #   end

  #   test "allows nil iff nil_ok?" do
  #     nil_not_ok_spec = Anal.prep!(%Dic{of: %Str{}, error_message: "dammit"})
  #     nil_ok_spec = %Dic{nil_not_ok_spec | nil_ok?: true}

  #     :ok = Anal.exam(nil_ok_spec, nil)
  #     {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
  #   end

  #   test "error if not a list" do
  #     spec = Anal.prep!(%Dic{of: %Str{}, error_message: "dammit"})

  #     {:error, "dammit"} = Anal.exam(spec, 5)
  #     {:error, "dammit"} = Anal.exam(spec, %{})
  #     {:error, "dammit"} = Anal.exam(spec, "foo")
  #   end

  #   test ":min_size" do
  #     spec = Anal.prep!(%Dic{of: %Str{}, min_size: 2, error_message: "dammit"})

  #     :ok = Anal.exam(spec, ["foo", "bar"])
  #     :ok = Anal.exam(spec, ["foo", "bar", "deez"])
  #     {:error, "dammit"} = Anal.exam(spec, ["foo"])
  #   end

  #   test ":max_size" do
  #     spec = Anal.prep!(%Dic{of: %Str{}, max_size: 3, error_message: "dammit"})

  #     :ok = Anal.exam(spec, ["foo", "bar"])
  #     :ok = Anal.exam(spec, ["foo", "bar", "deez"])
  #     {:error, "dammit"} = Anal.exam(spec, ["foo", "bar", "deez", "nuts"])
  #   end

  #   test ":of violations" do
  #     spec = Anal.prep!(%Dic{of: %Str{error_message: "bad string"}, error_message: "dammit"})

  #     {:error, %{0 => "bad string", 2 => "bad string"}} = Anal.exam(spec, [1, "bar", true])
  #   end

  #   test ":also" do
  #     spec =
  #       Anal.prep!(%Dic{of: %Str{}, also: &(rem(length(&1), 2) == 0), error_message: "dammit"})

  #     :ok = Anal.exam(spec, ["foo", "bar"])
  #     :ok = Anal.exam(spec, ["foo", "bar", "nuf", "sed"])
  #     {:error, "dammit"} = Anal.exam(spec, ["foo", "bar", "nuf"])
  #   end
  # end
end
