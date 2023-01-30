defmodule DammitTest do
  use ExUnit.Case
  doctest Dammit

  test "greets the world" do
    assert Dammit.hello() == :world
  end
end
