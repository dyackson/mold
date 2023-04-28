defmodule Anal.RecTest do
  alias Anal.SpecError
  alias Anal.Rec

  use ExUnit.Case

  describe "Anal.prep! a Rec raises a SpecError when" do
    test "nil_ok? not a boolean" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Rec{nil_ok?: "yuh"})
      end)
    end

    test ":also is not an arity-1 function" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Anal.prep!(%Rec{also: &(&1 + &2)})
      end)
    end

    test ":exclusive? is not a boolean" do
      assert_raise(
        SpecError,
        ":exclusive? must be a boolean",
        fn ->
          Anal.prep!(%Rec{exclusive?: "barf"})
        end
      )
    end

    test ":exclusive? is true but no fields defined" do
      assert_raise(
        SpecError,
        ":required and/or :optional must be used if :exclusive? is true",
        fn ->
          Anal.prep!(%Rec{exclusive?: true})
        end
      )
    end

    @tag :this
    test ":optional or :required is not a spec map" do
      [
        "goo",
        [],
        [key: "word"],
        9,
        nil,
        %{atom_key: %Anal.Str{}},
        %{"good" => "bad"},
        %{"good" => %{can_be_nil: true}}
      ]
      |> Enum.each(fn bad_val ->
        assert_raise(
          SpecError,
          ":optional must be a Map with string keys and Anal protocol-implementing values",
          fn -> Anal.prep!(%Rec{optional: bad_val}) end
        )

        assert_raise(
          SpecError,
          ":required must be a Map with string keys and Anal protocol-implementing values",
          fn -> Anal.prep!(%Rec{required: bad_val}) end
        )
      end)
    end

    test ":required and :optional field have the same key" do
      str_spec = %Anal.Str{}
      common = %{"a" => str_spec, "b" => str_spec}
      optional = Map.put(common, "c", str_spec)
      required = Map.put(common, "d", str_spec)

      assert_raise(
        SpecError,
        "the following keys were in both :optional and :required -- a, b",
        fn ->
          Anal.prep!(%Rec{optional: optional, required: required})
        end
      )
    end

    test ":optional or :required contains an invalid spec" do
      bad = %{"my_str" => %Anal.Str{min_length: -1}}

      assert_raise(
        SpecError,
        ":min_length must be a positive integer",
        fn ->
          Anal.prep!(%Rec{optional: bad})
        end
      )

      assert_raise(
        SpecError,
        ":min_length must be a positive integer",
        fn ->
          Anal.prep!(%Rec{required: bad})
        end
      )
    end
  end

  describe "Anal.prep!/1 a valid Rec" do
    test "adds a default error message" do
      assert %Rec{error_message: "must be a map"} = Anal.prep!(%Rec{})

      required = %{"r1" => %Anal.Str{}, "r2" => %Anal.Boo{}}
      optional = %{"o1" => %Anal.Str{}, "o2" => %Anal.Boo{}}

      assert %Rec{error_message: "must be a record with the required keys \"r1\", \"r2\""} =
               Anal.prep!(%Rec{required: required})

      assert %Rec{error_message: "must be a record with only the required keys \"r1\", \"r2\""} =
               Anal.prep!(%Rec{required: required, exclusive?: true})

      assert %Rec{error_message: "must be a record with the optional keys \"o1\", \"o2\""} =
               Anal.prep!(%Rec{optional: optional})

      assert %Rec{error_message: "must be a record with only the optional keys \"o1\", \"o2\""} =
               Anal.prep!(%Rec{optional: optional, exclusive?: true})

      assert %Rec{
               error_message:
                 "must be a record with the required keys \"r1\", \"r2\" and the optional keys \"o1\", \"o2\""
             } = Anal.prep!(%Rec{optional: optional, required: required})

      assert %Rec{
               error_message:
                 "must be a record with only the required keys \"r1\", \"r2\" and the optional keys \"o1\", \"o2\""
             } = Anal.prep!(%Rec{optional: optional, required: required, exclusive?: true})

      # assert %Str{
      #          error_message:
      #            "must be one of these strings (with matching case): |"Simon|", \"Garfunkel\""
      #        } = Anal.prep!(%Str{one_of: ["Simon", "Garfunkel"]})

      # assert %Str{
      #          error_message:
      #            "must be one of these strings (case doesn't have to match): \"simon\", \"garfunkel\""
      #        } = Anal.prep!(%Str{one_of_ci: ["Simon", "Garfunkel"]})

      # assert %Str{error_message: "must be a string matching the regex ~r/^\\d+$/"} =
      #          Anal.prep!(%Str{regex: ~r/^\d+$/})

      # assert %Str{error_message: "must be a string with at least 5 characters"} =
      #          Anal.prep!(%Str{min_length: 5})

      # assert %Str{error_message: "must be a string with at most 10 characters"} =
      #          Anal.prep!(%Str{max_length: 10})

      # assert %Str{error_message: "must be a string with at least 5 and at most 10 characters"} =
      #          Anal.prep!(%Str{min_length: 5, max_length: 10})
    end

    # test "accepts an error message" do
    #   assert %Str{error_message: "dammit"} = Anal.prep!(%Str{error_message: "dammit"})
    # end
  end
end

# defmodule Anal.StatMapTest do
#   alias Anal.Spec
#   alias Anal.StatMap
#   alias Anal.Str
#   alias Anal.Int
#   alias Anal.BoolSpec

#   use ExUnit.Case

#   describe "StatMap.new/1" do
#     test "creates a map spec" do
#       assert StatMap.new() == %StatMap{
#                can_be_nil: false,
#                required: %{},
#                optional: %{},
#                exclusive?: false,
#                also: nil
#              }

#       assert StatMap.new(can_be_nil: true) == %StatMap{can_be_nil: true}
#     end

#     test "validate with a map Spec" do
#       spec =
#         StatMap.new(
#           required: [my_str: Str.new(), my_int: Int.new()],
#           optional: %{my_bool: BoolSpec.new(can_be_nil: true)}
#         )

#       assert :ok = Spec.validate(%{my_str: "foo", my_int: 1}, spec)
#       assert :ok = Spec.validate(%{my_str: "foo", my_int: 1, my_bool: true}, spec)
#       assert :ok = Spec.validate(%{my_str: "foo", my_int: 1, my_bool: nil}, spec)
#       assert :ok = Spec.validate(%{my_str: "foo", my_int: 1, some_other_field: "foopy"}, spec)

#       assert Spec.validate(%{my_str: "foo"}, spec) == {:error, %{[:my_int] => "is required"}}

#       assert Spec.validate(%{}, spec) ==
#                {:error, %{[:my_int] => "is required", [:my_str] => "is required"}}

#       assert Spec.validate(%{my_str: "foo", my_int: "foo"}, spec) ==
#                {:error, %{[:my_int] => "must be an integer"}}

#       assert Spec.validate(%{my_str: 1, my_int: "foo"}, spec) ==
#                {:error, %{[:my_int] => "must be an integer", [:my_str] => "must be a string"}}

#       assert Spec.validate(%{my_str: 1, my_int: "foo"}, spec) ==
#                {:error, %{[:my_int] => "must be an integer", [:my_str] => "must be a string"}}

#       assert Spec.validate(%{my_str: 1, my_int: "foo", my_bool: "foo"}, spec) ==
#                {:error,
#                 %{
#                   [:my_int] => "must be an integer",
#                   [:my_str] => "must be a string",
#                   [:my_bool] => "must be a boolean"
#                 }}

#       exclusive?_spec = Map.put(spec, :exclusive?, true)

#       assert Spec.validate(%{my_str: "foo", my_int: 1, some_other_field: "foopy"}, exclusive?_spec) ==
#                {:error, %{[:some_other_field] => "is not allowed"}}

#       empty_map_spec = StatMap.new()

#       assert :ok = Spec.validate(%{}, empty_map_spec)
#       assert :ok = Spec.validate(%{some_other_field: [1, 2, 3]}, empty_map_spec)
#       assert {:error, "cannot be nil"} = Spec.validate(nil, empty_map_spec)

#       assert Spec.validate(
#                %{some_other_field: [1, 2, 3]},
#                Map.put(empty_map_spec, :exclusive?, true)
#              ) ==
#                {:error, %{[:some_other_field] => "is not allowed"}}
#     end

#     test "validate a nested map spec" do
#       nested_spec =
#         StatMap.new(
#           required: %{my_str: Str.new(), my_int: Int.new()},
#           optional: [my_bool: BoolSpec.new(can_be_nil: true)]
#         )

#       spec = StatMap.new(required: [nested: nested_spec])

#       :ok = Spec.validate(%{nested: %{my_int: 1, my_str: "foo"}}, spec)

#       assert Spec.validate(%{nested: %{my_str: "foo"}}, spec) ==
#                {:error, %{[:nested, :my_int] => "is required"}}

#       # exclucivity applies to nested specs
#       # TODO: allow explicit overwrite in child spec 
#       exclusive?_spec = Map.put(spec, :exclusive?, true)

#       map = %{nested: %{my_str: 1, my_bool: 1}, some_other_field: "foo"}

#       expected =
#         {:error,
#          %{
#            [:some_other_field] => "is not allowed",
#            [:nested, :my_str] => "must be a string",
#            [:nested, :my_int] => "is required",
#            [:nested, :my_bool] => "must be a boolean"
#          }}

#       assert Spec.validate(map, exclusive?_spec) == expected
#     end
#   end
# end
