defmodule CaspaxTest do
  use ExUnit.Case
  doctest Caspax

  test "greets the world" do
    assert Caspax.hello() == :world
  end
end
