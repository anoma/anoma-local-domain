defmodule TranspileTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.Transpile

  test "Run the examples" do
    Examples.ETranspile.transpile_factorial()
  end
end
