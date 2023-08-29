defmodule Anal.DicTest do
  alias Anal.SpecError
  alias Anal.Dic
  alias Anal.Str
  alias Anal.Int

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
      spec = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(SpecError, ":min_size must be a non-negative integer", fn ->
        Anal.prep!(%{spec | min_size: -1})
      end)

      assert_raise(SpecError, ":min_size must be a non-negative integer", fn ->
        Anal.prep!(%{spec | min_size: "1"})
      end)

      assert %Dic{} = Anal.prep!(%{spec | min_size: 0})
    end

    test ":max_size" do
      spec = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(SpecError, ":max_size must be a positive integer", fn ->
        Anal.prep!(%{spec | max_size: 0})
      end)

      assert_raise(SpecError, ":max_size must be a positive integer", fn ->
        Anal.prep!(%{spec | max_size: "5"})
      end)

      assert %Dic{} = Anal.prep!(%{spec | max_size: 5})
    end

    test ":min_size - :max_size combo" do
      spec = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(SpecError, ":min_size must be less than or equal to :max_size", fn ->
        Anal.prep!(%{spec | min_size: 3, max_size: 2})
      end)

      assert %Dic{} = Anal.prep!(%{spec | min_size: 2, max_size: 2})
      assert %Dic{} = Anal.prep!(%{spec | min_size: 2, max_size: 3})
    end
  end

  describe "Anal.prep!/1 a valid Dic" do
    test "adds a default error message" do
      spec = %Dic{keys: %Str{}, vals: %Int{}}

      assert Anal.prep!(spec).error_message ==
               "must be a mapping where each key must be a string, and each value must be an integer"

      assert Anal.prep!(%{spec | min_size: 5}).error_message ==
               "must be a mapping with at least 5 entries, where each key must be a string, and each value must be an integer"

      assert Anal.prep!(%{spec | max_size: 5}).error_message ==
               "must be a mapping with at most 5 entries, where each key must be a string, and each value must be an integer"

      assert Anal.prep!(%{spec | min_size: 2, max_size: 5}).error_message ==
               "must be a mapping with at least 2 and at most 5 entries, where each key must be a string, and each value must be an integer"
    end

    test "accepts an error message" do
      spec = %Dic{keys: %Str{}, vals: %Int{}, error_message: "dammit"}

      assert Anal.prep!(spec).error_message == "dammit"
    end
  end

  describe "Anal.exam a Dic" do
    test "SpecError if the spec isn't prepped" do
      assert_raise(
        SpecError,
        "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
        fn ->
          Anal.exam(%Dic{}, %{"foo" => 1})
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_not_ok_spec = Anal.prep!(%Dic{keys: %Str{}, vals: %Int{}, error_message: "dammit"})
      nil_ok_spec = %{nil_not_ok_spec | nil_ok?: true}

      :ok = Anal.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
    end

    test "error if not a map" do
      spec = Anal.prep!(%Dic{keys: %Str{}, vals: %Int{}, error_message: "dammit"})

      {:error, "dammit"} = Anal.exam(spec, 5)
      {:error, "dammit"} = Anal.exam(spec, [])
      {:error, "dammit"} = Anal.exam(spec, "foo")

      :ok = Anal.exam(spec, %{})
      :ok = Anal.exam(spec, %{"foo" => 5, "bar" => 9})
    end

    test ":min_size" do
      spec = Anal.prep!(%Dic{keys: %Str{}, vals: %Int{}, min_size: 2, error_message: "dammit"})

      :ok = Anal.exam(spec, %{"foo" => 5, "bar" => 9})
      :ok = Anal.exam(spec, %{"foo" => 5, "bar" => 9, "fud" => 8})
      {:error, "dammit"} = Anal.exam(spec, %{"foo" => 5})
    end

    test ":max_size" do
      spec = Anal.prep!(%Dic{keys: %Str{}, vals: %Int{}, max_size: 2, error_message: "dammit"})

      :ok = Anal.exam(spec, %{"foo" => 5})
      :ok = Anal.exam(spec, %{"foo" => 5, "bar" => 9})
      {:error, "dammit"} = Anal.exam(spec, %{"foo" => 5, "bar" => 2, "elf" => 8})
    end

    test ":bad keys" do
      spec =
        Anal.prep!(%Dic{
          keys: %Str{regex: ~r/^[0-f]+$/, error_message: "must be a hex string"},
          vals: %Int{}
        })

      assert :ok = Anal.exam(spec, %{"09af" => 3, "1dd" => 5, "1a9" => 2})

      assert {:error,
              %{"__key_errors__" => %{keys: [-1, "bar"], message: "must be a hex string"}}} =
               Anal.exam(spec, %{"09af" => 3, -1 => 5, "bar" => 2})
    end

    test ":bad vals" do
      spec = Anal.prep!(%Dic{keys: %Str{}, vals: %Int{}})

      assert :ok = Anal.exam(spec, %{"foo" => 3, "bar" => 2, "nut" => 4})

      assert {:error, %{"bar" => "must be an integer", "nut" => "must be an integer"}} =
               Anal.exam(spec, %{"foo" => 3, "bar" => true, "nut" => "wow"})
    end
  end

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
