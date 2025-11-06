defmodule JoogiTest do
  use ExUnit.Case
  doctest Joogi

  test "greets the world" do
    assert Joogi.hello() == :world
  end
end
