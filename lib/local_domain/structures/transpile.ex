defmodule Anoma.LocalDomain.Transpile do
  use TypedStruct
  
  typedstruct enforce: true do
    field(:counter, non_neg_integer())
  end

  def new() do
    %__MODULE__{ counter: 0 }
  end

  # Rename distinct variables to distinct names

  def next_variable_suffix(""), do: 0

  def next_variable_suffix(i), do: i + 1

  def rename_variable(from, mapping, used, base, i \\ "") do
    reference = String.to_atom("#{base}#{i}")
    if MapSet.member?(used, reference) do
      rename_variable(from, mapping, used, base, next_variable_suffix(i))
    else
      {reference, Map.put(mapping, from, reference), MapSet.put(used, reference)}
    end
  end

  def rename_variable(from, mapping, used) do
    base = String.replace(String.replace(Atom.to_string(from), "-", "_"), ".", "_")
    rename_variable(from, mapping, used, base)
  end

  def rename_variables_aux(expressions, mapping, used) do
    {expressions, used} = for expr <- expressions, reduce: {[], used} do
      {new_expressions, used} ->
        {expr, used} = rename_variables(expr, mapping, used)
        {[expr | new_expressions], used}
    end
    {Enum.reverse(expressions), used}
  end

  def rename_variables(expr, _mapping, used) when is_binary(expr) or is_number(expr) or is_boolean(expr) do
    {expr, used}
  end

  def rename_variables(expr, mapping, used) when is_atom(expr) do
    {Map.get(mapping, expr, expr), used}
  end

  def rename_variables([:if, condition, consequent, alternate], mapping, used) do
    {condition, used} = rename_variables(condition, mapping, used)
    {consequent, used} = rename_variables(consequent, mapping, used)
    {alternate, used} = rename_variables(alternate, mapping, used)
    {[:if, condition, consequent, alternate], used}
  end

  def rename_variables([:function, reference, parameters | expressions], mapping, used) do
    {reference, mapping, used} = rename_variable(reference, mapping, used)
    {parameters, mapping, used} = for param <- parameters, reduce: {[], mapping, used} do
      {new_parameters, mapping, used} ->
        {param, mapping, used} = rename_variable(param, mapping, used)
        {[param | new_parameters], mapping, used}
    end
    {expressions, used} = rename_variables_aux(expressions, mapping, used)
    {[:function, reference, Enum.reverse(parameters) | expressions], used}
  end

  def rename_variables([reference | arguments], mapping, used) do
    {reference, used} = rename_variables(reference, mapping, used)
    {arguments, used} = rename_variables_aux(arguments, mapping, used)
    {[reference | arguments], used}
  end

  # A variation of Enum.reduce that supplies tails to the function

  def tails(list = [_hd | tl], acc, f), do: tails(tl, f.(list, acc), f)

  def tails([], acc, _f), do: acc

  # Generate a new symbol

  def gen_sym(state = %__MODULE__{}) do
    sym = "tmp#{state.counter}"
    state = %__MODULE__{state | counter: state.counter + 1}
    {state, sym}
  end

  # Extract the components of a type name

  def specifier({:type_name, spec, _}), do: spec

  def declarator({:type_name, _, decl}), do: decl

  # Set the identifier in the given declarator

  def identifier({:identifier_declarator, _}, ident), do: {:identifier_declarator, ident}

  def identifier({:pointer_declarator, decl}, ident), do: {:pointer_declarator, identifier(decl, ident)}

  def identifier({:array_declarator, decl, expr}, ident), do: {:array_declarator, identifier(decl, ident), expr}

  def identifier({:function_declarator, decl, params}, ident), do: {:function_declarator, identifier(decl, ident), params}

  # Assign the expression to the target if it is there, otherwise just evaluate it
  
  def maybe_assign_expr(expr, {target_expr, target_type}, block) do
    [{:expr_stmt, {:binary_expr, "=", target_expr, {:cast_expr, target_type, expr}}} | block]
  end

  def maybe_assign_expr({:address_of_expr, {:symbol_expr, _}}, nil, block), do: block

  def maybe_assign_expr(expr, nil, block), do: [{:expr_stmt, expr} | block]

  # Transpile a Scheme expression to C

  def transpile_aux(state = %__MODULE__{}, expr, target, block, _tails) when is_binary(expr) or is_number(expr) or is_boolean(expr) do
    {state, maybe_assign_expr({:literal_expr, expr}, target, block)}
  end

  def transpile_aux(state = %__MODULE__{}, expr, target, block, _tails) when is_atom(expr) do
    {state, maybe_assign_expr({:symbol_expr, Atom.to_string(expr)}, target, block)}
  end

  def transpile_aux(state = %__MODULE__{}, expr = [:if, condition, consequent, alternate], target, block, tails) do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    {state, ccond_name} = gen_sym(state)
    ccond = {:symbol_expr, ccond_name}
    ccond_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
    block = [{:declaration_stmt, specifier(ccond_type), [{identifier(declarator(ccond_type), ccond_name), nil}]} | block]
    {state, block} = transpile_aux(state, condition, {ccond, ccond_type}, block, %{})
    {state, cconsequent} = transpile_aux(state, consequent, target, [], tails)
    {state, calternate} = transpile_aux(state, alternate, target, [], tails)
    ifstmt = {:if_stmt, ccond, Enum.reverse(cconsequent), Enum.reverse(calternate)}
    {state, [ifstmt | block]}
  end

  def transpile_aux(state = %__MODULE__{}, expr = [:function, reference, parameters | expressions], target, block, tails) do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    cparams = for param <- parameters, do: { "uintptr_t", {:identifier_declarator, Atom.to_string(param)}}
    cfunc_decl = {:function_declarator, {:identifier_declarator, Atom.to_string(reference)}, cparams}
    cfunc_type = {:type_name, if target do "auto uintptr_t" else "extern uintptr_t" end, cfunc_decl}
    decl_stmt = {:declaration_stmt, specifier(cfunc_type), [{declarator(cfunc_type), nil}]}
    block = block ++ [decl_stmt]
    {state, cfunc_label} = gen_sym(state)
    funbody = [{:label_stmt, cfunc_label}]
    {state, cret_name} = gen_sym(state)
    cret_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
    cret = {:symbol_expr, cret_name}
    funbody = [{:declaration_stmt, specifier(cret_type), [{identifier(declarator(cret_type), cret_name), nil}]} | funbody]
    tails = Map.put(tails, reference, {cfunc_label, parameters})
    {state, funbody} = tails(expressions, {state, funbody}, fn
      [expression], {state, funbody} -> transpile_aux(state, expression, {cret, cret_type}, funbody, tails)
      [expression | _], {state, funbody} -> transpile_aux(state, expression, {cret, cret_type}, funbody, %{})
    end)
    funbody = [{:return_stmt, cret} | funbody]
    funbody = [{:declaration_stmt, "__label__", [{{:identifier_declarator, cfunc_label}, nil}]} | Enum.reverse(funbody)]
    function = {:function_stmt, specifier(cfunc_type), cfunc_decl, funbody}
    {state, maybe_assign_expr({:address_of_expr, {:symbol_expr, Atom.to_string(reference)}}, target, [function | block])}
  end
  
  def transpile_aux(state = %__MODULE__{}, expr = [reference | arguments], target, block, _tails) when reference in [:+, :-, :/, :*, :"<<", :">>", :==, :!=, :<, :>, :<=, :>=, :&, :|, :%] do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    {state, block, cargs} =
      for arg <- arguments, reduce: {state, block, []} do
        {state, block, cargs} ->
          {state, carg_name} = gen_sym(state)
          carg_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
          block = [{:declaration_stmt, specifier(carg_type), [{identifier(declarator(carg_type), carg_name), nil}]} | block]
          carg = {:symbol_expr, carg_name}
          {state, block} = transpile_aux(state, arg, {carg, carg_type}, block, %{})
          {state, block, [carg | cargs]}
      end
    call = {:binary_expr, reference, Enum.at(cargs, 1), Enum.at(cargs, 0)}
    {state, maybe_assign_expr(call, target, block)}
  end

  def transpile_aux(state = %__MODULE__{}, expr = [reference | arguments], target, block, tails) when is_atom(reference) do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    {state, block, cargs} =
      for arg <- arguments, reduce: {state, block, []} do
        {state, block, cargs} ->
          {state, carg_name} = gen_sym(state)
          carg_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
          block = [{:declaration_stmt, specifier(carg_type), [{identifier(declarator(carg_type), carg_name), nil}]} | block]
          carg = {:symbol_expr, carg_name}
          {state, block} = transpile_aux(state, arg, {carg, carg_type}, block, %{})
          {state, block, [carg | cargs]}
      end
    case Map.get(tails, reference) do
      {target, params} ->
        block = for {param, arg} <- Enum.zip(params, Enum.reverse(cargs)), reduce: block do
          block -> [{:expr_stmt, {:binary_expr, "=", {:symbol_expr, Atom.to_string(param)}, arg}} | block]
        end
        {state, [{:goto_stmt, target} | block]}
      _ ->
        call = {:call_expr, {:symbol_expr, Atom.to_string(reference)}, Enum.reverse(cargs)}
        {state, maybe_assign_expr(call, target, block)}
    end
  end

  def transpile_aux(state = %__MODULE__{}, expr = [reference | arguments], target, block, _tails) do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    {state, cref_name} = gen_sym(state)
    cref = {:symbol_expr, cref_name}
    params = for _ <- arguments, do: {"uintptr_t", {:identifier_declarator, ""}}
    cref_type = {:type_name, "uintptr_t", {:function_declarator, {:pointer_declarator, {:identifier_declarator, ""}}, params}}
    block = [{:declaration_stmt, specifier(cref_type), [{identifier(declarator(cref_type), cref_name), nil}]} | block]
    {state, block} = transpile_aux(state, reference, {cref, cref_type}, block, %{})
    {state, block, cargs} =
      for arg <- arguments, reduce: {state, block, []} do
        {state, block, cargs} ->
          {state, carg_name} = gen_sym(state)
          carg_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
          block = [{:declaration_stmt, specifier(carg_type), [{identifier(declarator(carg_type), carg_name), nil}]} | block]
          carg = {:symbol_expr, carg_name}
          {state, block} = transpile_aux(state, arg, {carg, carg_type}, block, %{})
          {state, block, [carg | cargs]}
      end
    call = {:call_expr, cref, Enum.reverse(cargs)}
    {state, maybe_assign_expr(call, target, block)}
  end

  def transpile(state = %__MODULE__{}, expr, target \\ nil, block \\ [], tails \\ %{}) do
    used = MapSet.new([:return, :if, :switch, :case, :int, :float, :void, :goto, :break, :for, :while])
    {expr, _} = rename_variables(expr, %{}, used)
    {state, block} = transpile_aux(state, expr, target, block, tails)
    {state, Enum.reverse(block)}
  end

  # Convert Scheme expression to string

  def expr_to_string(value) when is_number(value), do: "#{value}"

  def expr_to_string(value) when is_binary(value), do: "\"#{value}\""

  def expr_to_string(value) when is_atom(value), do: "#{value}"

  def expr_to_string([]), do: "()"

  def expr_to_string([head | tail]) do
    str =
      for expr <- tail, reduce: ("(" <> expr_to_string(head)) do
        str -> str <> " " <> expr_to_string(expr)
      end
    str <> ")"
  end

  # Convert C expression to string

  def cexpr_to_string({:literal_expr, value}) when is_number(value), do: "#{value}"

  def cexpr_to_string({:literal_expr, value}) when is_boolean(value), do: "#{value}"

  def cexpr_to_string({:literal_expr, value}) when is_binary(value), do: "\"#{value}\""

  def cexpr_to_string({:symbol_expr, value}) when is_binary(value), do: "#{value}"

  def cexpr_to_string({:address_of_expr, expr}), do: "&#{cexpr_to_string(expr)}"

  def cexpr_to_string({:indirection_expr, expr}), do: "*#{cexpr_to_string(expr)}"
  
  def cexpr_to_string({:binary_expr, op, expr1, expr2}), do: "(#{cexpr_to_string(expr1)} #{op} #{cexpr_to_string(expr2)})"

  def cexpr_to_string({:not_expr, expr}), do: "!#{cexpr_to_string(expr)}"

  def cexpr_to_string({:subscript_expr, expr1, expr2}), do: "#{cexpr_to_string(expr1)}[#{cexpr_to_string(expr2)}]"

  def cexpr_to_string({:cast_expr, typename, expr}) do
    "(#{specifier(typename)} #{declarator_to_string(declarator(typename))}) #{cexpr_to_string(expr)}"
  end

  def cexpr_to_string({:call_expr, reference, args}) do
    str = cexpr_to_string(reference) <> "("
    str = case args do
      [arg0 | rest] ->
        for arg <- rest, reduce: str <> cexpr_to_string(arg0) do
          str -> str <> ", " <> cexpr_to_string(arg)
        end
      [] -> str
    end
    str <> ")"
  end

  # Convert C declaration to string

  def declarator_to_string({:identifier_declarator, ident}) when is_binary(ident), do: "#{ident}"

  def declarator_to_string({:pointer_declarator, decl}), do: "(*#{declarator_to_string(decl)})"

  def declarator_to_string({:array_declarator, decl, expr}), do: "(#{declarator_to_string(decl)}[#{cexpr_to_string(expr)}])"

  def declarator_to_string({:function_declarator, declarator, params}) do
    str = declarator_to_string(declarator) <> "("
    case params do
      [{spec0, decl0} | rest] ->
        str = str <> spec0 <> " " <> declarator_to_string(decl0)
        str = for {spec, decl} <- rest, reduce: str do
          str -> str <> ", " <> spec <> " " <> declarator_to_string(decl)
        end
        str <> ")"
      [] -> str <> ")"
    end
  end

  # Convert C initializer to string
  
  def initializer_to_string(nil), do: ""

  def initializer_to_string(init), do: " = " <> cexpr_to_string(init)

  # Convert C statement to string

  def stmt_to_string({:if_stmt, condition, cons, alt}) do
    str = "if(" <> cexpr_to_string(condition) <> ") {\n"
    str = for stmt <- cons, reduce: str do
      str -> str <> stmt_to_string(stmt)
    end
    if alt == [] do
      str <> "}\n"
    else
      str = for stmt <- alt, reduce: str <> "} else {\n" do
        str -> str <> stmt_to_string(stmt)
      end
      str <> "}\n"
    end
  end

  def stmt_to_string({:return_stmt, val}), do: "return " <> cexpr_to_string(val) <> ";\n"

  def stmt_to_string({:comment_stmt, comment}), do: "// " <> comment <> "\n"

  def stmt_to_string({:expr_stmt, expr}), do: cexpr_to_string(expr) <> ";\n"

  def stmt_to_string({:label_stmt, identifier}) when is_binary(identifier), do: identifier <> ":\n"

  def stmt_to_string({:goto_stmt, identifier}) when is_binary(identifier), do: "goto " <> identifier <> ";\n"

  def stmt_to_string({:declaration_stmt, spec, decls}) do
    str = spec
    case decls do
      [{decl0, init0} | rest] ->
        str = str <> " " <> declarator_to_string(decl0) <> initializer_to_string(init0)
        str =
          for {decl, init} <- rest, reduce: str do
            str -> str <> ", " <> declarator_to_string(decl) <> initializer_to_string(init)
          end
        str <> ";\n"
      [] -> ";\n"
    end
  end

  def stmt_to_string({:function_stmt, spec, decl, body}) do
    str = spec <> " " <> declarator_to_string(decl) <> " {\n"
    str =
      for stmt <- body, reduce: str do
        str -> str <> stmt_to_string(stmt)
      end
    str <> "}\n"
  end

  # Convert C program to string

  def program_to_string(program) do
    for stmt <- program, reduce: "" do
      str -> str <> stmt_to_string(stmt)
    end
  end
end
