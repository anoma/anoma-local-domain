defmodule Anoma.LocalDomain.NegotiateTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.Negotiate

  test "greets the world" do
    assert Anoma.LocalDomain.Negotiate.hello() == :world
  end
end
