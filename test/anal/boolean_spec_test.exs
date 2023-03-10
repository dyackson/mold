defmodule Anal.BooleanSpecTest do
  alias Anal.Spec
  alias Anal.BooleanSpec

  use ExUnit.Case

  describe "BooleanSpec.new/1" do
    test "creates a boolean spec" do
      assert BooleanSpec.new() == %BooleanSpec{can_be_nil: false}
      assert BooleanSpec.new(can_be_nil: true) == %BooleanSpec{can_be_nil: true}
    end

    test "validate with a boolean Spec" do
      spec = BooleanSpec.new()
      assert :ok = Spec.validate(false, spec)
      assert {:error, "must be a boolean"} = Spec.validate("foo", spec)
      assert {:error, "cannot be nil"} = Spec.validate(nil, spec)
      assert :ok = Spec.validate(nil, BooleanSpec.new(can_be_nil: true))
    end
  end
end
