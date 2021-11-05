defmodule MysocketTest do
  use ExUnit.Case
  doctest Mysocket

  test "greets the world" do
    assert Mysocket.hello() == :world
  end
end
