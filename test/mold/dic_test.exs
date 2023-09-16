defmodule Mold.DicTest do
  alias Mold.Error
  alias Mold.Dic
  alias Mold.Str
  alias Mold.Int

  use ExUnit.Case

  describe "Mold.prep! a Dic raises a Error when the spec has bad" do
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
      spec = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(Error, ":min_size must be a non-negative integer", fn ->
        Mold.prep!(%{spec | min_size: -1})
      end)

      assert_raise(Error, ":min_size must be a non-negative integer", fn ->
        Mold.prep!(%{spec | min_size: "1"})
      end)

      assert %Dic{} = Mold.prep!(%{spec | min_size: 0})
    end

    test ":max_size" do
      spec = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(Error, ":max_size must be a positive integer", fn ->
        Mold.prep!(%{spec | max_size: 0})
      end)

      assert_raise(Error, ":max_size must be a positive integer", fn ->
        Mold.prep!(%{spec | max_size: "5"})
      end)

      assert %Dic{} = Mold.prep!(%{spec | max_size: 5})
    end

    test ":min_size - :max_size combo" do
      spec = %Dic{keys: %Str{}, vals: %Int{}}

      assert_raise(Error, ":min_size must be less than or equal to :max_size", fn ->
        Mold.prep!(%{spec | min_size: 3, max_size: 2})
      end)

      assert %Dic{} = Mold.prep!(%{spec | min_size: 2, max_size: 2})
      assert %Dic{} = Mold.prep!(%{spec | min_size: 2, max_size: 3})
    end
  end

  describe "Mold.prep!/1 a valid Dic" do
    test "adds a default error message" do
      spec = %Dic{keys: %Str{}, vals: %Int{}}

      assert Mold.prep!(spec).error_message ==
               "must be a mapping where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{spec | min_size: 5}).error_message ==
               "must be a mapping with at least 5 entries, where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{spec | max_size: 5}).error_message ==
               "must be a mapping with at most 5 entries, where each key must be a string, and each value must be an integer"

      assert Mold.prep!(%{spec | min_size: 2, max_size: 5}).error_message ==
               "must be a mapping with at least 2 and at most 5 entries, where each key must be a string, and each value must be an integer"
    end

    test "accepts an error message" do
      spec = %Dic{keys: %Str{}, vals: %Int{}, error_message: "dammit"}

      assert Mold.prep!(spec).error_message == "dammit"
    end
  end

  describe "Mold.exam a Dic" do
    test "Error if the spec isn't prepped" do
      assert_raise(
        Error,
        "you must call Mold.prep/1 on the spec before calling Mold.exam/2",
        fn ->
          Mold.exam(%Dic{}, %{"foo" => 1})
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_not_ok_spec = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, error_message: "dammit"})
      nil_ok_spec = %{nil_not_ok_spec | nil_ok?: true}

      :ok = Mold.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Mold.exam(nil_not_ok_spec, nil)
    end

    test "error if not a map" do
      spec = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, error_message: "dammit"})

      {:error, "dammit"} = Mold.exam(spec, 5)
      {:error, "dammit"} = Mold.exam(spec, [])
      {:error, "dammit"} = Mold.exam(spec, "foo")

      :ok = Mold.exam(spec, %{})
      :ok = Mold.exam(spec, %{"foo" => 5, "bar" => 9})
    end

    test ":min_size" do
      spec = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, min_size: 2, error_message: "dammit"})

      :ok = Mold.exam(spec, %{"foo" => 5, "bar" => 9})
      :ok = Mold.exam(spec, %{"foo" => 5, "bar" => 9, "fud" => 8})
      {:error, "dammit"} = Mold.exam(spec, %{"foo" => 5})
    end

    test ":max_size" do
      spec = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}, max_size: 2, error_message: "dammit"})

      :ok = Mold.exam(spec, %{"foo" => 5})
      :ok = Mold.exam(spec, %{"foo" => 5, "bar" => 9})
      {:error, "dammit"} = Mold.exam(spec, %{"foo" => 5, "bar" => 2, "elf" => 8})
    end

    test ":bad keys" do
      spec =
        Mold.prep!(%Dic{
          keys: %Str{regex: ~r/^[0-f]+$/, error_message: "must be a hex string"},
          vals: %Int{}
        })

      assert :ok = Mold.exam(spec, %{"09af" => 3, "1dd" => 5, "1a9" => 2})

      assert {:error,
              %{"__key_errors__" => %{keys: [-1, "bar"], message: "must be a hex string"}}} =
               Mold.exam(spec, %{"09af" => 3, -1 => 5, "bar" => 2})
    end

    test ":bad vals" do
      spec = Mold.prep!(%Dic{keys: %Str{}, vals: %Int{}})

      assert :ok = Mold.exam(spec, %{"foo" => 3, "bar" => 2, "nut" => 4})

      assert {:error, %{"bar" => "must be an integer", "nut" => "must be an integer"}} =
               Mold.exam(spec, %{"foo" => 3, "bar" => true, "nut" => "wow"})
    end
  end
end
