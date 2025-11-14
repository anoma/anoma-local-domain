defmodule Examples.EScheme do
  require ExUnit.Assertions
  import ExUnit.Assertions

  alias Anoma.LocalDomain.Scheme
  use Anoma.LocalDomain.Scheme

  defscheme "inc", inc(x) do
    :erlang.+(x, 1) -> {"closure", ["x"], ["+", "x", 1]}
  end

  def list() do
    ["list", 1, 2, 3]
  end

  def dict() do
    %{a: 3}
  end

  def lambda() do
    ["lambda", ["a"], ["+", "a", 1]]
  end

  def apply() do
    result = Scheme.eval(["apply", lambda(), ["list", 1]])
    assert result == 2
    result
  end

  def native_plus() do
    result = Scheme.eval(["+", 1, 2])
    assert result == 3
    result
  end

  def native_nth() do
    expr = ["nth", list(), 2]
    result = Scheme.eval(expr)
    assert result == 3
    result
  end

  def map() do
    expr = ["map", list(), lambda()]
    result = Scheme.eval(expr)
    assert result == ["list", 2, 3, 4]
    result
  end

  def apply_map() do
    expr = [
      "apply",
      ["lambda", ["x"], ["+", "x", 1]],
      ["map", ["list", 1], ["lambda", ["x"], ["+", "x", 1]]]
    ]

    result = Scheme.eval(expr)
    assert result == 3
    result
  end

  def filter() do
    filter = ["lambda", ["x"], ["==", "x", 1]]
    expr = ["filter", list(), filter]
    result = Scheme.eval(expr)
    assert result == ["list", 1]
    result
  end

  def nthcdr() do
    expr = ["nthcdr", list(), 2]
    result = Scheme.eval(expr)
    assert result == ["list", 3]
    result
  end

  def take() do
    expr = ["take", list(), 2]
    result = Scheme.eval(expr)
    assert result == ["list", 1, 2]
    result
  end

  def get() do
    result = Scheme.eval(["get", dict(), :a])
    result
  end

  def put() do
    result = Scheme.eval(["put", dict(), :b, 1])
    result
  end

  def car() do
    result = Scheme.eval(["car", list()])
    assert result == 1
    result
  end

  def cdr() do
    result = Scheme.eval(["cdr", list()])
    assert result == ["list", 2, 3]
    result
  end

  def fn_to_scheme() do
    r =
      Scheme.ast_to_scheme(
        quote do
          fn x -> erlang.+(x, 1) end
        end
      )

    assert r == [
             "lambda",
             ["x"],
             ["+", "x", 1]
           ]

    r
  end

  def struct_to_scheme() do
    s =
      quote do
        %Anoma.LocalDomain.Resource{
          data: 3,
          logic: fn x -> Examples.EScheme.inc(x) end,
          type: NA
        }
      end

    r = Scheme.ast_to_scheme(s)
    assert length(Map.keys(r)) == 4
    assert Map.get(r, :__struct__) == Anoma.LocalDomain.Resource
    r
  end

  def if_to_scheme() do
    clause =
      quote do
        if x do
          y
        else
          z
        end
      end

    r = Scheme.ast_to_scheme(clause)

    assert hd(r) == "if"
    r
  end

  def get_scheme_registry_fails() do
    {:ok, nil} =
      Anoma.LocalDomain.SchemeRegistry.get_elixir(:erlang, "blah")
  end
end
