defmodule Examples.EAction do
  require ExUnit.Assertions
  import ExUnit.Assertions

  require Anoma.LocalDomain.Action
  alias Anoma.LocalDomain.Action

  def transacted_inc() do
    Anoma.LocalDomain.SchemeRegistry.register(Examples.EScheme)
    unit = Action.transact(Examples.EScheme.inc(2))
    created = Map.get(unit, :created)
    assert length(created) == 2
    unit
  end

  def unit_as_scheme() do
    Anoma.LocalDomain.Action.to_scheme(transacted_inc())
  end

  def run_inc_unit() do
    unit = transacted_inc()
    obj = Enum.at(unit.created, 1)
    consumed? = false
    logic = Anoma.LocalDomain.Resource.compile_logic(obj)

    result = apply(logic, [obj, unit, consumed?])

    assert result == true

    unit
  end

  def interpret_inc_unit() do
    unit = unit_as_scheme()
    obj = Enum.at(Map.get(unit, "created"), 1)
    consumed? = false
    logic = Map.get(obj, "logic")

    result =
      Anoma.LocalDomain.Scheme.eval([
        :apply,
        logic,
        [
          :list,
          obj,
          unit,
          consumed?
        ]
      ])

    assert result == true

    unit
  end
end
