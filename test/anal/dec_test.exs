defmodule Anal.DecTest do
  use ExUnit.Case

  alias Anal.Dec
  alias Anal.SpecError

  describe "Anal.prep! a Dec raises a SpecError when" do
    test "nil_ok? not a boolean" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Dec{nil_ok?: "yuh"})
      end)
    end

    test ":also is not an arity-1 function" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Anal.prep!(%Dec{also: &(&1 + &2)})
      end)
    end

    test "given an invalid bound" do
      Enum.each([:lt, :lte, :gt, :gte], fn bound ->
        spec = Map.put(%Dec{}, bound, "some shit")

        assert_raise(
          SpecError,
          "#{inspect(bound)} must be a Decimal, a decimal-formatted string, or an integer",
          fn -> Anal.prep!(spec) end
        )
      end)
    end

    test "trying to use both upper or both lower bounds" do
      assert_raise SpecError, "cannot use both :gt and :gte", fn ->
        Anal.prep!(%Dec{gt: 5, gte: 3})
      end

      assert_raise SpecError, "cannot use both :lt and :lte", fn ->
        Anal.prep!(%Dec{lt: 5, lte: 3})
      end
    end

    test "lower bound is greater than upper bound" do
      for lower <- [:gt, :gte], upper <- [:lt, :lte] do
        assert_raise SpecError, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          spec = Map.merge(%Dec{}, %{lower => 5, upper => 3})
          Anal.prep!(spec)
        end

        assert_raise SpecError, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          spec = Map.merge(%Dec{}, %{lower => 5, upper => 5})
          Anal.prep!(spec)
        end
      end
    end

    test ":max_decimal_places is not a non-negative integer" do
      assert_raise SpecError, ":max_decimal_places must be a non-negative integer", fn ->
        Anal.prep!(%Dec{max_decimal_places: -1})
      end
    end
  end

  describe "Anal.prep! a valid Dec" do
    test "with an integer bound" do
      assert %Dec{} = Anal.prep!(%Dec{gt: 1})
    end

    test "with a decimal-formatted string bound" do
      assert %Dec{} = Anal.prep!(%Dec{gt: "1.01"})
    end

    test "with a Decimal bound" do
      assert %Dec{} = Anal.prep!(%Dec{gt: Decimal.new("1.01")})
    end

    test "adds the default error message" do
      assert %Dec{error_message: "must be a decimal-formatted string"} = Anal.prep!(%Dec{})

      assert %Dec{error_message: "if not nil, must be a decimal-formatted string"} =
               Anal.prep!(%Dec{nil_ok?: true})

      assert %Dec{error_message: "must be a decimal-formatted string with up to 0 decimal places"} =
               Anal.prep!(%Dec{max_decimal_places: 0})

      assert %Dec{
               error_message: "must be a decimal-formatted string with up to 10 decimal places"
             } = Anal.prep!(%Dec{max_decimal_places: 10})

      assert %Dec{
               error_message: "must be a decimal-formatted string less than 5.5"
             } = Anal.prep!(%Dec{lt: "5.5"})

      assert %Dec{
               error_message: "must be a decimal-formatted string greater than 5.5"
             } = Anal.prep!(%Dec{gt: "5.5"})

      assert %Dec{
               error_message: "must be a decimal-formatted string less than or equal to 5.5"
             } = Anal.prep!(%Dec{lte: "5.5"})

      assert %Dec{
               error_message: "must be a decimal-formatted string greater than or equal to 5.5"
             } = Anal.prep!(%Dec{gte: "5.5"})

      assert %Dec{
               error_message:
                 "must be a decimal-formatted string greater than or equal to 5.5 and less than 20"
             } = Anal.prep!(%Dec{gte: "5.5", lt: 20})

      assert %Dec{
               error_message:
                 "must be a decimal-formatted string greater than 5.5 and less than or equal to 20"
             } = Anal.prep!(%Dec{gt: "5.5", lte: 20})

      assert %Dec{
               error_message:
                 "must be a decimal-formatted string with up to 10 decimal places, greater than 5.5, and less than or equal to 20"
             } = Anal.prep!(%Dec{gt: "5.5", lte: 20, max_decimal_places: 10})
    end

    test "can use custom error message" do
      assert %Dec{error_message: "dammit"} = Anal.prep!(%Dec{error_message: "dammit"})
    end
  end

  describe "Anal.exam using Dec" do
    test "SpecError if the spec isn't prepped" do
      unprepped = %Dec{}

      assert_raise(
        SpecError,
        "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
        fn ->
          Anal.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_spec = Anal.prep!(%Dec{nil_ok?: true})
      nil_not_ok_spec = Anal.prep!(%Dec{error_message: "dammit"})

      :ok = Anal.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
    end

    test "fail if not a decimal-formatted string" do
      spec = Anal.prep!(%Dec{error_message: "dammit"})
      # pass
      [".1", "1.1", "1", "0.1", "1.0", "-4", "-.4", "-0.4"]
      |> Enum.each(&assert :ok = Anal.exam(spec, &1))

      # fail
      [".1.11", "1.", "1.1.1", true, "bla", Decimal.new(1)]
      |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "takes an :also function" do
      spec = Anal.prep!(%Dec{error_message: "dammit", also: &String.contains?(&1, "3")})

      :ok = Anal.exam(spec, "2.30")
      {:error, "dammit"} = Anal.exam(spec, "2.22")
    end

    test "SpecError if :also doesn't return a boolean" do
      spec = Anal.prep!(%Dec{error_message: "dammit", also: fn _ -> :some_shit end})

      assert_raise(SpecError, ":also must return a boolean, but it returned :some_shit", fn ->
        Anal.exam(spec, "1.1")
      end)
    end

    test "checks :max_decimal_places" do
      spec = Anal.prep!(%Dec{max_decimal_places: 2, error_message: "dammit"})
      # pass
      [".1", ".11", "1", "1.1", "1.11"] |> Enum.each(&assert :ok = Anal.exam(spec, &1))
      # fail
      [".111", "1.111", "1.1111"] |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "checks :gt" do
      spec = Anal.prep!(%Dec{gt: "2", error_message: "dammit"})
      # pass
      ["2.1", "3"] |> Enum.each(&assert :ok = Anal.exam(spec, &1))
      # fail
      ["1", "2"] |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "checks :gte" do
      spec = Anal.prep!(%Dec{gte: "2.5", error_message: "dammit"})
      # pass
      ["2.5", "2.50", "3"] |> Enum.each(&assert :ok = Anal.exam(spec, &1))
      # fail
      ["1", "2.49999999"] |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "checks :lt" do
      spec = Anal.prep!(%Dec{lt: "2.5", error_message: "dammit"})
      # pass
      ["2.4999", "0"] |> Enum.each(&assert :ok = Anal.exam(spec, &1))
      # fail
      ["2.5", "3"] |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "checks :lte" do
      spec = Anal.prep!(%Dec{lte: "2.5", error_message: "dammit"})
      # pass
      ["2.50", "0"] |> Enum.each(&assert :ok = Anal.exam(spec, &1))
      # fail
      ["2.50000001", "3"] |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "checks both an upper and lower bound" do
      spec = Anal.prep!(%Dec{gte: 5, lt: 10, error_message: "dammit"})
      # pass
      ["5", "7", "9.999"] |> Enum.each(&assert :ok = Anal.exam(spec, &1))
      # fail
      ["4", "4.99", "10", "10.01"] |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end
  end
end