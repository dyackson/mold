defmodule PayloadValidator.SpexTest do
  alias PayloadValidator.SpecError
  alias PayloadValidator.Spex
  alias PayloadValidator.Spex.String, as: Str
  alias PayloadValidator.Spex.Boolean, as: Bool
  alias PayloadValidator.Spex.Integer, as: Int

  # import Str

  use ExUnit.Case

  @comparision_fields [:gt, :lt, :gte, :lte]

  # TODO: figure out what this is
  doctest PayloadValidator

  describe "Spex.List" do
    test "creates a list spec" do
      assert Spex.List.new(of: Str.new()) == %Spex.List{
               nullable: false,
               of: %Str{},
               min_len: nil,
               max_len: nil,
               and: nil
             }

      assert %Spex.List{
               nullable: true,
               of: %Str{},
               min_len: 1,
               max_len: 10,
               and: and_fn
             } =
               Spex.List.new(
                 nullable: true,
                 of: Str.new(),
                 min_len: 1,
                 max_len: 10,
                 and: &(rem(&1, 2) == 0)
               )

      assert is_function(and_fn, 1)

      assert_raise SpecError, ":of is required in PayloadValidator.Spex.List", fn ->
        Spex.List.new()
      end

      assert_raise SpecError, ":of must be a spec", fn ->
        Spex.List.new(of: "foo")
      end

      assert_raise SpecError, ":and must be a 1-arity function, got \"foo\"", fn ->
        Spex.List.new(of: Str.new(), and: "foo")
      end

      assert_raise SpecError, ":min_len must be a non-negative integer", fn ->
        Spex.List.new(of: Str.new(), min_len: "foo")
      end

      assert_raise SpecError, ":max_len must be a non-negative integer", fn ->
        Spex.List.new(of: Str.new(), max_len: -4)
      end

      assert_raise SpecError, ":min_len cannot be greater than :max_len", fn ->
        Spex.List.new(of: Str.new(), max_len: 1, min_len: 2)
      end

      assert %Spex.List{min_len: 1, max_len: nil} = Spex.List.new(of: Str.new(), min_len: 1)

      assert %Spex.List{min_len: nil, max_len: 1} = Spex.List.new(of: Str.new(), max_len: 1)
    end

    test "validates using a list spec" do
      spec = Spex.List.new(of: Str.new())

      assert :ok = Spex.validate([], spec)
      assert Spex.validate(nil, spec) == {:error, "cannot be nil"}

      min_len_spec = Spex.List.new(of: Str.new(), min_len: 1)
      assert Spex.validate([], min_len_spec) == {:error, "length must be at least 1"}
      assert :ok = Spex.validate(["a"], min_len_spec)
      assert :ok = Spex.validate(["a", "b"], min_len_spec)

      max_len_spec = Spex.List.new(of: Str.new(), max_len: 1)
      assert :ok = Spex.validate(["a"], max_len_spec)
      assert :ok = Spex.validate(["a"], max_len_spec)
      assert Spex.validate(["a", "b"], max_len_spec) == {:error, "length cannot exceed 1"}

      spec = Spex.List.new(of: Str.new())
      assert :ok = Spex.validate(["a", "b"], spec)

      assert Spex.validate([1, "a", true], spec) ==
               {:error, %{[0] => "must be a string", [2] => "must be a string"}}

      and_fn = fn ints ->
        sum = Enum.sum(ints)
        if sum > 5, do: "sum is too high", else: :ok
      end

      and_spec = Spex.List.new(of: Int.new(nullable: false), and: and_fn)

      assert :ok = Spex.validate([1, 0, 0, 0, 0, 3], and_spec)
      assert Spex.validate([1, 6], and_spec) == {:error, "sum is too high"}
    end
  end

  describe "Spex.Map" do
    test "creates a map spec" do
      assert Spex.Map.new() == %Spex.Map{
               nullable: false,
               required: %{},
               optional: %{},
               exclusive: false,
               and: nil
             }

      assert Spex.Map.new(nullable: true) == %Spex.Map{nullable: true}
    end

    test "validate with a map Spec" do
      spec =
        Spex.Map.new(
          required: [my_str: Str.new(), my_int: Int.new()],
          optional: %{my_bool: Bool.new(nullable: true)}
        )

      assert :ok = Spex.validate(%{my_str: "foo", my_int: 1}, spec)
      assert :ok = Spex.validate(%{my_str: "foo", my_int: 1, my_bool: true}, spec)
      assert :ok = Spex.validate(%{my_str: "foo", my_int: 1, my_bool: nil}, spec)
      assert :ok = Spex.validate(%{my_str: "foo", my_int: 1, some_other_field: "foopy"}, spec)

      assert Spex.validate(%{my_str: "foo"}, spec) == {:error, %{[:my_int] => "is required"}}

      assert Spex.validate(%{}, spec) ==
               {:error, %{[:my_int] => "is required", [:my_str] => "is required"}}

      assert Spex.validate(%{my_str: "foo", my_int: "foo"}, spec) ==
               {:error, %{[:my_int] => "must be an integer"}}

      assert Spex.validate(%{my_str: 1, my_int: "foo"}, spec) ==
               {:error, %{[:my_int] => "must be an integer", [:my_str] => "must be a string"}}

      assert Spex.validate(%{my_str: 1, my_int: "foo"}, spec) ==
               {:error, %{[:my_int] => "must be an integer", [:my_str] => "must be a string"}}

      assert Spex.validate(%{my_str: 1, my_int: "foo", my_bool: "foo"}, spec) ==
               {:error,
                %{
                  [:my_int] => "must be an integer",
                  [:my_str] => "must be a string",
                  [:my_bool] => "must be a boolean"
                }}

      exclusive_spec = Map.put(spec, :exclusive, true)

      assert Spex.validate(%{my_str: "foo", my_int: 1, some_other_field: "foopy"}, exclusive_spec) ==
               {:error, %{[:some_other_field] => "is not allowed"}}

      empty_map_spec = Spex.Map.new()

      assert :ok = Spex.validate(%{}, empty_map_spec)
      assert :ok = Spex.validate(%{some_other_field: [1, 2, 3]}, empty_map_spec)
      assert {:error, "cannot be nil"} = Spex.validate(nil, empty_map_spec)

      assert Spex.validate(
               %{some_other_field: [1, 2, 3]},
               Map.put(empty_map_spec, :exclusive, true)
             ) ==
               {:error, %{[:some_other_field] => "is not allowed"}}
    end

    test "validate a nested map spec" do
      nested_spec =
        Spex.Map.new(
          required: %{my_str: Str.new(), my_int: Int.new()},
          optional: [my_bool: Bool.new(nullable: true)]
        )

      spec = Spex.Map.new(required: [nested: nested_spec])

      :ok = Spex.validate(%{nested: %{my_int: 1, my_str: "foo"}}, spec)

      assert Spex.validate(%{nested: %{my_str: "foo"}}, spec) ==
               {:error, %{[:nested, :my_int] => "is required"}}

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

      assert Spex.validate(map, exclusive_spec) == expected
    end
  end

  describe "Spex.Boolean" do
    test "creates a boolean spec" do
      assert Bool.new() == %Bool{nullable: false}
      assert Bool.new(nullable: true) == %Bool{nullable: true}
    end

    test "validate with a boolean Spec" do
      spec = Bool.new()
      assert :ok = Spex.validate(false, spec)
      assert {:error, "must be a boolean"} = Spex.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spex.validate(nil, spec)
      assert :ok = Spex.validate(nil, Bool.new(nullable: true))
    end
  end

  describe "Spex.Integer" do
    test "creates as integer spec" do
      assert Int.new(nullable: true) == %Int{nullable: true}
      assert Int.new() == %Int{nullable: false}

      Enum.each(@comparision_fields, fn comp ->
        assert Int.new([{comp, 5}]) == Map.put(%Int{}, comp, 5)

        assert_raise SpecError, ":#{comp} must be an integer", fn ->
          Int.new([{comp, "5"}])
        end
      end)

      assert_raise SpecError, "cannot use both :gt and :gte", fn ->
        Int.new(gt: 5, gte: 3)
      end

      assert_raise SpecError, "cannot use both :lt and :lte", fn ->
        Int.new(lt: 5, lte: 3)
      end

      # lt/gt
      assert_raise SpecError, ":lt must be greater than :gt", fn ->
        Int.new(lt: 0, gt: 3)
      end

      assert_raise SpecError, ":lt must be greater than :gt", fn ->
        Int.new(lt: 0, gt: 0)
      end

      # lte/gt
      assert_raise SpecError, ":lte must be greater than :gt", fn ->
        Int.new(lte: 0, gt: 3)
      end

      assert_raise SpecError, ":lte must be greater than :gt", fn ->
        Int.new(lte: 0, gt: 0)
      end

      # lt/gte
      assert_raise SpecError, ":lt must be greater than :gte", fn ->
        Int.new(lt: 0, gte: 3)
      end

      assert_raise SpecError, ":lt must be greater than :gte", fn ->
        Int.new(lt: 0, gte: 0)
      end

      # lte/gte
      assert_raise SpecError, ":lte must be greater than or equal to :gte", fn ->
        Int.new(lte: 0, gte: 3)
      end

      assert %Int{lte: 0, gte: 0} = Int.new(lte: 0, gte: 0)
    end

    test "validate with an integer Spec" do
      spec = Int.new()
      assert :ok = Spex.validate(9, spec)
      assert {:error, "must be an integer"} = Spex.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spex.validate(nil, spec)
      assert :ok = Spex.validate(nil, Int.new(nullable: true))

      bounds_spec = Int.new(gt: 0, lt: 10)
      assert :ok = Spex.validate(5, bounds_spec)
      assert {:error, "must be less than 10"} = Spex.validate(10, bounds_spec)
      assert {:error, "must be greater than 0"} = Spex.validate(0, bounds_spec)

      bounds_spec = Int.new(gte: 0, lte: 10)
      assert :ok = Spex.validate(5, bounds_spec)
      assert :ok = Spex.validate(0, bounds_spec)
      assert :ok = Spex.validate(10, bounds_spec)
      assert {:error, "must be less than or equal to 10"} = Spex.validate(11, bounds_spec)
      assert {:error, "must be greater than or equal to 0"} = Spex.validate(-1, bounds_spec)
    end
  end

  describe "Spex.String" do
    test "creates a string spec" do
      assert Str.new() == %Str{nullable: false}
      assert Str.new(nullable: false) == %Str{nullable: false}
      assert Str.new(regex: ~r/^\d+$/) == %Str{nullable: false, regex: ~r/^\d+$/}

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

      assert_raise SpecError, ":foo is not a field of PayloadValidator.Spex.String", fn ->
        Str.new(foo: "bar")
      end

      assert_raise SpecError, ":regex must be a Regex", fn ->
        Str.new(regex: "bar")
      end
    end

    test "validates values" do
      spec = Str.new()
      assert :ok = Spex.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spex.validate(nil, spec)
      assert {:error, "must be a string"} = Spex.validate(5, spec)

      nullable_spec = Str.new(nullable: true)
      assert :ok = Spex.validate("foo", nullable_spec)
      assert :ok = Spex.validate(nil, nullable_spec)

      re_spec = Str.new(regex: ~r/^\d+$/)
      assert :ok = Spex.validate("1", re_spec)
      assert {:error, "cannot be nil"} = Spex.validate(nil, re_spec)

      and_spec = Str.new(nullable: false, and: fn str -> String.contains?(str, "x") end)
      assert :ok = Spex.validate("box", and_spec)
      assert {:error, "invalid"} = Spex.validate("bocks", and_spec)

      nullable_and_spec = Str.new(nullable: true, and: fn str -> String.contains?(str, "x") end)
      assert :ok = Spex.validate(nil, nullable_and_spec)
      assert {:error, "invalid"} = Spex.validate("bocks", nullable_and_spec)

      # TODO: implement and test min_len, max_len, and enum_vals
    end

    test "various allowed return vals for and_fn" do
      ret_ok = fn str ->
        if String.contains?(str, "x"), do: :ok, else: {:error, "need an x"}
      end

      assert :ok = Spex.validate("box", Str.new(and: ret_ok))
      assert {:error, "need an x"} = Spex.validate("bo", Str.new(and: ret_ok))

      ret_bool = &String.contains?(&1, "x")
      assert :ok = Spex.validate("box", Str.new(and: ret_bool))

      assert {:error, "no good"} = Spex.validate("bo", Str.new(and: fn _str -> "no good" end))
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
    #     fun_name = "PayloadValidator.StringSpec.string/1"

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
