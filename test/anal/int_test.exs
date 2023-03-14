defmodule Anal.IntTest do
  use ExUnit.Case

  require Integer

  alias Anal.Int
  alias Anal.SpecError

  describe "Anal.prep! a Int raises a SpecError when" do
    test "nil_ok? not a boolean" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Int{nil_ok?: "yuh"})
      end)
    end

    test ":also is not an arity-1 function" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Anal.prep!(%Int{also: &(&1 + &2)})
      end)
    end

    test "given an invalid bound" do
      Enum.each([:lt, :lte, :gt, :gte], fn bound ->
        spec = Map.put(%Int{}, bound, "some shit")

        assert_raise(
          SpecError,
          "#{inspect(bound)} must be an integer",
          fn -> Anal.prep!(spec) end
        )
      end)
    end

    test "trying to use both upper or both lower bounds" do
      assert_raise SpecError, "cannot use both :gt and :gte", fn ->
        Anal.prep!(%Int{gt: 5, gte: 3})
      end

      assert_raise SpecError, "cannot use both :lt and :lte", fn ->
        Anal.prep!(%Int{lt: 5, lte: 3})
      end
    end

    test "lower bound is greater than upper bound" do
      for lower <- [:gt, :gte], upper <- [:lt, :lte] do
        assert_raise SpecError, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          spec = Map.merge(%Int{}, %{lower => 5, upper => 3})
          Anal.prep!(spec)
        end

        assert_raise SpecError, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          spec = Map.merge(%Int{}, %{lower => 5, upper => 5})
          Anal.prep!(spec)
        end
      end
    end
  end

  describe "Anal.prep! a valid Int" do
    test "with bounds" do
      assert %Int{} = Anal.prep!(%Int{gt: 1, lte: 4})
    end

    test "adds the default error message" do
      assert %Int{error_message: "must be an integer"} = Anal.prep!(%Int{})

      assert %Int{error_message: "if not nil, must be an integer"} =
               Anal.prep!(%Int{nil_ok?: true})

      assert %Int{
               error_message: "must be an integer"
             } = Anal.prep!(%Int{})

      assert %Int{
               error_message: "must be an integer less than 5"
             } = Anal.prep!(%Int{lt: 5})

      assert %Int{
               error_message: "must be an integer greater than 5"
             } = Anal.prep!(%Int{gt: 5})

      assert %Int{
               error_message: "must be an integer less than or equal to 5"
             } = Anal.prep!(%Int{lte: 5})

      assert %Int{
               error_message: "must be an integer greater than or equal to 5"
             } = Anal.prep!(%Int{gte: 5})

      assert %Int{
               error_message: "must be an integer greater than or equal to 5 and less than 20"
             } = Anal.prep!(%Int{gte: 5, lt: 20})

      assert %Int{
               error_message: "must be an integer greater than 5 and less than or equal to 20"
             } = Anal.prep!(%Int{gt: 5, lte: 20})
    end

    test "can use custom error message" do
      assert %Int{error_message: "dammit"} = Anal.prep!(%Int{error_message: "dammit"})
    end
  end

  describe "Anal.exam using Int" do
    test "SpecError if the spec isn't prepped" do
      unprepped = %Int{}

      assert_raise(
        SpecError,
        "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
        fn ->
          Anal.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_spec = Anal.prep!(%Int{nil_ok?: true})
      nil_not_ok_spec = Anal.prep!(%Int{error_message: "dammit"})

      :ok = Anal.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
    end

    test "fail if not an integer" do
      spec = Anal.prep!(%Int{error_message: "dammit"})
      [1, -1] |> Enum.each(&assert :ok = Anal.exam(spec, &1))

      ["1", true, "bla", Decimal.new(1)]
      |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "takes an :also function" do
      spec = Anal.prep!(%Int{error_message: "dammit", also: &Integer.is_even/1})

      :ok = Anal.exam(spec, 4)
      {:error, "dammit"} = Anal.exam(spec, 5)
    end

    test "SpecError if :also doesn't return a boolean" do
      spec = Anal.prep!(%Int{error_message: "dammit", also: fn _ -> :some_shit end})

      assert_raise(SpecError, ":also must return a boolean, but it returned :some_shit", fn ->
        Anal.exam(spec, 1)
      end)
    end

    test "checks :gt" do
      spec = Anal.prep!(%Int{gt: 2, error_message: "dammit"})
      assert :ok = Anal.exam(spec, 3)
      [1, 2] |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "checks :gte" do
      spec = Anal.prep!(%Int{gte: 2, error_message: "dammit"})
      [2, 3] |> Enum.each(&assert :ok = Anal.exam(spec, &1))
      assert {:error, "dammit"} = Anal.exam(spec, 1)
    end

    test "checks :lt" do
      spec = Anal.prep!(%Int{lt: 2, error_message: "dammit"})
      assert :ok = Anal.exam(spec, 1)
      [2, 3] |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end

    test "checks :lte" do
      spec = Anal.prep!(%Int{lte: 2, error_message: "dammit"})
      [1, 2] |> Enum.each(&assert :ok = Anal.exam(spec, &1))
      assert {:error, "dammit"} = Anal.exam(spec, 3)
    end

    test "checks both an upper and lower bound" do
      spec = Anal.prep!(%Int{gte: 5, lt: 10, error_message: "dammit"})
      [5, 9] |> Enum.each(&assert :ok = Anal.exam(spec, &1))
      [4, 11] |> Enum.each(&assert {:error, "dammit"} = Anal.exam(spec, &1))
    end
  end
end
