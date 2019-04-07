defmodule LeprechaunTest do
  use ExUnit.Case
  doctest Leprechaun

  test "greets the world" do
    assert Leprechaun.hello() == :world
  end
end
