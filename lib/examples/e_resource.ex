defmodule Examples.EResource do
  require ExUnit.Assertions
  import ExUnit.Assertions

  alias Anoma.LocalDomain.Resource
  alias Anoma.LocalDomain.ObjToResource

  def obj_to_resource_int() do
    r = ObjToResource.obj_to_resource(1)
    assert r.quantity == 1
    r
  end

  def compile_resource_logic() do
    r = Resource.compile_logic(ObjToResource.obj_to_resource(1))
    assert is_function(r)
    r
  end

  def scheme_resource_int() do
    r = ObjToResource.scheme(obj_to_resource_int())

    assert r["logic"] ==
             [
               :lambda,
               [:obj, :_instance, :_consumedp],
               [:is_integer, [:get, :obj, "data"]]
             ]

    r
  end

  def obj_to_resource_built_in() do
    r = ObjToResource.obj_to_resource(&:erlang.+/2)
    assert r.quantity == 0
    r
  end

  def scheme_resource_built_in() do
    r = ObjToResource.scheme(obj_to_resource_built_in())
    assert Map.get(r, "data") == :+
    r
  end

  def obj_to_resource_fn() do
    r = ObjToResource.obj_to_resource(&Examples.EScheme.inc/1)
    assert r.data == (&Examples.EScheme.inc/1)
    assert r.quantity == 0
    r
  end

  def scheme_resource_fn() do
    r = ObjToResource.scheme(obj_to_resource_fn())
    r
  end

  def scheme_int() do
    r = ObjToResource.scheme(1)
    assert r == 1
    r
  end

  def scheme_built_in() do
    r = ObjToResource.scheme(&Kernel.+/2)
    assert r == :+
    r
  end

  def scheme_fn() do
    :inc =
      ObjToResource.scheme(&Examples.EScheme.inc/1)

    :inc
  end
end
