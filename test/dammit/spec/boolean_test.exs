defmodule Dammit.BooleanTest do
  alias Dammit.SpecError
  alias Dammit.Spec
  alias Dammit.Spec.Boolean, as: Bool

  use ExUnit.Case

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
end
