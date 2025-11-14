defmodule ResourceTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.Resource

  # Examples.EScheme.__after_compile__([], [])

  test "Run the examples" do
    Examples.EResource.obj_to_resource_int()
    Examples.EResource.compile_resource_logic()
    Examples.EResource.scheme_resource_int()
    Examples.EResource.obj_to_resource_built_in()
    Examples.EResource.scheme_resource_built_in()
    Examples.EResource.obj_to_resource_fn()
    Examples.EResource.scheme_resource_fn()

    Examples.EResource.scheme_int()
    Examples.EResource.scheme_built_in()
    Examples.EResource.scheme_fn()
  end
end
