defmodule Anoma.LocalDomain.Scheme do
  @moduledoc """
  I am the Scheme Interpreter for Risc0
  """
  
  def default_env(extra \\ %{}) do
    Map.merge(
      %{
        "+" => {"native", :erlang, :+},
        "==" => {"native", :erlang, :==},
        "integerp" => {"native", :erlang, :is_number},
        "get" => {"native", Map, :get},
        "put" => {"native", Map, :put},
        "not" => {"native", :erlang, :not}
      },
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
    # IO.inspect(op)
    # IO.inspect(args)

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
          ["list" | args] -> ["list" | tl(args)]
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

      "map" ->
        ["list" | lst] = eval(Enum.at(args, 1), env)
        lambda = eval(hd(args), env)

        [
          "list"
          | Enum.map(lst, fn arg -> eval(["apply", lambda, arg]) end)
        ]

      "filter" ->
        ["list" | lst] = eval(Enum.at(args, 1), env)
        lambda = eval(hd(args), env)

        [
          "list"
          | Enum.filter(lst, fn arg -> eval(["apply", lambda, arg]) end)
        ]

      "take" ->
        ["list" | lst] = eval(Enum.at(args, 1), env)
        number = eval(hd(args), env)

        [
          "list"
          | Enum.take(lst, number)
        ]
        
        
      "funcall" ->
        functor = eval(hd(args), env)
        ["list" | args] = eval(Enum.at(args, 1), env)
        eval([functor | args], env)

      "apply" ->
        [op | args] = args

        case eval(op, env) do
          {"closure", params, body} ->
            env =
              Enum.reduce(Enum.zip(params, args), env, fn {param, arg},
                                                          acc ->
                Map.put(acc, param, eval(arg, env))
              end)

            eval(body, env)

          {"native", module, functor} ->
            args = Enum.map(args, fn arg -> eval(arg, env) end)
            apply(module, functor, args)
        end

      _ ->
        eval(["apply" | [op | args]], env)
    end
  end

  def eval(expr) do
    eval(expr, default_env())
  end
end
