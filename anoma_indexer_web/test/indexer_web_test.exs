defmodule IndexerWebTest do
  use ExUnit.Case
  doctest IndexerWeb

  test "greets the world" do
    assert IndexerWeb.hello() == :world
  end
end
