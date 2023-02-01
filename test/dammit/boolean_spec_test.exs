defmodule Dammit.BooleanSpecTest do
  alias Dammit.SpecError
  alias Dammit.Spec
  alias Dammit.BooleanSpec

  use ExUnit.Case

  describe "BooleanSpec.new/1" do
    test "creates a boolean spec" do
      assert BooleanSpec.new() == %BooleanSpec{nullable: false}
      assert BooleanSpec.new(nullable: true) == %BooleanSpec{nullable: true}
    end

    test "validate with a boolean Spec" do
      spec = BooleanSpec.new()
      assert :ok = Spec.validate(false, spec)
      assert {:error, "must be a boolean"} = Spec.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, spec)
      assert :ok = Spec.validate(nil, BooleanSpec.new(nullable: true))
    end
  end
end
