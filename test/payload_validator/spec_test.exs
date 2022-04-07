defmodule PayloadValidator.SpecTest do
  alias PayloadValidator.Spec
  alias PayloadValidator.SpecBehavior

  use ExUnit.Case

  # TODO: figure out what this is
  doctest PayloadValidator

  defmodule GoodSpec do
    @behaviour SpecBehavior

    defstruct nullable: false, required: false, good: false

    @impl SpecBehavior
    def check_spec(%__MODULE__{} = spec), do: spec

    def check_spec(_), do: {:error, "not a valid spec"}

    @impl SpecBehavior
    def conform("good", %__MODULE__{good: true}), do: :ok

    def conform(_, %__MODULE__{}), do: {:error, "bad"}
  end

  defmodule BadSpec do
    @behaviour SpecBehavior

    defstruct  bad: true

    @impl SpecBehavior
    def check_spec(%__MODULE__{}), do: "should never be called"

    @impl SpecBehavior
    def conform(_, %__MODULE__{}), do: "should never be called"

  end

  describe "check_spec/1" do
    test "returns :ok for a valid spec" do
      spec = %GoodSpec{good: true}
      assert Spec.check_spec(spec) == :ok
      assert GoodSpec.conform("good", spec) == :ok
      assert GoodSpec.conform("bad", spec) == {:error, "bad"}
    end

    test "error tuple for bad spec" do
      spec = %BadSpec{}
      assert Spec.check_spec(spec) == :ok
    end
  end
end
