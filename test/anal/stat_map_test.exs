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

    test ":exclusive is true but no fields defined" do
      assert_raise(SpecError, ":required and/or :optional must be used if :exclusive is true", fn ->
        Anal.prep!(%Rec{exclusive: true})
      end)
    end



    #   assert_raise(SpecError, "cannot use both :one_of_ci and :max_length", fn ->
    #     Anal.prep!(%Str{max_length: 5, one_of_ci: ["fool", "bart"]})
    #   end)
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
#                exclusive: false,
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

#       exclusive_spec = Map.put(spec, :exclusive, true)

#       assert Spec.validate(%{my_str: "foo", my_int: 1, some_other_field: "foopy"}, exclusive_spec) ==
#                {:error, %{[:some_other_field] => "is not allowed"}}

#       empty_map_spec = StatMap.new()

#       assert :ok = Spec.validate(%{}, empty_map_spec)
#       assert :ok = Spec.validate(%{some_other_field: [1, 2, 3]}, empty_map_spec)
#       assert {:error, "cannot be nil"} = Spec.validate(nil, empty_map_spec)

#       assert Spec.validate(
#                %{some_other_field: [1, 2, 3]},
#                Map.put(empty_map_spec, :exclusive, true)
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
#       exclusive_spec = Map.put(spec, :exclusive, true)

#       map = %{nested: %{my_str: 1, my_bool: 1}, some_other_field: "foo"}

#       expected =
#         {:error,
#          %{
#            [:some_other_field] => "is not allowed",
#            [:nested, :my_str] => "must be a string",
#            [:nested, :my_int] => "is required",
#            [:nested, :my_bool] => "must be a boolean"
#          }}

#       assert Spec.validate(map, exclusive_spec) == expected
#     end
#   end
# end
