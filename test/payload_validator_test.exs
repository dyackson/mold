defmodule PayloadValidatorTest do
  use ExUnit.Case
  doctest PayloadValidator

  test "greets the world" do
    assert PayloadValidator.hello() == :world
  end
end
