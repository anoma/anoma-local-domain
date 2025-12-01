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

  @doc """
  Retrieve all scheme fns known by the registry and put into an environment
  """
  def default_env(extra \\ %{}) do
    {:ok, {scheme_fns, prelude_fns}} = Anoma.LocalDomain.SchemeRegistry.all_scheme()

    {Enum.reduce(extra, scheme_fns, fn {name, value}, acc ->
      put_env(acc, name, value)
    end), prelude_fns}
  end

  def new_env(), do: {%{}, 0, 1}


  @doc """
  Put a given binding into the environment
  """
  def put_env({tree, index, next}, name, value) do
    {Map.put(tree, next, {name, value, index}), next, next+1}
  end

  @doc """
  Get the value of the given identifier in the environment
  """
  def get_env({tree, index, next}, search_name) do
    {name, value, parent} = Map.fetch!(tree, index)
    if name == search_name do
      value
    else
      get_env({tree, parent, next}, search_name)
    end
  end

  @doc """
  Get the unique identifier for the given environment
  """
  def env_id({_tree, index, _next}), do: index

  @doc """
  Reserve a unique environment identifier to fill in later
  """
  def reserve_env({tree, index, next}) do
    {{tree, index, next+1}, next}
  end

  @doc """
  Insert the given binding at the given unique identifier
  """
  def insert_env({tree, index, next}, at, name, value) do
    {Map.put(tree, at, {name, value, index}), at, next}
  end

  @doc """
  Switch to the given environment
  """
  def switch_env({tree, _index, next}, target) do
    {tree, target, next}
  end

  @doc """
  Convert an ordinary Elixir map into an environment
  """
  def map_to_env(map) do
    Enum.reduce(map, new_env(), fn {name, value}, acc ->
      put_env(acc, name, value)
    end)
  end

  @doc """
  Add functions to the environment
  """
  def build_body_env([:function, name, params | body], {env, body_env_id}) do
    {put_env(env, name, {:closure, params, body, body_env_id}), body_env_id}
  end

  def build_body_env(_, acc), do: acc

  # Evaluate the given expression in the given environment

  def eval(obj, env) when is_number(obj) or is_boolean(obj) or is_binary(obj) or is_nil(obj) or is_function(obj) do
    {obj, env}
  end

  def eval(var, env) when is_atom(var) do
    {get_env(env, var), env}
  end

  def eval(map, env) when is_map(map) do
    {map, env} = map
    |> Enum.map_reduce(env, fn {k, v}, env ->
      {k, env} = eval(k, env)
      {v, env} = eval(v, env)
      {{k, v}, env} end)
    {Map.new(map), env}
  end

  def eval(closure = {:closure, _, _, _}, env), do: closure

  def eval(native = {:native, _, _}, env), do: native

  def eval([:if, cond, consequent, alternate], env) do
    {cond, env} = eval(cond, env)
    if cond do
      eval(consequent, env)
    else
      eval(alternate, env)
    end
  end

  def eval([:quote, expr], env), do: {expr, env}

  def eval([:function, name, params | body], env) do
    {env, closure_env_id} = reserve_env(env)
    closure = {:closure, params, body, closure_env_id}
    env = insert_env(env, closure_env_id, name, closure)
    {closure, env}
  end

  # Define evaluate by reducing to simpler expressions

  def eval([:and, expr1, expr2], env) do
    eval([:if, expr1, expr2, false], env)
  end

  def eval([:or, expr1, expr2], env) do
    eval([:if, expr1, true, expr2], env)
  end

  def eval([:list | args], env) do
    expansion = Enum.reduce(Enum.reverse(args), :null, fn elt, acc -> [:cons, elt, acc] end)
    eval(expansion, env)
  end

  def eval([:apply, op, args], env) do
    {args, env} = eval(args, env)
    {op, env} = eval(op, env)
    eval_apply(op, args, env)
  end

  def eval([op | args], env) do
    {args, env} = Enum.map_reduce(args, env, &eval/2)
    {op, env} = eval(op, env)
    eval_apply(op, args, env)
  end

  # Apply the given arguments to the given function

  def eval_apply({:closure, params, body, closure_env_id}, args, env) do
    caller_env_id = env_id(env)
    put_env = fn {param, arg}, acc -> put_env(acc, param, arg) end
    callee_env = switch_env(env, closure_env_id)
    callee_env = Enum.reduce(Enum.zip(params, args), callee_env, put_env)
    {callee_env, body_env_id} = reserve_env(callee_env)
    {callee_env, body_env_id} = Enum.reduce(body, {callee_env, body_env_id}, &build_body_env/2)
    callee_env = insert_env(callee_env, body_env_id, nil, nil)
    eval = fn expr, {_result, call_env} -> eval(expr, call_env) end
    {result, env} = Enum.reduce(body, {nil, callee_env}, eval)
    {result, switch_env(env, caller_env_id)}
  end

  def eval_apply({:native, module, functor}, args, env) do
    {apply(module, functor, args), env}
  end

  # Evaluate the given expression with a prelude prepended

  @doc """
  Evaluate the given expression with a prelude prepended
  """
  def eval(expr) do
    {env, prelude} = default_env()
    eval([[:function, :_, [] | prelude] ++ [expr]], env)
  end

  @doc """
  Turn an Elixir AST to Scheme
  """
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
      :function,
      :_,
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
