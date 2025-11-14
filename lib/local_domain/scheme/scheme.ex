defmodule Anoma.LocalDomain.Scheme do
  @moduledoc """
  I am the Scheme DSL Interpreter
  """

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :scheme_fns,
        accumulate: true
      )

      Module.register_attribute(__MODULE__, :risc0_template,
        accumulate: true
      )

      import Anoma.LocalDomain.Scheme
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    module = env.module
    scheme_fns = Module.get_attribute(module, :scheme_fns)
    risc0_template = Module.get_attribute(module, :risc0_template)

    quote do
      def __scheme_fns__ do
        unquote(Macro.escape(scheme_fns))
      end

      def __risc0_template__ do
        unquote(Macro.escape(risc0_template))
      end

      # This doesn't work first compilation, only recompilation
      @after_compile __MODULE__
      def __after_compile__(_env, _bytecode) do
        Anoma.LocalDomain.SchemeRegistry.register(unquote(module))
      end
    end
  end

  @doc """
  Define an elixir->scheme mapping
  """
  defmacro defrisc({name, _meta, args},
             do: [{:->, _, [[body_elixir], scheme_template]}]
           ) do
    ["list" | args_scheme] = ast_to_scheme(args)

    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote(body_elixir)
      end

      @risc0_template {unquote(name), unquote(args_scheme),
                       unquote(Macro.escape(body_elixir)),
                       unquote(scheme_template)}
    end
  end

  defmacro defrisc({name, _meta, args}, do: body_elixir) do
    ["list" | args_scheme] = ast_to_scheme(args)

    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote(body_elixir)
      end

      @risc0_template {unquote(name), unquote(args_scheme),
                       unquote(Macro.escape(body_elixir)), nil}
    end
  end

  defmacro defscheme({name_scheme, _meta, args},
             do: body_scheme
           ) do
    ["list" | args_scheme] = ast_to_scheme(args)

    quote do
      @scheme_fns {unquote(Atom.to_string(name_scheme)),
                   unquote(args_scheme), unquote(body_scheme)}
    end
  end

  defmacro defscheme({name_scheme, _meta, args}, name) do
    ["list" | args_scheme] = ast_to_scheme(args)

    quote do
      @scheme_fns {unquote(Atom.to_string(name_scheme)),
                   unquote(args_scheme), unquote(name)}
    end
  end

  def default_env(extra \\ %{}) do
    {:ok, scheme_fns} = Anoma.LocalDomain.SchemeRegistry.all_scheme()

    Map.merge(
      scheme_fns,
      extra
    )
  end

  def eval(num, _env) when is_number(num) do
    num
  end

  def eval(var, env) when is_binary(var) do
    Map.fetch!(env, var)
  end

  def eval(atom, _env) when is_atom(atom) do
    atom
  end

  def eval(func, _env) when is_function(func) do
    func
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

  def eval(map, env) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {eval(k, env), eval(v, env)} end)
    |> Map.new()
  end

  def eval({"closure", params, body}, _env) do
    {"closure", params, body}
  end

  def eval({"native", module, functor}, _env) do
    {"native", module, functor}
  end

  def eval([op | args], env) do
    case op do
      "if" ->
        if eval(hd(args), env) do
          eval(Enum.at(args, 1), env)
        else
          eval(Enum.at(args, 2), env)
        end

      "quote" ->
        hd(args)

      "list" ->
        ["list" | Enum.map(args, fn arg -> eval(arg, env) end)]

      "car" ->
        case eval(hd(args), env) do
          ["list" | args] -> hd(args)
          _ -> :err
        end

      "cdr" ->
        case eval(hd(args), env) do
          ["list" | args] ->
            if length(args) == 1 do
              nil
            else
              ["list" | tl(args)]
            end

          _ ->
            :err
        end

      "cons" ->
        car = eval(hd(args), env)

        case eval(Enum.at(args, 1), env) do
          ["list" | args] -> ["list", car | args]
          nil -> ["list", car]
          _ -> :err
        end

      "and" ->
        case eval(hd(args), env) do
          true -> eval(Enum.at(args, 1), env)
          false -> false
        end

      "or" ->
        case eval(hd(args), env) do
          true -> true
          false -> eval(Enum.at(args, 1), env)
        end

      "lambda" ->
        {"closure", hd(args), Enum.at(args, 1)}

      "apply" ->
        [op, args] = args

        args = eval(args, env)

        case eval(op, env) do
          {"closure", params, body} ->
            env =
              Enum.reduce(Enum.zip(params, tl(args)), env, fn {param,
                                                               arg},
                                                              acc ->
                Map.put(acc, param, arg)
              end)

            eval(body, env)

          {"native", module, functor} ->
            apply(module, functor, tl(args))

          _ ->
            :err
        end

      _ ->
        eval(["apply", op, ["list" | args]], env)
    end
  end

  def eval(expr) do
    eval(expr, default_env())
  end

  def elixir_fn_to_scheme(mod, name) do
    case Anoma.LocalDomain.SchemeRegistry.get_template(mod, name) do
      :absent ->
        {:ok, args, ast} =
          Anoma.LocalDomain.SchemeRegistry.get_ast(mod, name)

        ast_to_scheme(args, ast)

      {:ok, template} ->
        template
    end
  end

  def ast_to_scheme(args, ast) do
    {"closure", args, ast_to_scheme(ast)}
  end

  def ast_to_scheme(n) when is_integer(n) do
    n
  end

  def ast_to_scheme(k) when is_atom(k) do
    k
  end

  def ast_to_scheme(b) when is_boolean(b) do
    b
  end

  def ast_to_scheme(xs) when is_list(xs) do
    ["list" | Enum.map(xs, fn x -> ast_to_scheme(x) end)]
  end

  def ast_to_scheme(
        {:if, _, [condition, [do: if_branch, else: else_branch]]}
      ) do
    [
      "if",
      ast_to_scheme(condition),
      ast_to_scheme(if_branch),
      ast_to_scheme(else_branch)
    ]
  end

  def ast_to_scheme({:fn, _, [{:->, _, [inputs, body]}]}) do
    [
      "lambda",
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

    ast_to_scheme({:%{}, [], kvs ++ [__struct__: mod]})
  end

  def ast_to_scheme({:__aliases__, _, mod}) do
    Module.concat(mod)
  end

  def ast_to_scheme({:., _, [mod, fn_name]}) do
    # Module namespaced function
    mod = ast_to_scheme(mod)

    elixir_fn_to_scheme(mod, fn_name)
  end

  def ast_to_scheme({fn_name, _, args}) when is_list(args) do
    # Function Application
    [
      ast_to_scheme(fn_name)
      | Enum.map(args, fn x -> ast_to_scheme(x) end)
    ]
  end

  def ast_to_scheme({:erlang, _, _}), do: :erlang

  def ast_to_scheme({sym, _, _mod}) do
    # Syms are currently strings
    Atom.to_string(sym)
  end
end
