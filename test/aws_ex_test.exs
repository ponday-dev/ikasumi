defmodule AWSTest do
  use ExUnit.Case
  doctest AWS

  test "greets the world" do
    assert AWS.hello() == :world
  end
end
