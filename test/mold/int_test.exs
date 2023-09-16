defmodule Mold.IntTest do
  use ExUnit.Case

  require Integer

  alias Mold.Int
  alias Mold.Error

  describe "Mold.prep! a Int raises a Error when" do
    test "nil_ok? not a boolean" do
      assert_raise(Error, ":nil_ok? must be a boolean", fn ->
        Mold.prep!(%Int{nil_ok?: "yuh"})
      end)
    end

    test ":but is not an arity-1 function" do
      assert_raise(Error, ":but must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Int{but: &(&1 + &2)})
      end)
    end

    test "given an invalid bound" do
      Enum.each([:lt, :lte, :gt, :gte], fn bound ->
        mold = Map.put(%Int{}, bound, "some shit")

        assert_raise(
          Error,
          "#{inspect(bound)} must be an integer",
          fn -> Mold.prep!(mold) end
        )
      end)
    end

    test "trying to use both upper or both lower bounds" do
      assert_raise Error, "cannot use both :gt and :gte", fn ->
        Mold.prep!(%Int{gt: 5, gte: 3})
      end

      assert_raise Error, "cannot use both :lt and :lte", fn ->
        Mold.prep!(%Int{lt: 5, lte: 3})
      end
    end

    test "lower bound is greater than upper bound" do
      for lower <- [:gt, :gte], upper <- [:lt, :lte] do
        assert_raise Error, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          mold = Map.merge(%Int{}, %{lower => 5, upper => 3})
          Mold.prep!(mold)
        end

        assert_raise Error, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          mold = Map.merge(%Int{}, %{lower => 5, upper => 5})
          Mold.prep!(mold)
        end
      end
    end
  end

  describe "Mold.prep! a valid Int" do
    test "with bounds" do
      assert %Int{} = Mold.prep!(%Int{gt: 1, lte: 4})
    end

    test "adds the default error message" do
      assert %Int{error_message: "must be an integer"} = Mold.prep!(%Int{})

      assert %Int{error_message: "if not nil, must be an integer"} =
               Mold.prep!(%Int{nil_ok?: true})

      assert %Int{
               error_message: "must be an integer"
             } = Mold.prep!(%Int{})

      assert %Int{
               error_message: "must be an integer less than 5"
             } = Mold.prep!(%Int{lt: 5})

      assert %Int{
               error_message: "must be an integer greater than 5"
             } = Mold.prep!(%Int{gt: 5})

      assert %Int{
               error_message: "must be an integer less than or equal to 5"
             } = Mold.prep!(%Int{lte: 5})

      assert %Int{
               error_message: "must be an integer greater than or equal to 5"
             } = Mold.prep!(%Int{gte: 5})

      assert %Int{
               error_message: "must be an integer greater than or equal to 5 and less than 20"
             } = Mold.prep!(%Int{gte: 5, lt: 20})

      assert %Int{
               error_message: "must be an integer greater than 5 and less than or equal to 20"
             } = Mold.prep!(%Int{gt: 5, lte: 20})
    end

    test "can use custom error message" do
      assert %Int{error_message: "wrong"} = Mold.prep!(%Int{error_message: "wrong"})
    end
  end

  describe "Mold.exam using Int" do
    test "Error if the mold isn't prepped" do
      unprepped = %Int{}

      assert_raise(
        Error,
        "you must call Mold.prep/1 on the mold before calling Mold.exam/2",
        fn ->
          Mold.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_mold = Mold.prep!(%Int{nil_ok?: true})
      nil_not_ok_mold = Mold.prep!(%Int{error_message: "wrong"})

      :ok = Mold.exam(nil_ok_mold, nil)
      {:error, "wrong"} = Mold.exam(nil_not_ok_mold, nil)
    end

    test "fail if not an integer" do
      mold = Mold.prep!(%Int{error_message: "wrong"})
      [1, -1] |> Enum.each(&assert :ok = Mold.exam(mold, &1))

      ["1", true, "bla", Decimal.new(1)]
      |> Enum.each(&assert {:error, "wrong"} = Mold.exam(mold, &1))
    end

    test "takes an :but function" do
      mold = Mold.prep!(%Int{error_message: "wrong", but: &Integer.is_even/1})

      :ok = Mold.exam(mold, 4)
      {:error, "wrong"} = Mold.exam(mold, 5)
    end

    test "Error if :but doesn't return a boolean" do
      mold = Mold.prep!(%Int{error_message: "wrong", but: fn _ -> :poo end})

      assert_raise(Error, ":but must return a boolean, but it returned :poo", fn ->
        Mold.exam(mold, 1)
      end)
    end

    test "checks :gt" do
      mold = Mold.prep!(%Int{gt: 2, error_message: "wrong"})
      assert :ok = Mold.exam(mold, 3)
      [1, 2] |> Enum.each(&assert {:error, "wrong"} = Mold.exam(mold, &1))
    end

    test "checks :gte" do
      mold = Mold.prep!(%Int{gte: 2, error_message: "wrong"})
      [2, 3] |> Enum.each(&assert :ok = Mold.exam(mold, &1))
      assert {:error, "wrong"} = Mold.exam(mold, 1)
    end

    test "checks :lt" do
      mold = Mold.prep!(%Int{lt: 2, error_message: "wrong"})
      assert :ok = Mold.exam(mold, 1)
      [2, 3] |> Enum.each(&assert {:error, "wrong"} = Mold.exam(mold, &1))
    end

    test "checks :lte" do
      mold = Mold.prep!(%Int{lte: 2, error_message: "wrong"})
      [1, 2] |> Enum.each(&assert :ok = Mold.exam(mold, &1))
      assert {:error, "wrong"} = Mold.exam(mold, 3)
    end

    test "checks both an upper and lower bound" do
      mold = Mold.prep!(%Int{gte: 5, lt: 10, error_message: "wrong"})
      [5, 9] |> Enum.each(&assert :ok = Mold.exam(mold, &1))
      [4, 11] |> Enum.each(&assert {:error, "wrong"} = Mold.exam(mold, &1))
    end
  end
end
