defmodule Examples.EFixedSupply do
  require ExUnit.Assertions
  import ExUnit.Assertions

  require Anoma.LocalDomain.Action
  alias Anoma.LocalDomain.Action
  alias Anoma.LocalDomain.FixedSupply
  alias Anoma.LocalDomain.FixedSupplyIntent
  alias Anoma.LocalDomain.ObjToResource

  def compute_related_fixed_supply() do
    fixed_supply = %FixedSupply{supply_quantity: 1000, quantity: 500}

    fixed_supply_resource = ObjToResource.obj_to_resource(fixed_supply)

    with_related =
      Action.compute_related(%Action{
        consumed: [fixed_supply_resource],
        created: []
      })

    assert with_related.__struct__ == Action
    assert length(with_related.created) == 1

    intent = hd(with_related.created)
    assert intent.data.__struct__ == FixedSupplyIntent
    with_related
  end

  def transact_fixed_supply() do
    fixed_supply = %FixedSupply{supply_quantity: 1000, quantity: 500}

    transaction =
      Action.transact(FixedSupply.supply_quantity(fixed_supply))

    assert length(transaction.created) == 3
    transaction
  end

  def transact_fixed_supply_intent_consumption() do
    transaction = Action.transact(FixedSupply.make_fixed_supply(500))

    # assert length(transaction.consumed) == 2
    transaction
  end

  def interpret_fixed_supply_elixir() do
    transaction = transact_fixed_supply()
    obj = hd(transaction.consumed)
    logic = obj.logic
    apply(logic, [obj, transaction, true])
  end

  def interpret_fixed_supply_scheme() do
    transaction = transact_fixed_supply()
    unit = Action.to_scheme(transaction)
    obj = Enum.at(Map.get(unit, :consumed), 1)
    consumed? = true
    logic = Map.get(obj, :logic)

    result =
      Anoma.LocalDomain.Scheme.eval([
        "apply",
        logic,
        obj,
        unit,
        consumed?
      ])

    assert result == true

    unit
  end

  def interpret_quantity_elixir() do
    transaction = transact_fixed_supply()
    obj = hd(transaction.created)
    logic = obj.logic
    apply(logic, [obj, transaction, false])
  end

  def interpret_quantity_scheme() do
    transaction = transact_fixed_supply()
    unit = Action.to_scheme(transaction)
    obj = Enum.at(Map.get(unit, :created), 1)
    consumed? = false
    logic = Map.get(obj, :logic)

    result =
      Anoma.LocalDomain.Scheme.eval([
        "apply",
        logic,
        obj,
        unit,
        consumed?
      ])

    assert result == true

    unit
  end

  def interpret_intent_elixir() do
    transaction = transact_fixed_supply()
    obj = Enum.at(transaction.created, 2)
    logic = obj.logic
    apply(logic, [obj, transaction, false])

    transaction
  end
end
