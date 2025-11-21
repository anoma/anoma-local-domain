defmodule Examples.ETranspile do
  require ExUnit.Assertions

  alias Anoma.LocalDomain.Transpile

  def transpile_factorial() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :scm_main, [],
       [:function, :factorial, [:n],
        [:if, [:==, :n, 0],
         1,
         [:*, :n, [:factorial, [:-, :n, 1]]]]],
        [:factorial, 5]]])
    {state, block, Transpile.program_to_string(block)}
  end

  # let input = Sexpr::from((0..100).map(|x| Sexpr::from(2 * x + 1)).collect::<Vec::<_>>());
  # let output: Sexpr = receipt.journal.decode().unwrap();
  def transpile_filter() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :filter, [:xs, :f],
        [:if, [:is_null, :xs],
          [:null],
          [:if, [:f, [:car, :xs]],
            [:cons, [:car, :xs], [:filter, [:cdr, :xs], :f]],
            [:filter, [:cdr, :xs], :f]]]],
      [:function, :scm_main, [],
        [[:function, :_, [:n],
          [:commit_sexpr, [:filter, [:read_sexpr],
            [:function, :divisible_by_n, [:x], [:==, [:%, [:as_integer, :x], :n], 0]]]]], 3]]])
    {state, block, Transpile.program_to_string(block)}
  end
end
