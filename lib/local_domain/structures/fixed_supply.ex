defmodule Anoma.LocalDomain.FixedSupply do
  use TypedStruct
  use Anoma.LocalDomain.Scheme

  typedstruct enforced: true do
    field(:quantity, integer())
    field(:supply_quantity, integer())
  end

  defrisc supply_quantity(fixed_supply) do
    Map.get(fixed_supply, :quantity)
  end

  defrisc fixed_supply_holds(obj, instance, using) do
    :erlang.not(
      :erlang.==(
        :erlang.length(
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

  def make_fixed_supply(q) do
    %__MODULE__{
      supply_quantity: 1000,
      quantity: q
    }
  end
end

defimpl Anoma.LocalDomain.ObjToResource,
  for: Anoma.LocalDomain.FixedSupply do
  def obj_to_resource(x) do
    %Anoma.LocalDomain.Resource{
      data: x,
      logic:
        quote do
          fn obj, instance, consumedp ->
            if consumedp do
              Anoma.LocalDomain.FixedSupply.fixed_supply_holds(
                obj,
                instance,
                true
              )
            else
              Anoma.LocalDomain.FixedSupply.fixed_supply_holds(
                obj,
                instance,
                false
              )
            end
          end
        end,
      quantity: x.quantity,
      type: Anoma.LocalDomain.FixedSupply
    }
  end

  def scheme(data) do
    %{
      "quantity" => data.quantity,
      "supply_quantity" => data.supply_quantity
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
