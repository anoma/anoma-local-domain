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
      logic:
        quote do
          fn obj, instance, consumedp ->
            if consumedp do
              :erlang.not(
                :erlang.==(
                  :erlang.length(
                    Enum.filter(
                      if Map.get(Map.get(obj, :data), :should_create) do
                        Map.get(instance, :created)
                      else
                        Map.get(instance, :consumed)
                      end,
                      fn finding ->
                        :erlang.and(
                          :erlang.==(
                            Map.get(finding, :type),
                            Map.get(obj, :type)
                          ),
                          :erlang.==(
                            Map.get(finding, :quantity),
                            Map.get(obj, :quantity)
                          )
                        )
                      end
                    )
                  ),
                  0
                )
              )
            else
              true
            end
          end
        end,
      quantity: data.quantity,
      type: Anoma.LocalDomain.FixedSupplyIntent
    }
  end

  def scheme(data) do
    %{
      "quantity" => data.quantity,
      "should_create" => data.should_create
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
