defmodule Anoma.LocalDomain.FixedSupplyIntent do
  use TypedStruct

  typedstruct enforced: true do
    field(:quantity, integer())
    field(:should_create, boolean())
  end
end

defimpl Anoma.LocalDomain.ObjToResource,
  for: Anoma.LocalDomain.FixedSupplyIntent do
  def obj_to_resource(data) do
    %Anoma.LocalDomain.Resource{
      data: data,
      logic: fn obj, instance, consumedp ->
        if consumedp do
          length(
            Enum.filter(
              if obj.data.should_create do
                instance.created
              else
                instance.consumed
              end,
              fn finding ->
                finding.type == obj.type &&
                  finding.quantity == obj.quantity
              end
            )
          ) != 0
        else
          true
        end
      end,
      quantity: data.quantity,
      type: Anoma.LocalDomain.FixedSupplyIntent
    }
  end

  def scheme(data) do
    %{
      data: %{
        quantity: data.quantity,
        should_create: data.should_create
      },
      logic: [
        "lambda",
        ["obj", "instance", "consumedp"],
        [
          "if",
          "consumedp",
          "true",
          [
            "filter",
            [
              "lambda",
              ["x"],
              [
                "and",
                [
                  "==",
                  ["get", ["get", "x", :data], :type],
                  ["get", ["get", "obj", :data], :type]
                ],
                [
                  "==",
                  ["get", ["get", "x", :data], :quantity],
                  ["get", ["get", "obj", :data], :quantity]
                ]
              ]
            ],
            [
              "if",
              ["get", ["get", "obj", :data], :should_create],
              ["get", "instance", :created],
              ["get", "instance", :consumed]
            ]
          ]
        ]
      ],
      quantity: data.quantity,
      type: Anoma.LocalDomain.FixedSupplyIntent
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
