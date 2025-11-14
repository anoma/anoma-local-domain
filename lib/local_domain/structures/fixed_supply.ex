defmodule Anoma.LocalDomain.FixedSupply do
  use TypedStruct

  typedstruct enforced: true do
    field(:quantity, integer())
    field(:supply_quantity, integer())
  end

  def supply_quantity(%__MODULE__{supply_quantity: supply}) do
    supply
  end

  def make_fixed_supply(q) do
    %__MODULE__{
      supply_quantity: 1000,
      quantity: q
    }
  end

  def scheme_fn(:supply_quantity) do
    ["lambda", ["x"], ["get", "x", :supply_quantity]]
  end

  def scheme_fn(:make_fixed_supply) do
    ["lambda", ["q"], %{supply_quantity: 1000, quantity: "q"}]
  end
end

defimpl Anoma.LocalDomain.ObjToResource,
  for: Anoma.LocalDomain.FixedSupply do
  def fixed_supply_holds(obj, instance, using) do
    :erlang.not(
      :erlang.==(
        length(
          Enum.filter(
            Map.get(instance, :created),
            fn finding ->
              :erlang.and(
                :erlang.==(
                  Map.get(finding, :type),
                  Anoma.LocalDomain.FixedSupplyIntent
                ),
                :erlang.and(
                  :erlang.==(
                    Map.get(finding, :quantity),
                    Map.get(obj, :quantity)
                  ),
                  :erlang.==(
                    Map.get(Map.get(finding, :data), :should_create),
                    using
                  )
                )
              )
            end
          )
        ),
        0
      )
    )
  end

  def obj_to_resource(x) do
    %Anoma.LocalDomain.Resource{
      data: x,
      logic: fn obj, instance, consumedp ->
        if consumedp do
          fixed_supply_holds(obj, instance, true)
        else
          fixed_supply_holds(obj, instance, false)
        end
      end,
      quantity: x.quantity,
      type: Anoma.LocalDomain.FixedSupply
    }
  end

  def scheme_fixed_supply_holds(should_create) do
    [
      "not",
      [
        "==",
        [
          "length",
          [
            "filter",
            [
              "lambda",
              ["finding"],
              [
                "and",
                [
                  "and",
                  [
                    "==",
                    ["get", "finding", :type],
                    Anoma.LocalDomain.FixedSupplyIntent
                  ],
                  [
                    "==",
                    ["get", "finding", :quantity],
                    ["get", "obj", :quantity]
                  ]
                ],
                [
                  "==",
                  ["get", ["get", "finding", :data], :should_create],
                  should_create
                ]
              ]
            ],
            ["get", "instance", :created]
          ]
        ],
        0
      ]
    ]
  end

  def scheme(data) do
    %{
      data: %{
        supply_quantity: data.supply_quantity
      },
      logic: [
        "lambda",
        ["obj", "instance", "consumedp"],
        [
          "if",
          "consumedp",
          scheme_fixed_supply_holds(true),
          scheme_fixed_supply_holds(false)
        ]
      ],
      quantity: data.quantity,
      type: Anoma.LocalDomain.FixedSupply
    }
  end

  def related_use(data) do
    %{
      consumed: [],
      created: [
        %Anoma.LocalDomain.FixedSupplyIntent{
          quantity: data.quantity,
          should_create: true
        }
      ]
    }
  end

  def related_create(data) do
    %{
      consumed: [],
      created: [
        %Anoma.LocalDomain.FixedSupplyIntent{
          quantity: data.quantity,
          should_create: false
        }
      ]
    }
  end
end
