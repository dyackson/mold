defmodule AnalTest do
  use ExUnit.Case
  doctest Anal

  test "greets the world" do
    assert Anal.hello() == :world
  end
end
