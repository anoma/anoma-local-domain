defmodule ActionTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.Action

  # Examples.EScheme.__after_compile__([], [])

  test "Run the examples" do
    Examples.EAction.transacted_inc()
    Examples.EAction.unit_as_scheme()
    Examples.EAction.run_inc_unit()
    Examples.EAction.interpret_inc_unit()
  end
end
