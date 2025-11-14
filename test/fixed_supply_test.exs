defmodule FixedSupplyTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.FixedSupply

  # Examples.EScheme.__after_compile__([], [])

  test "Run the examples" do
    Examples.EFixedSupply.compute_related_fixed_supply()
    # Examples.EFixedSupply.interpret_fixed_supply_elixir()
    # Examples.EFixedSupply.interpret_fixed_supply_scheme()
    # Examples.EFixedSupply.interpret_quantity_elixir()
    # Examples.EFixedSupply.interpret_quantity_scheme()
  end
end
