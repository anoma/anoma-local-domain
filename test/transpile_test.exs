defmodule TranspileTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.Transpile

  test "Run the examples" do
    Examples.ETranspile.transpile_factorial()
    Examples.ETranspile.transpile_filter()
    Examples.ETranspile.transpile_take()
    Examples.ETranspile.transpile_map()
    Examples.ETranspile.transpile_length()
    Examples.ETranspile.transpile_nth()
    Examples.ETranspile.transpile_nthcdr()
    Examples.ETranspile.transpile_lexical_scoping()
    Examples.ETranspile.transpile_mutual_recursion()
    Examples.ETranspile.transpile_nested_mutual_recursion()
    Examples.ETranspile.transpile_string_literals()
    Examples.ETranspile.transpile_resource_data()
  end
end
