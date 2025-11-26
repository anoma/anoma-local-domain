defmodule Anoma.LocalDomain.Scheme do
  @moduledoc """
  I am the Scheme DSL Interpreter
  """

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :scheme_fns,
        accumulate: true
      )

      import Anoma.LocalDomain.Scheme
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    module = env.module
    scheme_fns = Module.get_attribute(module, :scheme_fns)

    quote do
      def __scheme_fns__ do
        unquote(Enum.reverse(Macro.escape(scheme_fns)))
      end

      # This doesn't work first compilation, only recompilation
      # Also if we care about registration order (we do) we shouldn't do post-compiles
      # @after_compile __MODULE__
      # def __after_compile__(_env, _bytecode) do
      #   Anoma.LocalDomain.SchemeRegistry.register(unquote(module))
      # end
    end
  end

  @doc """
  Define an elixir->scheme mapping
  """
  defmacro defrisc({name, _meta, args},
             do: body_elixir
           ) do
    [:list | args_scheme] = ast_to_scheme(args)

    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote(body_elixir)
      end

      @scheme_fns {unquote(name), unquote(args_scheme),
                   unquote(
                     Anoma.LocalDomain.Scheme.ast_to_scheme(body_elixir)
                   )}
    end
  end

  defmacro defscheme({name_scheme, _meta, args}, do: body_scheme) do
    [:list | args_scheme] = ast_to_scheme(args)

    quote do
      @scheme_fns {unquote(name_scheme), unquote(args_scheme),
                   unquote(body_scheme)}
    end
  end

  def default_env() do
    {:ok, scheme_fns, store} = Anoma.LocalDomain.SchemeRegistry.all_scheme()

    {scheme_fns, store}
  end

  def eval(num, env, store) when is_number(num) do
    {num, env, store}
  end

  def eval(true, env, store) do
    {true, env, store}
  end

  def eval(false, env, store) do
    {false, env, store}
  end

  def eval(nil, env, store) do
    {nil, env, store}
  end

  def eval(str, env, store) when is_binary(str) do
    {str, env, store}
  end

  def eval(var, env, store) when is_atom(var) do
    {Map.fetch!(env, var), env, store}
  end

  def eval(func, env, store) when is_function(func) do
    {func, env, store}
  end

  def eval(map, env, store) when is_map(map) do
    {map
    |> Enum.map(fn {k, v} ->
       {k, _, _} = eval(k, env, store)
       {v, _, _} = eval(v, env, store)
       {k, v} end)
    |> Map.new(),
     env, store}
  end

  def eval({:closure, params, body, closure_env}, env, store) do
    {{:closure, params, body, closure_env}, env, store}
  end

  def eval({:cell, cell_id}, env, store) do
    {{:cell, cell_id}, env, store}
  end
  
  def eval({:native, module, functor}, env, store) do
    {{:native, module, functor}, env, store}
  end

  def eval([op | args], env, store) do
    # IO.inspect(op)
    # IO.inspect(args)
    # IO.inspect(env)
    case op do
      :if ->
        {cond_statement, _, _} = eval(hd(args), env, store)
        if cond_statement do
          eval(Enum.at(args, 1), env, store)
        else
          eval(Enum.at(args, 2), env, store)
        end

      :quote ->
        {[:quote, hd(args)], env, store}

      :list ->
        {[:list | Enum.map(args, fn arg ->
             {arg, _, _} = eval(arg, env, store)
             arg
           end)], env, store}

      :car ->
        case eval(hd(args), env, store) do
          {[:list | args], _, _} -> {hd(args), env, store}
          _ -> :car_err
        end

      :cdr ->
        case eval(hd(args), env, store) do
          {[:list | args], _, _} ->
            if length(args) == 1 do
              {nil, env, store}
            else
              {[:list | tl(args)], env, store}
            end

          _ ->
            :cdr_err
        end

      :cons ->
        {car, _, _} = eval(hd(args), env, store)

        case eval(Enum.at(args, 1), env, store) do
          {[:list | args], _, _} -> {[:list, car | args], env, store}
          {nil, _, _} -> {[:list, car], env, store}
          _ -> :cons_err
        end

      :and ->
        case eval(hd(args), env, store) do
          {true, _, _} -> eval(Enum.at(args, 1), env, store)
          {false, _, _} -> {false, env, store}
        end

      :or ->
        case eval(hd(args), env, store) do
          {true, _, _} -> {true, env, store}
          {false, _, _} -> eval(Enum.at(args, 1), env, store)
        end

      :lambda ->
        {{:closure, hd(args), Enum.at(args, 1), env}, env, store}

      :let ->
        [name, val, body] = args
        {val, _, _} = eval(val, env, store)
        eval(body, Map.put(env, name, val), store)

      :do ->
        Enum.reduce(args, {nil, env, store},
          fn arg, {_, acc, store} ->
            eval(arg, acc, store)
          end)

      :function ->
        [name, params, body] = args
        cell_id = Base.encode16(:crypto.strong_rand_bytes(8))
        closure_env = Map.put(env, name, {:cell, cell_id})
        
        {name, closure_env, Map.put(store, cell_id, {:closure, params, body, closure_env})}
        
        :apply ->
        [op, args] = args

        {args, _, _} = eval(args, env, store)

        case eval(op, env, store) do
          {{:cell, cell_id}, _, _} ->
            closure = Map.fetch!(store, cell_id)
            eval([:apply, closure, args], env, store)
            
          {{:closure, params, body, closure_env}, _, _} ->
            call_env =
              Enum.reduce(
                Enum.zip(params, tl(args)),
                closure_env,
                fn {param, arg}, acc ->
                  Map.put(acc, param, arg)
                end
              )

            eval(
              body,
              call_env,
              store
            )

          {{:native, module, functor}, _, _} ->
            {apply(module, functor, tl(args)), env, store}

          _ ->
            :op_err
        end

      _ ->
        eval([:apply, op, [:list | args]], env, store)
    end
  end

  def eval(expr) do
    {env, store} = default_env()
    {result, _, _} = eval(expr, env, store)
    result
  end

  def ast_to_scheme(n) when is_integer(n) do
    n
  end

  def ast_to_scheme(true) do
    true
  end

  def ast_to_scheme(false) do
    false
  end

  def ast_to_scheme(nil) do
    nil
  end

  def ast_to_scheme(k) when is_atom(k) do
    Atom.to_string(k)
  end

  def ast_to_scheme(b) when is_boolean(b) do
    b
  end

  def ast_to_scheme(xs) when is_list(xs) do
    [:list | Enum.map(xs, fn x -> ast_to_scheme(x) end)]
  end

  def ast_to_scheme(
        {:if, _, [condition, [do: if_branch, else: else_branch]]}
      ) do
    [
      :if,
      ast_to_scheme(condition),
      ast_to_scheme(if_branch),
      ast_to_scheme(else_branch)
    ]
  end

  def ast_to_scheme({:fn, _, [{:->, _, [inputs, body]}]}) do
    [
      :lambda,
      Enum.map(inputs, fn i -> ast_to_scheme(i) end),
      ast_to_scheme(body)
    ]
  end

  def ast_to_scheme({:%{}, _, kvs}) do
    # Maps
    Map.new(kvs)
  end

  def ast_to_scheme({:%, _, [mod, {:%{}, _, kvs}]}) do
    # Structs
    mod = ast_to_scheme(mod)

    kvs =
      Enum.map(kvs, fn {k, v} ->
        {ast_to_scheme(k), ast_to_scheme(v)}
      end)

    ast_to_scheme({:%{}, [], kvs ++ [{"__struct__", mod}]})
  end

  def ast_to_scheme({:__aliases__, _, mod}) do
    Atom.to_string(Module.concat(mod))
  end

  def ast_to_scheme({:., _, [mod, fn_name]}) do
    # Module namespaced function
    _mod = ast_to_scheme(mod)

    fn_name
  end

  def ast_to_scheme({fn_name, _, args}) when is_list(args) do
    # Function Application
    func = ast_to_scheme(fn_name)
    args = Enum.map(args, fn x -> ast_to_scheme(x) end)

    [func | args]
  end

  def ast_to_scheme({:erlang, _, _}), do: :erlang

  def ast_to_scheme({sym, _, _mod}) do
    sym
  end
end
