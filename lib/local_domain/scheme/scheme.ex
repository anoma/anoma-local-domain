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

  def default_env(extra \\ %{}) do
    {:ok, scheme_fns} = Anoma.LocalDomain.SchemeRegistry.all_scheme()

    map_to_env(Map.merge(
      scheme_fns,
      extra
    ))
  end

  def new_env(), do: {%{}, 0, 1}

  # Put the given binding into the environment

  def put_env({tree, index, next}, name, value) do
    {Map.put(tree, next, {name, value, index}), next, next+1}
  end

  # Get the value of the given identifier in the environment

  def get_env({tree, index, next}, search_name) do
    {name, value, parent} = Map.fetch!(tree, index)
    if name == search_name do
      value
    else
      get_env({tree, parent, next}, search_name)
    end
  end

  # Get the unique identifier for the given environment

  def env_id({tree, index, next}), do: index

  # Reserve a unique environment identifier to filled later

  def reserve_env({tree, index, next}) do
    {{tree, index, next+1}, next}
  end

  # Insert the given binding at the given unique identifier

  def insert_env({tree, index, next}, at, name, value) do
    {Map.put(tree, at, {name, value, index}), at, next}
  end

  # Convert an ordinary Elixir map into an environment

  def map_to_env(map) do
    Enum.reduce(map, new_env(), fn {name, value}, acc ->
      put_env(acc, name, value)
    end)
  end

  def eval(num, _env) when is_number(num) do
    num
  end

  def eval(true, _env) do
    true
  end

  def eval(false, _env) do
    false
  end

  def eval(nil, _env) do
    nil
  end

  def eval(str, _env) when is_binary(str) do
    str
  end

  def eval(var, env) when is_atom(var) do
    get_env(env, var)
  end

  def eval(func, _env) when is_function(func) do
    func
  end

  def eval(map, env) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {eval(k, env), eval(v, env)} end)
    |> Map.new()
  end

  def eval({:closure, params, body}, _env) do
    {:closure, params, body}
  end

  def eval({:native, module, functor}, _env) do
    {:native, module, functor}
  end

  def eval([op | args], env) do
    case op do
      :if ->
        if eval(hd(args), env) do
          eval(Enum.at(args, 1), env)
        else
          eval(Enum.at(args, 2), env)
        end

      :quote ->
        hd(args)

      :list ->
        [:list | Enum.map(args, fn arg -> eval(arg, env) end)]

      :car ->
        case eval(hd(args), env) do
          [:list | args] -> hd(args)
          _ -> :err
        end

      :cdr ->
        case eval(hd(args), env) do
          [:list | args] ->
            if length(args) == 1 do
              nil
            else
              [:list | tl(args)]
            end

          _ ->
            :err
        end

      :cons ->
        car = eval(hd(args), env)

        case eval(Enum.at(args, 1), env) do
          [:list | args] -> [:list, car | args]
          nil -> [:list, car]
          _ -> :err
        end

      :and ->
        case eval(hd(args), env) do
          true -> eval(Enum.at(args, 1), env)
          false -> false
        end

      :or ->
        case eval(hd(args), env) do
          true -> true
          false -> eval(Enum.at(args, 1), env)
        end

      :lambda ->
        {:closure, hd(args), Enum.at(args, 1), env}

      :apply ->
        [op, args] = args

        args = eval(args, env)

        case eval(op, env) do
          {:closure, params, body, closure_env} ->
            call_env =
              Enum.reduce(
                Enum.zip(params, tl(args)),
                closure_env,
                fn {param, arg}, acc ->
                  put_env(acc, param, arg)
                end
              )

            eval(
              body,
              put_env(
                call_env,
                :self,
                {:closure, params, body, closure_env}
              )
            )

          {:native, module, functor} ->
            apply(module, functor, tl(args))

          _ ->
            :err
        end

      _ ->
        eval([:apply, op, [:list | args]], env)
    end
  end

  def eval(expr) do
    eval(expr, default_env())
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
