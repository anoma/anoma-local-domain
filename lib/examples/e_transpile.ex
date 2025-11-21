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

  # let input = Sexpr::from((0..100).map(|x| Sexpr::from(2 * x + 1)).collect::<Vec::<_>>());
  # let output: Sexpr = receipt.journal.decode().unwrap();
  def transpile_take() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :take, [:xs, :n],
        [:if, [:==, :n, 0],
          [:null],
          [:cons, [:car, :xs], [:take, [:cdr, :xs], [:-, :n, 1]]]]],
      [:function, :scm_main, [],
        [[:function, :_, [:n],
          [:commit_sexpr, [:take, [:read_sexpr], :n]]], 3]]])
    {state, block, Transpile.program_to_string(block)}
  end

  # let input = Sexpr::from((0..100).map(|x| Sexpr::from(2 * x + 1)).collect::<Vec::<_>>());
  # let output: Sexpr = receipt.journal.decode().unwrap();
  def transpile_map() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :map, [:xs, :f],
        [:if, [:is_null, :xs],
          [:null],
          [:cons, [:f, [:car, :xs]], [:map, [:cdr, :xs], :f]]]],
      [:function, :scm_main, [],
        [[:function, :_, [:n],
          [:commit_sexpr, [:map, [:read_sexpr],
            [:function, :multiply_by_n, [:x], [:integer, [:*, [:as_integer, :x], :n]]]]]], 4]]])
    {state, block, Transpile.program_to_string(block)}
  end

  # let input = Sexpr::from((0..100).map(|x| Sexpr::from(2 * x + 1)).collect::<Vec::<_>>());
  # let output: Sexpr = receipt.journal.decode().unwrap();
  def transpile_length() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :length, [:xs],
        [:if, [:is_null, :xs],
          0,
          [:+, 1, [:length, [:cdr, :xs]]]]],
      [:function, :scm_main, [],
        [:commit_sexpr, [:integer, [:length, [:read_sexpr]]]]]])
    {state, block, Transpile.program_to_string(block)}
  end

  # let input = Sexpr::from((0..100).map(|x| Sexpr::from(2 * x + 1)).collect::<Vec::<_>>());
  # let output: Sexpr = receipt.journal.decode().unwrap();
  def transpile_nth() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :nth, [:xs, :n],
        [:if, [:==, :n, 0],
          [:car, :xs],
          [:nth, [:cdr, :xs], [:-, :n, 1]]]],
      [:function, :scm_main, [],
        [:commit_sexpr, [:nth, [:read_sexpr], 8]]]])
    {state, block, Transpile.program_to_string(block)}
  end

  # let input = Sexpr::from((0..100).map(|x| Sexpr::from(2 * x + 1)).collect::<Vec::<_>>());
  # let output: Sexpr = receipt.journal.decode().unwrap();
  def transpile_nthcdr() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :nthcdr, [:xs, :n],
        [:if, [:==, :n, 0],
          :xs,
          [:nthcdr, [:cdr, :xs], [:-, :n, 1]]]],
      [:function, :scm_main, [],
        [:commit_sexpr, [:nthcdr, [:read_sexpr], 8]]]])
    {state, block, Transpile.program_to_string(block)}
  end

  # let input = Sexpr::from((0..100).map(|x| Sexpr::from(2 * x + 1)).collect::<Vec::<_>>());
  # let output: Sexpr = receipt.journal.decode().unwrap();
  def transpile_lexical_scoping() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :outer, [:n],
        [:function, :thunk, [], :n],
        [[:function, :inner, [:n], [:thunk]], 5]],
      [:function, :scm_main, [],
        [:commit_sexpr, [:integer, [:outer, 11]]]]])
    {state, block, Transpile.program_to_string(block)}
  end

  # let input = Sexpr::from((0..100).map(|x| Sexpr::from(2 * x + 1)).collect::<Vec::<_>>());
  # let output: Sexpr = receipt.journal.decode().unwrap();
  def transpile_mutual_recursion() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :is_even, [:n],
        [:if, [:==, :n, 0], true, [:is_odd, [:-, :n, 1]]]],
      [:function, :is_odd, [:n],
        [:if, [:==, :n, 0], false, [:is_even, [:-, :n, 1]]]],
      [:function, :scm_main, [],
        [:commit_sexpr, [:cons, [:integer, [:is_even, 11]], [:cons, [:integer, [:is_even, 12]], [:integer, [:is_even, 14]]]]]]])
    {state, block, Transpile.program_to_string(block)}
  end

  # let input = Sexpr::from((0..100).map(|x| Sexpr::from(2 * x + 1)).collect::<Vec::<_>>());
  # let output: Sexpr = receipt.journal.decode().unwrap();
  def transpile_nested_mutual_recursion() do
    state = Transpile.new()
    {state, block} = Transpile.transpile(state,
      [[:function, :is_odd, [:n],
        [:function, :is_even, [:n],
          [:if, [:==, :n, 0], true, [:is_odd, [:-, :n, 1]]]],
        [:if, [:==, :n, 0], false, [:is_even, [:-, :n, 1]]],],
      [:function, :scm_main, [],
        [:commit_sexpr, [:cons, [:integer, [:is_odd, 11]], [:cons, [:integer, [:is_odd, 12]], [:integer, [:is_odd, 14]]]]]]])
    {state, block, Transpile.program_to_string(block)}
  end
end
