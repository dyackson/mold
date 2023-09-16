defmodule Mold.DicTest do
  alias Mold.Error
  alias Mold.Dic
  alias Mold.Str
  alias Mold.Int

  use ExUnit.Case

  describe "Mold.prep! a Dic raises a Error when the mold has bad" do
    test "nil_ok?" do
      assert_raise(Error, ":nil_ok? must be a boolean", fn ->
        Mold.prep!(%Dic{nil_ok?: "yuh"})
      end)
    end

    test ":also" do
      assert_raise(Error, ":also must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Dic{also: &(&1 + &2)})
      end)
    end

    test ":keys" do
      msg = ":keys must be an %Mold.Str{} or %Mold.Int{}"

      assert_raise(Error, msg, fn ->
        Mold.prep!(%Dic{})
      end)

      assert_raise(Error, msg, fn ->
        Mold.prep!(%Dic{keys: %{}})
      end)

      assert_raise(Error, msg, fn ->
        Mold.prep!(%Dic{keys: %Mold.Boo{}})
      end)

      assert %Dic{keys: %Str{}, vals: %Int{}}
      assert %Dic{keys: %Int{}, vals: %Int{}}
    end

    test ":vals" do
      msg = ":vals must implement the Mold protocol"

      assert_raise(Error, msg, fn ->
        Mold.prep!(%Dic{keys: %Mold.Str{}})
      end)

      assert_raise(Error, msg, fn ->
        Mold.prep!(%Dic{keys: %Mold.Str{}, vals: %{}})
      end)
    end

    test ":min_size" do
      mold = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(Error, ":min_size must be a non-negative integer", fn ->
        Mold.prep!(%{mold | min_size: -1})
      end)

      assert_raise(Error, ":min_size must be a non-negative integer", fn ->
        Mold.prep!(%{mold | min_size: "1"})
      end)

      assert %Dic{} = Mold.prep!(%{mold | min_size: 0})
    end

    test ":max_size" do
      mold = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(Error, ":max_size must be a positive integer", fn ->
        Mold.prep!(%{mold | max_size: 0})
      end)

      assert_raise(Error, ":max_size must be a positive integer", fn ->
        Mold.prep!(%{mold | max_size: "5"})
      end)

      assert %Dic{} = Mold.prep!(%{mold | max_size: 5})
    end

    test ":min_size - :max_size combo" do
      mold = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(Error, ":min_size must be less than or equal to :max_size", fn ->
        Mold.prep!(%{mold | min_size: 3, max_size: 2})
      end)

      assert %Dic{} = Mold.prep!(%{mold | min_size: 2, max_size: 2})
      assert %Dic{} = Mold.prep!(%{mold | min_size: 2, max_size: 3})
    end
  end

  describe "Mold.prep!/1 a valid Dic" do
    test "adds a default error message" do
      mold = %Dic{keys: %Str{}, vals: %Int{}}

      assert Mold.prep!(mold).error_message ==
               "must be a mapping where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{mold | min_size: 5}).error_message ==
               "must be a mapping with at least 5 entries, where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{mold | max_size: 5}).error_message ==
               "must be a mapping with at most 5 entries, where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{mold | min_size: 2, max_size: 5}).error_message ==
               "must be a mapping with at least 2 and at most 5 entries, where each key must be a string, and each value must be an integer"
    end

    test "accepts an error message" do
      mold = %Dic{keys: %Str{}, vals: %Int{}, error_message: "dammit"}

      assert Mold.prep!(mold).error_message == "dammit"
    end
  end

  describe "Mold.exam a Dic" do
    test "Error if the mold isn't prepped" do
      assert_raise(
        Error,
        "you must call Mold.prep/1 on the mold before calling Mold.exam/2",
        fn ->
          Mold.exam(%Dic{}, %{"foo" => 1})
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_not_ok_mold = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, error_message: "dammit"})
      nil_ok_mold = %{nil_not_ok_mold | nil_ok?: true}

      :ok = Mold.exam(nil_ok_mold, nil)
      {:error, "dammit"} = Mold.exam(nil_not_ok_mold, nil)
    end

    test "error if not a map" do
      mold = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, error_message: "dammit"})

      {:error, "dammit"} = Mold.exam(mold, 5)
      {:error, "dammit"} = Mold.exam(mold, [])
      {:error, "dammit"} = Mold.exam(mold, "foo")

      :ok = Mold.exam(mold, %{})
      :ok = Mold.exam(mold, %{"foo" => 5, "bar" => 9})
    end

    test ":min_size" do
      mold = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, min_size: 2, error_message: "dammit"})

      :ok = Mold.exam(mold, %{"foo" => 5, "bar" => 9})
      :ok = Mold.exam(mold, %{"foo" => 5, "bar" => 9, "fud" => 8})
      {:error, "dammit"} = Mold.exam(mold, %{"foo" => 5})
    end

    test ":max_size" do
      mold = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, max_size: 2, error_message: "dammit"})

      :ok = Mold.exam(mold, %{"foo" => 5})
      :ok = Mold.exam(mold, %{"foo" => 5, "bar" => 9})
      {:error, "dammit"} = Mold.exam(mold, %{"foo" => 5, "bar" => 2, "elf" => 8})
    end

    test ":bad keys" do
      mold =
        Mold.prep!(%Dic{
          keys: %Str{regex: ~r/^[0-f]+$/, error_message: "must be a hex string"},
          vals: %Int{}
        })

      assert :ok = Mold.exam(mold, %{"09af" => 3, "1dd" => 5, "1a9" => 2})

      assert {:error,
              %{"__key_errors__" => %{keys: [-1, "bar"], message: "must be a hex string"}}} =
               Mold.exam(mold, %{"09af" => 3, -1 => 5, "bar" => 2})
    end

    test ":bad vals" do
      mold = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}})

      assert :ok = Mold.exam(mold, %{"foo" => 3, "bar" => 2, "nut" => 4})

      assert {:error, %{"bar" => "must be an integer", "nut" => "must be an integer"}} =
               Mold.exam(mold, %{"foo" => 3, "bar" => true, "nut" => "wow"})
    end
  end
end
