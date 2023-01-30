defmodule Dammit.SpecTest do
  alias Dammit.SpecError
  alias Dammit.Spec
  alias Dammit.Spec.String, as: Str
  alias Dammit.Spec.Boolean, as: Bool
  alias Dammit.Spec.Integer, as: Int
  alias Dammit.Spec.Decimal, as: Dec

  use ExUnit.Case

  @comparision_fields [:gt, :lt, :gte, :lte]

  # TODO: figure out what this is
  doctest Dammit

  describe "Spec.List" do
    test "creates a list spec" do
      assert Spec.List.new(of: Str.new()) == %Spec.List{
               nullable: false,
               of: %Str{},
               min_len: nil,
               max_len: nil,
               and: nil
             }

      assert %Spec.List{
               nullable: true,
               of: %Str{},
               min_len: 1,
               max_len: 10,
               and: and_fn
             } =
               Spec.List.new(
                 nullable: true,
                 of: Str.new(),
                 min_len: 1,
                 max_len: 10,
                 and: &(rem(&1, 2) == 0)
               )

      assert is_function(and_fn, 1)

      assert_raise SpecError, ":of is required in Dammit.Spec.List", fn ->
        Spec.List.new()
      end

      assert_raise SpecError, ":of must be a spec", fn ->
        Spec.List.new(of: "foo")
      end

      assert_raise SpecError, ":and must be a 1-arity function, got \"foo\"", fn ->
        Spec.List.new(of: Str.new(), and: "foo")
      end

      assert_raise SpecError, ":min_len must be a non-negative integer", fn ->
        Spec.List.new(of: Str.new(), min_len: "foo")
      end

      assert_raise SpecError, ":max_len must be a non-negative integer", fn ->
        Spec.List.new(of: Str.new(), max_len: -4)
      end

      assert_raise SpecError, ":min_len cannot be greater than :max_len", fn ->
        Spec.List.new(of: Str.new(), max_len: 1, min_len: 2)
      end

      assert %Spec.List{min_len: 1, max_len: nil} = Spec.List.new(of: Str.new(), min_len: 1)

      assert %Spec.List{min_len: nil, max_len: 1} = Spec.List.new(of: Str.new(), max_len: 1)
    end

    test "validates using a list spec" do
      spec = Spec.List.new(of: Str.new())

      assert :ok = Spec.validate([], spec)
      assert Spec.validate(nil, spec) == {:error, "cannot be nil"}

      min_len_spec = Spec.List.new(of: Str.new(), min_len: 1)
      assert Spec.validate([], min_len_spec) == {:error, "length must be at least 1"}
      assert :ok = Spec.validate(["a"], min_len_spec)
      assert :ok = Spec.validate(["a", "b"], min_len_spec)

      max_len_spec = Spec.List.new(of: Str.new(), max_len: 1)
      assert :ok = Spec.validate(["a"], max_len_spec)
      assert :ok = Spec.validate(["a"], max_len_spec)
      assert Spec.validate(["a", "b"], max_len_spec) == {:error, "length cannot exceed 1"}

      spec = Spec.List.new(of: Str.new())
      assert :ok = Spec.validate(["a", "b"], spec)

      assert Spec.validate([1, "a", true], spec) ==
               {:error, %{[0] => "must be a string", [2] => "must be a string"}}

      and_fn = fn ints ->
        sum = Enum.sum(ints)
        if sum > 5, do: "sum is too high", else: :ok
      end

      and_spec = Spec.List.new(of: Int.new(nullable: false), and: and_fn)

      assert :ok = Spec.validate([1, 0, 0, 0, 0, 3], and_spec)
      assert Spec.validate([1, 6], and_spec) == {:error, "sum is too high"}
    end
  end

  describe "Spec.Map" do
    test "creates a map spec" do
      assert Spec.Map.new() == %Spec.Map{
               nullable: false,
               required: %{},
               optional: %{},
               exclusive: false,
               and: nil
             }

      assert Spec.Map.new(nullable: true) == %Spec.Map{nullable: true}
    end

    test "validate with a map Spec" do
      spec =
        Spec.Map.new(
          required: [my_str: Str.new(), my_int: Int.new()],
          optional: %{my_bool: Bool.new(nullable: true)}
        )

      assert :ok = Spec.validate(%{my_str: "foo", my_int: 1}, spec)
      assert :ok = Spec.validate(%{my_str: "foo", my_int: 1, my_bool: true}, spec)
      assert :ok = Spec.validate(%{my_str: "foo", my_int: 1, my_bool: nil}, spec)
      assert :ok = Spec.validate(%{my_str: "foo", my_int: 1, some_other_field: "foopy"}, spec)

      assert Spec.validate(%{my_str: "foo"}, spec) == {:error, %{[:my_int] => "is required"}}

      assert Spec.validate(%{}, spec) ==
               {:error, %{[:my_int] => "is required", [:my_str] => "is required"}}

      assert Spec.validate(%{my_str: "foo", my_int: "foo"}, spec) ==
               {:error, %{[:my_int] => "must be an integer"}}

      assert Spec.validate(%{my_str: 1, my_int: "foo"}, spec) ==
               {:error, %{[:my_int] => "must be an integer", [:my_str] => "must be a string"}}

      assert Spec.validate(%{my_str: 1, my_int: "foo"}, spec) ==
               {:error, %{[:my_int] => "must be an integer", [:my_str] => "must be a string"}}

      assert Spec.validate(%{my_str: 1, my_int: "foo", my_bool: "foo"}, spec) ==
               {:error,
                %{
                  [:my_int] => "must be an integer",
                  [:my_str] => "must be a string",
                  [:my_bool] => "must be a boolean"
                }}

      exclusive_spec = Map.put(spec, :exclusive, true)

      assert Spec.validate(%{my_str: "foo", my_int: 1, some_other_field: "foopy"}, exclusive_spec) ==
               {:error, %{[:some_other_field] => "is not allowed"}}

      empty_map_spec = Spec.Map.new()

      assert :ok = Spec.validate(%{}, empty_map_spec)
      assert :ok = Spec.validate(%{some_other_field: [1, 2, 3]}, empty_map_spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, empty_map_spec)

      assert Spec.validate(
               %{some_other_field: [1, 2, 3]},
               Map.put(empty_map_spec, :exclusive, true)
             ) ==
               {:error, %{[:some_other_field] => "is not allowed"}}
    end

    test "validate a nested map spec" do
      nested_spec =
        Spec.Map.new(
          required: %{my_str: Str.new(), my_int: Int.new()},
          optional: [my_bool: Bool.new(nullable: true)]
        )

      spec = Spec.Map.new(required: [nested: nested_spec])

      :ok = Spec.validate(%{nested: %{my_int: 1, my_str: "foo"}}, spec)

      assert Spec.validate(%{nested: %{my_str: "foo"}}, spec) ==
               {:error, %{[:nested, :my_int] => "is required"}}

      # exclucivity applies to nested specs
      # TODO: allow explicit overwrite in child spec 
      exclusive_spec = Map.put(spec, :exclusive, true)

      map = %{nested: %{my_str: 1, my_bool: 1}, some_other_field: "foo"}

      expected =
        {:error,
         %{
           [:some_other_field] => "is not allowed",
           [:nested, :my_str] => "must be a string",
           [:nested, :my_int] => "is required",
           [:nested, :my_bool] => "must be a boolean"
         }}

      assert Spec.validate(map, exclusive_spec) == expected
    end
  end

  describe "Spec.Boolean" do
    test "creates a boolean spec" do
      assert Bool.new() == %Bool{nullable: false}
      assert Bool.new(nullable: true) == %Bool{nullable: true}
    end

    test "validate with a boolean Spec" do
      spec = Bool.new()
      assert :ok = Spec.validate(false, spec)
      assert {:error, "must be a boolean"} = Spec.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, spec)
      assert :ok = Spec.validate(nil, Bool.new(nullable: true))
    end
  end

  describe "Spec.Decimal" do
    # @tag :it
    test "creates a decimal spec" do
      default_error_message = "must be a decimal-formatted string"
      assert Dec.new() == %Dec{error_message: default_error_message}

      assert Dec.new(gt: 5, lt: "10.01") == %Dec{
               gt: Decimal.new("5"),
               lt: Decimal.new("10.01"),
               error_message: default_error_message <> " greater than 5 and less than 10.01"
             }

      assert Dec.new(gte: 5, lte: "10.01") == %Dec{
               gte: Decimal.new("5"),
               lte: Decimal.new("10.01"),
               error_message:
                 default_error_message <>
                   " greater than or equal to 5 and less than or equal to 10.01"
             }

      # overwrite the default get_error_message function 
      get_error_message = fn spec -> "gotta be at least #{spec.gte} and at most #{spec.lte}" end

      assert Dec.new(gte: 1, lte: 5, get_error_message: get_error_message) == %Dec{
               gte: Decimal.new("1"),
               lte: Decimal.new("5"),
               error_message: "gotta be at least 1 and at most 5",
               get_error_message: get_error_message
             }

      Enum.each(@comparision_fields, fn comp ->
        assert_raise SpecError,
                     "#{inspect(comp)} must be a Decimal, a decimal-formatted string, or an integer",
                     fn ->
                       Dec.new([{comp, "f00py"}])
                     end
      end)

      assert_raise SpecError, "cannot use both :gt and :gte", fn ->
        Dec.new(gt: 5, gte: 3)
      end

      assert_raise SpecError, "cannot use both :lt and :lte", fn ->
        Dec.new(lt: 5, lte: 3)
      end

      for lower <- [:gt, :gte], upper <- [:lt, :lte] do
        assert_raise SpecError, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          Dec.new([{lower, 5}, {upper, 4}])
        end

        assert_raise SpecError, "#{inspect(lower)} must be less than #{inspect(upper)}", fn ->
          Dec.new([{lower, 5}, {upper, 5}])
        end
      end

      assert_raise SpecError, ":max_decimal_places must be a positive integer", fn ->
        Dec.new(max_decimal_places: "3")
      end

      assert_raise SpecError, ":max_decimal_places must be a positive integer", fn ->
        Dec.new(max_decimal_places: -3)
      end
    end

    test "validates a decimal, basic test" do
      spec = assert Dec.new()

      assert :ok = Spec.validate("4", spec)
      assert :ok = Spec.validate(" 4 ", spec)
      assert :ok = Spec.validate("-14", spec)
      assert :ok = Spec.validate(" -14 ", spec)
      assert :ok = Spec.validate("4.00", spec)
      assert :ok = Spec.validate("-4.00", spec)
      assert :ok = Spec.validate("-47.00", spec)
      assert :ok = Spec.validate(".47", spec)
      assert :ok = Spec.validate(" .47 ", spec)
      assert :ok = Spec.validate("-.47", spec)
      assert :ok = Spec.validate(" -.47 ", spec)
      assert {:error, _} = Spec.validate("foo", spec)
      assert {:error, _} = Spec.validate("1.1.", spec)
      assert {:error, _} = Spec.validate(".1.1", spec)
      assert {:error, _} = Spec.validate(" ", spec)
      assert {:error, _} = Spec.validate(".", spec)
      assert {:error, _} = Spec.validate("..", spec)
      assert {:error, _} = Spec.validate(1, spec)
      assert {:error, _} = Spec.validate(Decimal.new(4), spec)
      assert {:error, _} = Spec.validate(nil, spec)
    end

    test "a decimal spec with exclusive bounds" do
      spec = assert Dec.new(gt: 1, lt: 3)
      assert {:error, _} = Spec.validate("1", spec)
      assert :ok = Spec.validate("2", spec)
      assert {:error, _} = Spec.validate("3", spec)
    end

    test "a decimal spec with inclusive bounds" do
      spec = assert Dec.new(gte: 1, lte: 3)
      assert {:error, _} = Spec.validate("0.999", spec)
      assert :ok = Spec.validate("1", spec)
      assert :ok = Spec.validate("2", spec)
      assert :ok = Spec.validate("3", spec)
      assert {:error, _} = Spec.validate("3.001", spec)
    end

    @tag :it
    test "a decimal spec with max_decimal_places" do
      spec = assert Dec.new(max_decimal_places: 2)
      assert :ok = Spec.validate("1.0", spec)
      assert :ok = Spec.validate("1.00", spec)
      assert {:error, _} = Spec.validate("1.000", spec)
    end
  end


  describe "Spec.String" do
    test "creates a string spec" do
      a_regex = ~r/^\d+$/
      assert Str.new() == %Str{nullable: false}
      assert Str.new(nullable: false) == %Str{nullable: false}
      assert Str.new(regex: a_regex) == %Str{nullable: false, regex: a_regex}
      assert Str.new(one_of: ["foo", "bar"]) == %Str{nullable: false, one_of: ["foo", "bar"]}

      assert Str.new(one_of_ci: ["foo", "bar"]) == %Str{
               nullable: false,
               one_of_ci: ["foo", "bar"]
             }

      assert %Str{nullable: false, and: and_fn} =
               Str.new(nullable: false, and: fn str -> String.contains?(str, "x") end)

      assert is_function(and_fn, 1)

      assert_raise SpecError, ":and must be a 1-arity function, got \"foo\"", fn ->
        Str.new(nullable: false, and: "foo")
      end

      assert_raise SpecError, ~r/and must be a 1-arity function, got/, fn ->
        Str.new(nullable: false, and: fn _x, _y -> nil end)
      end

      assert_raise SpecError, ":nullable must be a boolean, got \"foo\"", fn ->
        Str.new(nullable: "foo")
      end

      assert_raise SpecError, ":foo is not a field of Dammit.Spec.String", fn ->
        Str.new(foo: "bar")
      end

      assert_raise SpecError, ":regex must be a Regex", fn ->
        Str.new(regex: "bar")
      end

      assert_raise SpecError, ":one_of must be a non-empty list of strings", fn ->
        Str.new(one_of: "foo")
      end

      assert_raise SpecError, ":one_of must be a non-empty list of strings", fn ->
        Str.new(one_of: [])
      end

      assert_raise SpecError, ":one_of_ci must be a non-empty list of strings", fn ->
        Str.new(one_of_ci: "foo")
      end

      assert_raise SpecError, ":one_of_ci must be a non-empty list of strings", fn ->
        Str.new(one_of_ci: [])
      end

      assert_raise SpecError, "cannot use both :regex and :one_of_ci", fn ->
        Str.new(one_of_ci: ["foo"], regex: a_regex)
      end

      assert_raise SpecError, "cannot use both :regex and :one_of", fn ->
        Str.new(one_of: ["foo"], regex: a_regex)
      end

      assert_raise SpecError, "cannot use both :one_of and :one_of_ci", fn ->
        Str.new(one_of: ["foo"], one_of_ci: ["foo"])
      end
    end

    test "validates values" do
      spec = Str.new()
      assert :ok = Spec.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, spec)
      assert {:error, "must be a string"} = Spec.validate(5, spec)

      nullable_spec = Str.new(nullable: true)
      assert :ok = Spec.validate("foo", nullable_spec)
      assert :ok = Spec.validate(nil, nullable_spec)

      re_spec = Str.new(regex: ~r/^\d+$/)
      assert :ok = Spec.validate("1", re_spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, re_spec)

      and_spec = Str.new(nullable: false, and: fn str -> String.contains?(str, "x") end)
      assert :ok = Spec.validate("box", and_spec)
      assert {:error, "invalid"} = Spec.validate("bocks", and_spec)

      nullable_and_spec = Str.new(nullable: true, and: fn str -> String.contains?(str, "x") end)
      assert :ok = Spec.validate(nil, nullable_and_spec)
      assert {:error, "invalid"} = Spec.validate("bocks", nullable_and_spec)

      # TODO: implement and test min_len, max_len,
      one_of_spec = Str.new(one_of: ["foo", "bar"])
      assert :ok = Spec.validate("foo", one_of_spec)

      assert {:error, "must be a case-sensative match for one of: foo, bar"} =
               Spec.validate("farts", one_of_spec)

      one_of_ci_spec = Str.new(one_of_ci: ["foo", "BAR"])
      assert :ok = Spec.validate("fOo", one_of_ci_spec)
      assert :ok = Spec.validate("BaR", one_of_ci_spec)

      assert {:error, "must be a case-insensative match for one of: foo, bar"} =
               Spec.validate("farts", one_of_ci_spec)
    end

    test "various allowed return vals for and_fn" do
      ret_ok = fn str ->
        if String.contains?(str, "x"), do: :ok, else: {:error, "need an x"}
      end

      assert :ok = Spec.validate("box", Str.new(and: ret_ok))
      assert {:error, "need an x"} = Spec.validate("bo", Str.new(and: ret_ok))

      ret_bool = &String.contains?(&1, "x")
      assert :ok = Spec.validate("box", Str.new(and: ret_bool))

      assert {:error, "no good"} = Spec.validate("bo", Str.new(and: fn _str -> "no good" end))
    end

    # test "creates a string spec with enum_vals" do
    #   enum_vals = ["a", "b"]

    #   assert string(enum_vals: enum_vals) == %StringSpec{
    #            nullable: false,
    #            required: false,
    #            enum_vals: enum_vals
    #          }

    #   assert string(required: true, nullable: true, case_insensative: true, enum_vals: enum_vals) ==
    #            %StringSpec{
    #              nullable: true,
    #              required: true,
    #              enum_vals: enum_vals,
    #              case_insensative: true
    #            }

    #     assert %StringSpec{and: and_fn} = string(and: fn it -> String.length(it) > 4 end)
    #     assert is_function(and_fn)
    #   end

    #   test "creates a string spec with regex" do
    #     regex = ~r/foo/

    #     assert string(regex: regex) == %StringSpec{
    #              nullable: false,
    #              required: false,
    #              regex: regex
    #            }
    #   end

    #   test "raises if given bad opts" do
    #     fun_name = "Dammit.StringSpec.string/1"

    #     assert_raise SpecError, "for #{fun_name}, :required must be a boolean", fn ->
    #       string(required: "foo")
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :nullable must be a boolean", fn ->
    #       string(nullable: nil)
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :enum_vals must be a list", fn ->
    #       string(enum_vals: "foo")
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :enum_vals cannot be empty", fn ->
    #       string(enum_vals: [])
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :case_insensative must be a boolean", fn ->
    #       string(enum_vals: ["1", "2"], case_insensative: "foo")
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :enum_vals can only contain strings", fn ->
    #       string(case_insensative: true, enum_vals: [:ea, 1])
    #     end

    #     assert_raise SpecError, "for #{fun_name}, :regex must be a Regex", fn ->
    #       string(regex: "foo")
    #     end

    #     assert_raise SpecError,
    #                  "for #{fun_name}, :enum_vals and :regex are not allowed together",
    #                  fn ->
    #                    string(regex: ~r/foo/, enum_vals: ["a", "b"])
    #                  end

    #     assert_raise SpecError,
    #                  "for #{fun_name}, :and must be a function",
    #                  fn ->
    #                    string(and: "something")
    #                  end

    #     assert_raise SpecError,
    #                  "for #{fun_name}, :fart is not an option",
    #                  fn ->
    #                    string(fart: "something")
    #                  end
    #   end
    # end

    # describe "StringSpec.conform/1" do
    #   test "checks a value against a StringSpec" do
    #     assert conform("yes", string()) == :ok
    #     assert conform([], string()) == {:error, "must be a string"}
    #     assert conform(nil, string(nullable: true)) == :ok
    #     assert conform(nil, string()) == {:error, "cannot be nil"} end

    #   test "checks a values against enum_vals" do
    #     enum_vals = ~w[a b]
    #     assert conform("a", string(enum_vals: enum_vals)) == :ok

    #     assert conform("c", string(enum_vals: enum_vals)) ==
    #              {:error, "must be one of: a, b (case sensative)"}

    #     assert conform("A", string(enum_vals: enum_vals)) ==
    #              {:error, "must be one of: a, b (case sensative)"}

    #     assert conform("A", string(enum_vals: enum_vals, case_insensative: true)) == :ok

    #     assert conform("c", string(enum_vals: enum_vals, case_insensative: true)) ==
    #              {:error, "must be one of: a, b (case insensative)"}
    #   end

    #   test "checks a value against a Regex" do
    #     regex = ~r/^foo/

    #     assert conform("fool", string(regex: regex)) == :ok
    #     assert conform("ofoo", string(regex: regex)) == {:error, "must match regex: ^foo"}
    #   end

    #   test "checks a value against a StringSpec and against an 'and' function" do
    #     assert conform("fool", string(and: &(String.length(&1) < 10))) == :ok

    #     assert conform(
    #              "fool",
    #              string(
    #                and: fn it ->
    #                  if String.length(it) < 10, do: :ok, else: {:error, "too long"}
    #                end
    #              )
    #            ) == :ok

    #     assert conform("fool", string(and: &(String.length(&1) < 3))) == {:error, "invalid"}

    #     assert conform(
    #              "fool",
    #              string(
    #                and: fn it ->
    #                  if String.length(it) < 3, do: :ok, else: {:error, "too long"}
    #                end
    #              )
    #            ) == {:error, "too long"}

    #     assert conform(
    #              "fool",
    #              string(
    #                and: fn it ->
    #                  if String.length(it) < 3, do: :ok, else: "too long"
    #                end
    #              )
    #            ) == {:error, "too long"}
    #   end

    #   test "checks the 'and' only if the other validations pass" do
    #     assert conform(4, string(and: &(String.length(&1) < 10))) == {:error, "must be a string"}
    #     assert conform(nil, string(and: &(String.length(&1) < 10))) == {:error, "cannot be nil"}
    #   end
  end
end
