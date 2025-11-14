defmodule SchemeTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.Scheme

  # Examples.EScheme.__after_compile__([], [])

  test "Run the examples" do
    Examples.EScheme.list()
    Examples.EScheme.dict()
    Examples.EScheme.lambda()
    Examples.EScheme.apply()
    Examples.EScheme.native_plus()
    Examples.EScheme.native_nth()
    Examples.EScheme.map()
    Examples.EScheme.apply_map()
    Examples.EScheme.filter()
    Examples.EScheme.nthcdr()
    Examples.EScheme.take()
    Examples.EScheme.get()
    Examples.EScheme.put()
    Examples.EScheme.car()
    Examples.EScheme.cdr()

    Examples.EScheme.fn_to_scheme()
    Examples.EScheme.struct_to_scheme()
    Examples.EScheme.if_to_scheme()
  end
end
