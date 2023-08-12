defmodule Anal.LstTest do
  alias Anal.SpecError
  alias Anal.Lst
  alias Anal.Str

  use ExUnit.Case

  describe "Anal.prep! a Lst raises a SpecError when the spec has bad" do
    test "nil_ok?" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Lst{nil_ok?: "yuh"})
      end)
    end

    test ":also" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Anal.prep!(%Lst{also: &(&1 + &2)})
      end)
    end

    test ":min_length" do
      assert_raise(SpecError, ":min_length must be a non-negative integer", fn ->
        Anal.prep!(%Lst{min_length: -1})
      end)

      assert_raise(SpecError, ":min_length must be a non-negative integer", fn ->
        Anal.prep!(%Lst{min_length: "9"})
      end)
    end

    test ":max_length" do
      assert_raise(SpecError, ":max_length must be a positive integer", fn ->
        Anal.prep!(%Lst{max_length: 0})
      end)

      assert_raise(SpecError, ":max_length must be a positive integer", fn ->
        Anal.prep!(%Lst{max_length: "5"})
      end)
    end

    test ":min_length - :max_length combo" do
      assert_raise(SpecError, ":min_length must be less than or equal to :max_length", fn ->
        Anal.prep!(%Lst{min_length: 5, max_length: 4})
      end)
    end

    test ":of" do
      assert_raise(SpecError, ":of is required and must implement the Anal protocol", fn ->
        Anal.prep!(%Lst{of: "farts"})
      end)
    end
  end

  describe "Anal.prep!/1 a valid Lst" do
    test "adds a default error message" do
      assert %Lst{error_message: "must be a list"} = Anal.prep!(%Lst{of: %Str{}})

      assert %Lst{error_message: "must be a list with at least 5 elements"} =
               Anal.prep!(%Lst{of: %Str{}, min_length: 5})

      assert %Lst{error_message: "must be a list with at most 5 elements"} =
               Anal.prep!(%Lst{of: %Str{}, max_length: 5})

      assert %Lst{error_message: "must be a list with at least 1 and at most 5 elements"} =
               Anal.prep!(%Lst{of: %Str{}, min_length: 1, max_length: 5})
    end

    test "accepts an error message" do
      assert %Lst{error_message: "dammit"} = Anal.prep!(%Lst{of: %Str{}, error_message: "dammit"})
    end
  end

  describe "Anal.exam a valid Lst" do
    test "SpecError if the spec isn't prepped" do
      assert_raise(
        SpecError,
        "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
        fn ->
          Anal.exam(%Lst{}, true)
        end
      )
    end


    test "allows nil iff nil_ok?" do
      nil_not_ok_spec = Anal.prep!(%Lst{of: %Str{}, error_message: "dammit"})
      nil_ok_spec = %Lst{nil_not_ok_spec | nil_ok?: true}

      :ok = Anal.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
    end

  #   test "error if not a map" do
  #     spec = Anal.prep!(%Rec{error_message: "dammit"})

  #     [
  #       true,
  #       1,
  #       "foo",
  #       [],
  #       {}
  #     ]
  #     |> Enum.each(fn val ->
  #       assert {:error, "dammit"} = Anal.exam(spec, val)
  #     end)

  #     assert :ok = Anal.exam(spec, %{})
  #   end

  #   test "with required fields" do
  #     required = %{"rs" => %Anal.Str{}, "rb" => %Anal.Boo{}}

  #     spec = Anal.prep!(%Rec{required: required})

  #     :ok = Anal.exam(spec, %{"rs" => "foo", "rb" => true})
  #     {:error, %{"rb" => "is required"}} = Anal.exam(spec, %{"rs" => "foo"})
  #   end

  #   test "with optional fields" do
  #     # required = %{"rs" => %Anal.Str{}, "rb" => %Anal.Boo{}}
  #     optional = %{"os" => %Anal.Str{}, "ob" => %Anal.Boo{}}

  #     spec = Anal.prep!(%Rec{optional: optional, error_message: "dammit"})

  #     :ok = Anal.exam(spec, %{"rs" => "foo", "rb" => true})
  #     :ok = Anal.exam(spec, %{"rb" => true})
  #     :ok = Anal.exam(spec, %{})
  #   end

  #   test "with exclusive?" do
  #     required = %{"r" => %Anal.Str{}}
  #     optional = %{"o" => %Anal.Str{}}

  #     spec = Anal.prep!(%Rec{required: required, optional: optional, error_message: "dammit"})
  #     exclusive_spec = Map.put(spec, :exclusive?, true)

  #     assert :ok = Anal.exam(spec, %{"r" => "foo", "other" => "thing"})
  #     assert :ok = Anal.exam(spec, %{"r" => "foo", "o" => "foo", "other" => "thing"})

  #     assert {:error, %{"other" => "is not allowed"}} =
  #              Anal.exam(exclusive_spec, %{"r" => "foo", "other" => "thing"})

  #     assert {:error, %{"other" => "is not allowed"}} =
  #              Anal.exam(exclusive_spec, %{"r" => "foo", "o" => "foo", "other" => "thing"})
  #   end

  #   test "detects nested errors" do
  #     required = %{"r" => %Anal.Str{error_message: "bad r"}}
  #     optional = %{"o" => %Anal.Str{error_message: "bad o"}}

  #     spec = Anal.prep!(%Rec{required: required, optional: optional})

  #     assert :ok = Anal.exam(spec, %{"r" => "foo", "other" => "thing"})
  #     assert :ok = Anal.exam(spec, %{"r" => "foo", "o" => "foo", "other" => "thing"})

  #     assert {:error, %{"r" => "bad r"}} = Anal.exam(spec, %{"r" => 1, "other" => 1})

  #     assert {:error, %{"o" => "bad o"}} =
  #              Anal.exam(spec, %{"r" => "foo", "o" => 1, "other" => 1})

  #     assert {:error, %{"r" => "bad r", "o" => "bad o"}} =
  #              Anal.exam(spec, %{"r" => 1, "o" => 1, "other" => 1})
  #   end

  #   test "detects deeply nested errors" do
  #     required = %{"r" => %Anal.Str{error_message: "bad r str"}}
  #     optional = %{"o" => %Anal.Str{error_message: "bad o str"}}

  #     nested_rec_spec = %Rec{
  #       required: required,
  #       optional: optional
  #     }

  #     spec =
  #       Anal.prep!(%Rec{
  #         required: %{"r" => Map.put(nested_rec_spec, :error_message, "bad r rec")},
  #         optional: %{"o" => Map.put(nested_rec_spec, :error_message, "bad o rec")}
  #       })

  #     assert :ok =
  #              Anal.exam(spec, %{
  #                "r" => %{"r" => "foo", "o" => "foo", "x" => "?"},
  #                "o" => %{"r" => "foo", "o" => "foo", "x" => "?"},
  #                "x" => "?"
  #              })

  #     assert :ok =
  #              Anal.exam(spec, %{
  #                "r" => %{"r" => "foo"},
  #                "o" => %{"r" => "foo", "o" => "foo", "x" => "?"},
  #                "x" => "?"
  #              })

  #     assert :ok = Anal.exam(spec, %{"r" => %{"r" => "foo"}})

  #     assert {:error, errors} =
  #              Anal.exam(spec, %{
  #                "r" => %{"r" => 1, "o" => 1, "x" => "?"},
  #                "o" => %{"o" => 1, "x" => "?"},
  #                "x" => "?"
  #              })

  #     assert errors == %{
  #              "r" => %{"r" => "bad r str", "o" => "bad o str"},
  #              "o" => %{
  #                "r" => "is required",
  #                "o" => "bad o str"
  #              }
  #            }

  #     assert {:error, errors} = Anal.exam(spec, %{"o" => %{"o" => 1, "x" => "?"}, "x" => "?"})

  #     assert errors == %{
  #              "r" => "is required",
  #              "o" => %{
  #                "r" => "is required",
  #                "o" => "bad o str"
  #              }
  #            }

  #     assert {:error, errors} =
  #              Anal.exam(spec, %{"r" => 1, "o" => %{"o" => 1, "x" => "?"}, "x" => "?"})

  #     assert errors == %{
  #              "r" => "bad r rec",
  #              "o" => %{
  #                "r" => "is required",
  #                "o" => "bad o str"
  #              }
  #            }

  #     assert {:error, %{"r" => "bad r rec"}} = Anal.exam(spec, %{"r" => 1, "other" => 1})

  #     assert {:error, %{"o" => "bad o rec"}} =
  #              Anal.exam(spec, %{"r" => "foo", "o" => 1, "other" => 1})

  #     assert {:error, %{"r" => "bad r rec", "o" => "bad o rec"}} =
  #              Anal.exam(spec, %{"r" => 1, "o" => 1, "other" => 1})
  #   end
  end
end

# defmodule Anal.LstTest do
#   alias Anal.SpecError
#   alias Anal.Spec
#   alias Anal.Lst
#   alias Anal.Str
#   alias Anal.Int

#   use ExUnit.Case

#   describe "Lst.new()" do
#     test "creates a list spec" do
#       assert Lst.new(of: Str.new()) == %Lst{
#                can_be_nil: false,
#                of: %Str{},
#                min_len: nil,
#                max_len: nil,
#                also: nil
#              }

#       assert %Lst{
#                can_be_nil: true,
#                of: %Str{},
#                min_len: 1,
#                max_len: 10,
#                also: also
#              } =
#                Lst.new(
#                  can_be_nil: true,
#                  of: Str.new(),
#                  min_len: 1,
#                  max_len: 10,
#                  also: &(rem(&1, 2) == 0)
#                )

#       assert is_function(also, 1)

#       assert_raise ArgumentError, ~r/the following keys must also be given.* \[:of\]/, fn ->
#         Lst.new()
#       end

#       assert_raise SpecError, ":of must be a spec", fn ->
#         Lst.new(of: "foo")
#       end

#       assert_raise SpecError, ":also must be a 1-arity function, got \"foo\"", fn ->
#         Lst.new(of: Str.new(), also: "foo")
#       end

#       assert_raise SpecError, ":min_len must be a non-negative integer", fn ->
#         Lst.new(of: Str.new(), min_len: "foo")
#       end

#       assert_raise SpecError, ":max_len must be a non-negative integer", fn ->
#         Lst.new(of: Str.new(), max_len: -4)
#       end

#       assert_raise SpecError, ":min_len cannot be greater than :max_len", fn ->
#         Lst.new(of: Str.new(), max_len: 1, min_len: 2)
#       end

#       assert %Lst{min_len: 1, max_len: nil} = Lst.new(of: Str.new(), min_len: 1)

#       assert %Lst{min_len: nil, max_len: 1} = Lst.new(of: Str.new(), max_len: 1)
#     end

#     test "validates using a list spec" do
#       spec = Lst.new(of: Str.new())

#       assert :ok = Spec.validate([], spec)
#       assert Spec.validate(nil, spec) == {:error, "cannot be nil"}

#       min_len_spec = Lst.new(of: Str.new(), min_len: 1)
#       assert Spec.validate([], min_len_spec) == {:error, "length must be at least 1"}
#       assert :ok = Spec.validate(["a"], min_len_spec)
#       assert :ok = Spec.validate(["a", "b"], min_len_spec)

#       max_len_spec = Lst.new(of: Str.new(), max_len: 1)
#       assert :ok = Spec.validate(["a"], max_len_spec)
#       assert :ok = Spec.validate(["a"], max_len_spec)
#       assert Spec.validate(["a", "b"], max_len_spec) == {:error, "length cannot exceed 1"}

#       spec = Lst.new(of: Str.new())
#       assert :ok = Spec.validate(["a", "b"], spec)

#       assert Spec.validate([1, "a", true], spec) ==
#                {:error, %{[0] => "must be a string", [2] => "must be a string"}}

#       also = fn ints ->
#         sum = Enum.sum(ints)
#         if sum > 5, do: {:error, "sum is too high"}, else: :ok
#       end

#       also_spec = Lst.new(of: Int.new(can_be_nil: false), also: also)

#       assert :ok = Spec.validate([1, 0, 0, 0, 0, 3], also_spec)
#       assert Spec.validate([1, 6], also_spec) == {:error, "sum is too high"}
#     end
#   end
# end
