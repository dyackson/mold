defmodule Mold.DicTest do
  alias Mold.Error
  alias Mold.Dic
  alias Mold.Str
  alias Mold.Int

  use ExUnit.Case

  describe "Mold.prep! a Dic raises a Error when the mold has bad" do
    test ":but" do
      assert_raise(Error, ":but must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Dic{but: &(&1 + &2)})
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

    test ":min" do
      mold = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(Error, ":min must be a non-negative integer", fn ->
        Mold.prep!(%{mold | min: -1})
      end)

      assert_raise(Error, ":min must be a non-negative integer", fn ->
        Mold.prep!(%{mold | min: "1"})
      end)

      assert %Dic{} = Mold.prep!(%{mold | min: 0})
    end

    test ":max" do
      mold = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(Error, ":max must be a positive integer", fn ->
        Mold.prep!(%{mold | max: 0})
      end)

      assert_raise(Error, ":max must be a positive integer", fn ->
        Mold.prep!(%{mold | max: "5"})
      end)

      assert %Dic{} = Mold.prep!(%{mold | max: 5})
    end

    test ":min - :max combo" do
      mold = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(Error, ":min must be less than or equal to :max", fn ->
        Mold.prep!(%{mold | min: 3, max: 2})
      end)

      assert %Dic{} = Mold.prep!(%{mold | min: 2, max: 2})
      assert %Dic{} = Mold.prep!(%{mold | min: 2, max: 3})
    end
  end

  describe "Mold.prep!/1 a valid Dic" do
    test "adds a default error message" do
      mold = %Dic{keys: %Str{}, vals: %Int{}}

      assert Mold.prep!(mold).error_message ==
               "must be a mapping where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{mold | nil_ok?: true}).error_message ==
               "if not nil, must be a mapping where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{mold | min: 5}).error_message ==
               "must be a mapping with at least 5 entries, where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{mold | max: 5}).error_message ==
               "must be a mapping with at most 5 entries, where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{mold | min: 2, max: 5}).error_message ==
               "must be a mapping with at least 2 and at most 5 entries, where each key must be a string, and each value must be an integer"
    end

    test "accepts an error message" do
      mold = %Dic{keys: %Str{}, vals: %Int{}, error_message: "wrong"}

      assert Mold.prep!(mold).error_message == "wrong"
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
      nil_not_ok_mold = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, error_message: "wrong"})
      nil_ok_mold = %{nil_not_ok_mold | nil_ok?: true}

      :ok = Mold.exam(nil_ok_mold, nil)
      {:error, "wrong"} = Mold.exam(nil_not_ok_mold, nil)
    end

    test "error if not a map" do
      mold = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, error_message: "wrong"})

      {:error, "wrong"} = Mold.exam(mold, 5)
      {:error, "wrong"} = Mold.exam(mold, [])
      {:error, "wrong"} = Mold.exam(mold, "foo")

      :ok = Mold.exam(mold, %{})
      :ok = Mold.exam(mold, %{"foo" => 5, "bar" => 9})
    end

    test ":min" do
      mold = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, min: 2, error_message: "wrong"})

      :ok = Mold.exam(mold, %{"foo" => 5, "bar" => 9})
      :ok = Mold.exam(mold, %{"foo" => 5, "bar" => 9, "fud" => 8})
      {:error, "wrong"} = Mold.exam(mold, %{"foo" => 5})
    end

    test ":max" do
      mold = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, max: 2, error_message: "wrong"})

      :ok = Mold.exam(mold, %{"foo" => 5})
      :ok = Mold.exam(mold, %{"foo" => 5, "bar" => 9})
      {:error, "wrong"} = Mold.exam(mold, %{"foo" => 5, "bar" => 2, "elf" => 8})
    end

    test ":bad keys" do
      mold =
        Mold.prep!(%Dic{
          keys: %Str{regex: ~r/^[0-f]+$/, error_message: "must be a hex string"},
          vals: %Int{}
        })

      assert :ok = Mold.exam(mold, %{"09af" => 3, "1dd" => 5, "1a9" => 2})

      assert {:error, %{__key_errors__: %{keys: [-1, "bar"], message: "must be a hex string"}}} =
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
