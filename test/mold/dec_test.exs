defmodule Mold.DecTest do
  use ExUnit.Case

  alias Mold.Dec
  alias Mold.Error

  describe "Mold.prep! a Dec raises a Error when" do
    test "nil_ok? not a boolean" do
      assert_raise(Error, ":nil_ok? must be a boolean", fn ->
        Mold.prep!(%Dec{nil_ok?: "yuh"})
      end)
    end

    test ":also is not an arity-1 function" do
      assert_raise(Error, ":also must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Dec{also: &(&1 + &2)})
      end)
    end

    test "given an invalid bound" do
      Enum.each([:lt, :lte, :gt, :gte], fn bound ->
        spec = Map.put(%Dec{}, bound, "some shit")

        assert_raise(
          Error,
          "#{inspect(bound)} must be a Decimal, a decimal-formatted string, or an integer",
          fn -> Mold.prep!(spec) end
        )
      end)
    end

    test "trying to use both upper or both lower bounds" do
      assert_raise Error, "cannot use both :gt and :gte", fn ->
        Mold.prep!(%Dec{gt: 5, gte: 3})
      end

      assert_raise Error, "cannot use both :lt and :lte", fn ->
        Mold.prep!(%Dec{lt: 5, lte: 3})
      end
    end

    test "lower bound is greater than upper bound" do
      for lower <- [:gt, :gte], upper <- [:lt, :lte] do
        assert_raise Error, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          spec = Map.merge(%Dec{}, %{lower => 5, upper => 3})
          Mold.prep!(spec)
        end

        assert_raise Error, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          spec = Map.merge(%Dec{}, %{lower => 5, upper => 5})
          Mold.prep!(spec)
        end
      end
    end

    test ":max_decimal_places is not a non-negative integer" do
      assert_raise Error, ":max_decimal_places must be a non-negative integer", fn ->
        Mold.prep!(%Dec{max_decimal_places: -1})
      end
    end
  end

  describe "Mold.prep! a valid Dec" do
    test "with an integer bound" do
      assert %Dec{} = Mold.prep!(%Dec{gt: 1})
    end

    test "with a decimal-formatted string bound" do
      assert %Dec{} = Mold.prep!(%Dec{gt: "1.01"})
    end

    test "with a Decimal bound" do
      assert %Dec{} = Mold.prep!(%Dec{gt: Decimal.new("1.01")})
    end

    test "adds the default error message" do
      assert %Dec{error_message: "must be a decimal-formatted string"} = Mold.prep!(%Dec{})

      assert %Dec{error_message: "if not nil, must be a decimal-formatted string"} =
               Mold.prep!(%Dec{nil_ok?: true})

      assert %Dec{error_message: "must be a decimal-formatted string with up to 0 decimal places"} =
               Mold.prep!(%Dec{max_decimal_places: 0})

      assert %Dec{
               error_message: "must be a decimal-formatted string with up to 10 decimal places"
             } = Mold.prep!(%Dec{max_decimal_places: 10})

      assert %Dec{
               error_message: "must be a decimal-formatted string less than 5.5"
             } = Mold.prep!(%Dec{lt: "5.5"})

      assert %Dec{
               error_message: "must be a decimal-formatted string greater than 5.5"
             } = Mold.prep!(%Dec{gt: "5.5"})

      assert %Dec{
               error_message: "must be a decimal-formatted string less than or equal to 5.5"
             } = Mold.prep!(%Dec{lte: "5.5"})

      assert %Dec{
               error_message: "must be a decimal-formatted string greater than or equal to 5.5"
             } = Mold.prep!(%Dec{gte: "5.5"})

      assert %Dec{
               error_message:
                 "must be a decimal-formatted string greater than or equal to 5.5 and less than 20"
             } = Mold.prep!(%Dec{gte: "5.5", lt: 20})

      assert %Dec{
               error_message:
                 "must be a decimal-formatted string greater than 5.5 and less than or equal to 20"
             } = Mold.prep!(%Dec{gt: "5.5", lte: 20})

      assert %Dec{
               error_message:
                 "must be a decimal-formatted string with up to 10 decimal places, greater than 5.5, and less than or equal to 20"
             } = Mold.prep!(%Dec{gt: "5.5", lte: 20, max_decimal_places: 10})
    end

    test "can use custom error message" do
      assert %Dec{error_message: "dammit"} = Mold.prep!(%Dec{error_message: "dammit"})
    end
  end

  describe "Mold.exam using Dec" do
    test "Error if the spec isn't prepped" do
      unprepped = %Dec{}

      assert_raise(
        Error,
        "you must call Mold.prep/1 on the spec before calling Mold.exam/2",
        fn ->
          Mold.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_spec = Mold.prep!(%Dec{nil_ok?: true})
      nil_not_ok_spec = Mold.prep!(%Dec{error_message: "dammit"})

      :ok = Mold.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Mold.exam(nil_not_ok_spec, nil)
    end

    test "fail if not a decimal-formatted string" do
      spec = Mold.prep!(%Dec{error_message: "dammit"})
      # pass
      [".1", "1.1", "1", "0.1", "1.0", "-4", "-.4", "-0.4"]
      |> Enum.each(&assert :ok = Mold.exam(spec, &1))

      # fail
      [".1.11", "1.", "1.1.1", true, "bla", Decimal.new(1)]
      |> Enum.each(&assert {:error, "dammit"} = Mold.exam(spec, &1))
    end

    test "takes an :also function" do
      spec = Mold.prep!(%Dec{error_message: "dammit", also: &String.contains?(&1, "3")})

      :ok = Mold.exam(spec, "2.30")
      {:error, "dammit"} = Mold.exam(spec, "2.22")
    end

    test "Error if :also doesn't return a boolean" do
      spec = Mold.prep!(%Dec{error_message: "dammit", also: fn _ -> :some_shit end})

      assert_raise(Error, ":also must return a boolean, but it returned :some_shit", fn ->
        Mold.exam(spec, "1.1")
      end)
    end

    test "checks :max_decimal_places" do
      spec = Mold.prep!(%Dec{max_decimal_places: 2, error_message: "dammit"})
      # pass
      [".1", ".11", "1", "1.1", "1.11"] |> Enum.each(&assert :ok = Mold.exam(spec, &1))
      # fail
      [".111", "1.111", "1.1111"] |> Enum.each(&assert {:error, "dammit"} = Mold.exam(spec, &1))
    end

    test "checks :gt" do
      spec = Mold.prep!(%Dec{gt: "2", error_message: "dammit"})
      # pass
      ["2.1", "3"] |> Enum.each(&assert :ok = Mold.exam(spec, &1))
      # fail
      ["1", "2"] |> Enum.each(&assert {:error, "dammit"} = Mold.exam(spec, &1))
    end

    test "checks :gte" do
      spec = Mold.prep!(%Dec{gte: "2.5", error_message: "dammit"})
      # pass
      ["2.5", "2.50", "3"] |> Enum.each(&assert :ok = Mold.exam(spec, &1))
      # fail
      ["1", "2.49999999"] |> Enum.each(&assert {:error, "dammit"} = Mold.exam(spec, &1))
    end

    test "checks :lt" do
      spec = Mold.prep!(%Dec{lt: "2.5", error_message: "dammit"})
      # pass
      ["2.4999", "0"] |> Enum.each(&assert :ok = Mold.exam(spec, &1))
      # fail
      ["2.5", "3"] |> Enum.each(&assert {:error, "dammit"} = Mold.exam(spec, &1))
    end

    test "checks :lte" do
      spec = Mold.prep!(%Dec{lte: "2.5", error_message: "dammit"})
      # pass
      ["2.50", "0"] |> Enum.each(&assert :ok = Mold.exam(spec, &1))
      # fail
      ["2.50000001", "3"] |> Enum.each(&assert {:error, "dammit"} = Mold.exam(spec, &1))
    end

    test "checks both an upper and lower bound" do
      spec = Mold.prep!(%Dec{gte: 5, lt: 10, error_message: "dammit"})
      # pass
      ["5", "7", "9.999"] |> Enum.each(&assert :ok = Mold.exam(spec, &1))
      # fail
      ["4", "4.99", "10", "10.01"] |> Enum.each(&assert {:error, "dammit"} = Mold.exam(spec, &1))
    end
  end
end
