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
end

defprotocol Anoma.LocalDomain.ObjToResource do
  def obj_to_resource(x)
  def scheme(x)
end

defimpl Anoma.LocalDomain.ObjToResource, for: Integer do
  def obj_to_resource(x) do
    %Anoma.LocalDomain.Resource{
      data: x,
      logic: fn obj, _instance, _consumedp -> is_integer(obj.data) end,
      quantity: 1,
      type: Integer
    }
  end

  def scheme(data) do
    %{
      data: data,
      logic: [
        "lambda",
        ["obj", "instance", "consumedp"],
        ["integerp", "obj"]
      ],
      quantity: 1,
      type: :integer
    }
  end
end

defimpl Anoma.LocalDomain.ObjToResource, for: Function do
  def obj_to_resource(x) do
    %Anoma.LocalDomain.Resource{
      data: x,
      logic: fn obj, instance, consumedp ->
        if consumedp do
          true
        else
          Enum.at(instance.created, 1) ==
            apply(obj.data, instance.consumed)
        end
      end,
      quantity: 0,
      type: Function
    }
  end

  def scheme(data) do
    {:module, mod} = Function.info(data, :module)
    {:name, name} = Function.info(data, :name)
    {:arity, arity} = Function.info(data, :arity)

    if function_exported?(mod, :scheme_fn, 1) do
      %{
        data: mod.scheme_fn(name),
        logic: [
          "lambda",
          ["obj", "instance", "consumedp"],
          [
            "if",
            "consumedp",
            true,
            [
              "==",
              [
                "get",
                ["car", ["cdr", ["get", "instance", :created]]],
                :data
              ],
              [
                "funcall",
                ["get", "obj", :data],
                [
                  "map",
                  ["lambda", ["consumed"], ["get", "consumed", :data]],
                  ["take",
                   ["get", "obj", :arity],
                   ["get", "instance", :consumed]
                  ]
                ]
              ]
            ]
          ]
        ],
        quantity: 0,
        type: :function,
        arity: arity
      }
    else
      case Enum.find(Anoma.LocalDomain.Scheme.default_env(), fn {_k, v} ->
             v == {"native", mod, name}
           end) do
        {k, _v} ->
          %{
            data: k,
            logic: [
              "lambda",
              ["obj", "instance", "consumedp"],
              [
                "if",
                "consumedp",
                true,
                [
                  "==",
                  [
                    "get",
                    ["car", ["cdr", ["get", "instance", :created]]],
                    :data
                  ],
                  [
                    "funcall",
                    ["get", "obj", :data],
                    [
                      "map",
                      [
                        "lambda",
                        ["consumed"],
                        ["get", "consumed", :data]
                      ],
                      ["get", "instance", :consumed]
                    ]
                  ]
                ]
              ]
            ],
            quantity: 0,
            type: :function
          }

        nil ->
          %{
            data: nil,
            logic: [
              "lambda",
              ["obj", "instance", "consumedp"],
              false
            ],
            quantity: 0,
            type: :function
          }
      end
    end
  end
end

defimpl Anoma.LocalDomain.ObjToResource, for: Anoma.LocalDomain.Resource do
  def obj_to_resource(x) do
    x
  end

  def scheme(x) do
    scheme(x.data)
  end
end
