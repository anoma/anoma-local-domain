defmodule Anoma.LocalDomain.Resource do
  @moduledoc """
  I define the struct for ARM resources 
  """

  use TypedStruct

  typedstruct enforce: true do
    # field(:label, any())
    field(:data, any())
    field(:logic, any())
    field(:quantity, integer(), default: 0)
    field(:type, any())
  end

  def compile_logic(%Anoma.LocalDomain.Resource{logic: logic}) do
    {func, _bindings} = Code.eval_quoted(logic)
    func
  end
end

defprotocol Anoma.LocalDomain.ObjToResource do
  def obj_to_resource(x)
  def scheme(x)
  def related_use(x)
  def related_create(x)
end

defimpl Anoma.LocalDomain.ObjToResource, for: Integer do
  def obj_to_resource(x) do
    %Anoma.LocalDomain.Resource{
      data: x,
      logic:
        quote do
          fn obj, _instance, _consumedp ->
            :erlang.is_integer(Map.get(obj, :data))
          end
        end,
      quantity: 1,
      type: Integer
    }
  end

  def scheme(data) do
    data
  end

  def related_use(_data) do
    %{
      consumed: [],
      created: []
    }
  end

  def related_create(_data) do
    %{
      consumed: [],
      created: []
    }
  end
end

defimpl Anoma.LocalDomain.ObjToResource, for: Function do
  def obj_to_resource(data) do
    {:arity, arity} = Function.info(data, :arity)

    %Anoma.LocalDomain.Resource{
      data: data,
      logic:
        quote do
          fn obj, instance, consumedp ->
            if consumedp do
              true
            else
              :erlang.==(
                Map.get(Enum.at(Map.get(instance, :created), 1), :data),
                :erlang.apply(
                  Map.get(obj, :data),
                  Enum.map(
                    Enum.take(
                      Map.get(instance, :consumed),
                      unquote(arity)
                    ),
                    fn consumed -> Map.get(consumed, :data) end
                  )
                )
              )
            end
          end
        end,
      quantity: 0,
      type: Function
    }
  end

  def scheme(data) do
    {:module, _mod} = Function.info(data, :module)
    {:name, name} = Function.info(data, :name)

    name
  end

  def related_use(_data) do
    %{
      consumed: [],
      created: []
    }
  end

  def related_create(_data) do
    %{
      consumed: [],
      created: []
    }
  end
end

defimpl Anoma.LocalDomain.ObjToResource, for: Anoma.LocalDomain.Resource do
  def obj_to_resource(x) do
    x
  end

  def scheme(x) do
    %{
      "data" => Anoma.LocalDomain.ObjToResource.scheme(x.data),
      "logic" => Anoma.LocalDomain.Scheme.ast_to_scheme(x.logic),
      "quantity" => x.quantity,
      "type" => Atom.to_string(x.type)
    }
  end

  def related_use(_data) do
    %{
      consumed: [],
      created: []
    }
  end

  def related_create(_data) do
    %{
      consumed: [],
      created: []
    }
  end
end
