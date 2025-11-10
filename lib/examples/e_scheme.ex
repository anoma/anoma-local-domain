defmodule Examples.EScheme do
  require ExUnit.Assertions
  import ExUnit.Assertions

  alias Anoma.LocalDomain.Scheme

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
    result = Scheme.eval(["apply", lambda(), 1])
    assert result == 2
    result
  end

  def native() do
    result = Scheme.eval(["+", 1, 2])
    assert result == 3
    result
  end

  def map() do
    result = Scheme.eval(["map", lambda(), list()])
    assert result == ["list", 2, 3, 4]
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

  def funcall() do
    result = Scheme.eval(["funcall", "+", ["list", 1, 2]])
    assert result == 3
    result
  end

  def funcall_map() do
    result =
      Scheme.eval([
        "funcall",
        "+",
        ["map", ["lambda", ["a"], ["+", 1, "a"]], ["list", 1, 2]]
      ])

    assert result == 5

    result
  end
end
