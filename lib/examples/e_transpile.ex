defmodule Examples.ETranspile do
  require ExUnit.Assertions
  import ExUnit.Assertions

  alias Anoma.LocalDomain.Transpile

  def transpile_factorial() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      ["function", "main", [],
       ["function", "factorial", ["n"],
        ["if", ["==", "n", 0],
         1,
         ["*", "n", ["factorial", ["-", "n", 1]]]]],
       ["factorial", 5]],
      {{:literal_expr, 120}, {:type_name, "uintptr_t", {:identifier_declarator, ""}}},
      [],
      [])
    {:expr_stmt,
     {:binary_expr, binary_op, {:literal_expr, expected_result},
      {:cast_expr, {:type_name, result_type, _},
       _}}} = Enum.at(block, -1)
    assert binary_op == "="
    assert expected_result == 120
    assert result_type == "uintptr_t" 
    {state, block}
  end
end
