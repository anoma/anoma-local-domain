defmodule Examples.EResource do
  require ExUnit.Assertions
  import ExUnit.Assertions

  # alias Anoma.LocalDomain.Resource
  alias Anoma.LocalDomain.ObjToResource

  def inc(x) do
    x + 1
  end

  # This, as well as putting a native in the scheme environment, both work
  def scheme_fn(:inc) do
    ["lambda", ["x"], ["+", "x", 1]]
  end

  def obj_to_resource_int() do
    r = ObjToResource.obj_to_resource(1)
    assert r.quantity == 1
    r
  end

  def obj_to_resource_built_in() do
    r = ObjToResource.obj_to_resource(&Kernel.+/2)
    r
  end

  def obj_to_resource_fn() do
    r = ObjToResource.obj_to_resource(&Examples.EResource.inc/1)
    assert r.data == (&Examples.EResource.inc/1)
    assert r.quantity == 0
    r
  end

  def scheme_int() do
    r = ObjToResource.scheme(1)
    r
  end

  def scheme_built_in() do
    r = ObjToResource.scheme(&Kernel.+/2)
    r
  end

  def scheme_fn() do
    r = ObjToResource.scheme(&inc/1)
    r
  end
end
