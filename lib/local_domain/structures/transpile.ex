defmodule Anoma.LocalDomain.Transpile do
  use TypedStruct
  
  typedstruct enforce: true do
    field(:counter, non_neg_integer())
    field(:cprogram, list())
  end

  def new() do
    %__MODULE__{ counter: 0, cprogram: [] }
  end

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

  def transpile_aux(state = %__MODULE__{}, expr, target, block, _labels) when is_binary(expr) do
    {state, maybe_assign_expr({:symbol_expr, expr}, target, block)}
  end

  def transpile_aux(state = %__MODULE__{}, expr, target, block, _labels) when is_number(expr) do
    {state, maybe_assign_expr({:literal_expr, expr}, target, block)}
  end

  def transpile_aux(state = %__MODULE__{}, expr, target, block, _labels) when is_boolean(expr) do
    {state, maybe_assign_expr(expr, target, block)}
  end

  # Transpile a Scheme if expression to C

  def transpile_aux(state = %__MODULE__{}, expr = ["if", condition, consequent, alternate], target, block, labels) do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    {state, ccond_name} = gen_sym(state)
    ccond = {:symbol_expr, ccond_name}
    ccond_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
    block = [{:declaration_stmt, specifier(ccond_type), [{identifier(declarator(ccond_type), ccond_name), nil}]} | block]
    {state, block} = transpile_aux(state, condition, {ccond, ccond_type}, block, labels)
    {state, cconsequent} = transpile_aux(state, consequent, target, [], labels)
    {state, calternate} = transpile_aux(state, alternate, target, [], labels)
    ifstmt = {:if_stmt, ccond, Enum.reverse(cconsequent), Enum.reverse(calternate)}
    {state, [ifstmt | block]}
  end

  # Transpile a Scheme function expression to C

  def transpile_aux(state = %__MODULE__{}, expr = ["function", reference, parameters | expressions], target, block, labels) do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    cparams = for param <- parameters, do: { "uintptr_t", {:identifier_declarator, param}}
    cfunc_decl = {:function_declarator, {:identifier_declarator, reference}, cparams}
    cfunc_type = {:type_name, if target do "auto uintptr_t" else "extern uintptr_t" end, cfunc_decl}
    decl_stmt = {:declaration_stmt, specifier(cfunc_type), [{declarator(cfunc_type), nil}]}
    block = block ++ [decl_stmt]
    {state, cret_name} = gen_sym(state)
    cret_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
    cret = {:symbol_expr, cret_name}
    funbody = [{:declaration_stmt, specifier(cret_type), [{identifier(declarator(cret_type), cret_name), nil}]}]
    {state, funbody} =
      for expression <- expressions, reduce: {state, funbody} do
        {state, funbody} -> transpile_aux(state, expression, {cret, cret_type}, funbody, labels)
      end
    funbody = [{:return_stmt, cret} | funbody]
    function = {:function_stmt, specifier(cfunc_type), cfunc_decl, Enum.reverse(funbody)}
    {state, maybe_assign_expr({:address_of_expr, {:symbol_expr, reference}}, target, [function | block])}
  end

  # Transpile a Scheme binary expression to C
  
  def transpile_aux(state = %__MODULE__{}, expr = [reference | arguments], target, block, labels) when reference in ["+", "-", "/", "*", "<<", ">>", "==", "!=", "<", ">", "<=", ">=", "&", "|", "%"] do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    {state, block, cargs} =
      for arg <- arguments, reduce: {state, block, []} do
        {state, block, cargs} ->
          {state, carg_name} = gen_sym(state)
          carg_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
          block = [{:declaration_stmt, specifier(carg_type), [{identifier(declarator(carg_type), carg_name), nil}]} | block]
          carg = {:symbol_expr, carg_name}
          {state, block} = transpile_aux(state, arg, {carg, carg_type}, block, labels)
          {state, block, [carg | cargs]}
      end
    call = {:binary_expr, reference, Enum.at(cargs, 1), Enum.at(cargs, 0)}
    {state, maybe_assign_expr(call, target, block)}
  end

  # Transpile a Scheme procedure call expression to C

  def transpile_aux(state = %__MODULE__{}, expr = [reference | arguments], target, block, labels) when is_binary(reference) do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    {state, block, cargs} =
      for arg <- arguments, reduce: {state, block, []} do
        {state, block, cargs} ->
          {state, carg_name} = gen_sym(state)
          carg_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
          block = [{:declaration_stmt, specifier(carg_type), [{identifier(declarator(carg_type), carg_name), nil}]} | block]
          carg = {:symbol_expr, carg_name}
          {state, block} = transpile_aux(state, arg, {carg, carg_type}, block, labels)
          {state, block, [carg | cargs]}
      end
    call = {:call_expr, {:symbol_expr, reference}, Enum.reverse(cargs)}
    {state, maybe_assign_expr(call, target, block)}
  end

  # Transpile a Scheme procedure call expression to C

  def transpile_aux(state = %__MODULE__{}, expr = [reference | arguments], target, block, labels) do
    block = [{:comment_stmt, expr_to_string(expr)} | block]
    {state, cref_name} = gen_sym(state)
    cref = {:symbol_expr, cref_name}
    params = for _ <- arguments, do: {"uintptr_t", {:identifier_declarator, ""}}
    cref_type = {:type_name, "uintptr_t", {:function_declarator, {:pointer_declarator, {:identifier_declarator, ""}}, params}}
    block = [{:declaration_stmt, specifier(cref_type), [{identifier(declarator(cref_type), cref_name), nil}]} | block]
    {state, block} = transpile_aux(state, reference, {cref, cref_type}, block, labels)
    {state, block, cargs} =
      for arg <- arguments, reduce: {state, block, []} do
        {state, block, cargs} ->
          {state, carg_name} = gen_sym(state)
          carg_type = {:type_name, "uintptr_t", {:identifier_declarator, ""}}
          block = [{:declaration_stmt, specifier(carg_type), [{identifier(declarator(carg_type), carg_name), nil}]} | block]
          carg = {:symbol_expr, carg_name}
          {state, block} = transpile_aux(state, arg, {carg, carg_type}, block, labels)
          {state, block, [carg | cargs]}
      end
    call = {:call_expr, cref, Enum.reverse(cargs)}
    {state, maybe_assign_expr(call, target, block)}
  end

  def transpile(state = %__MODULE__{}, expr, target, block, labels) do
    {state, block} = transpile_aux(state, expr, target, block, labels)
    {state, Enum.reverse(block)}
  end

  # Convert Scheme expression to string

  def expr_to_string(value) when is_number(value), do: "#{value}"

  def expr_to_string(value) when is_binary(value), do: "#{value}"

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
