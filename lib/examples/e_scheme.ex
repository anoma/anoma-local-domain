defmodule Examples.EScheme do
  require ExUnit.Assertions
  import ExUnit.Assertions

  alias Anoma.LocalDomain.Scheme
  use Anoma.LocalDomain.Scheme

  defrisc(inc(x), do: :erlang.+(x, 1))

  def list() do
    [:list, 1, 2, 3]
  end

  def dict() do
    %{"a" => 3}
  end

  def lambda() do
    [:lambda, [:a], [:+, :a, 1]]
  end

  def apply() do
    result = Scheme.eval([:apply, lambda(), [:list, 1]])
    assert result == 2
    result
  end

  def native_plus() do
    result = Scheme.eval([:+, 1, 2])
    assert result == 3
    result
  end

  def native_at() do
    expr = [:at, list(), 2]
    result = Scheme.eval(expr)
    assert result == 3
    result
  end

  def map() do
    expr = [:map, list(), lambda()]
    result = Scheme.eval(expr)
    assert result == [:list, 2, 3, 4]
    result
  end

  def apply_map() do
    expr = [
      :apply,
      [:lambda, [:x], [:+, :x, 1]],
      [:map, [:list, 1], [:lambda, [:x], [:+, :x, 1]]]
    ]

    result = Scheme.eval(expr)
    assert result == 3
    result
  end

  def filter() do
    filter = [:lambda, [:x], [:==, :x, 1]]
    expr = [:filter, list(), filter]
    result = Scheme.eval(expr)
    assert result == [:list, 1]
    result
  end

  def nthcdr() do
    expr = [:nthcdr, list(), 2]
    result = Scheme.eval(expr)
    assert result == [:list, 3]
    result
  end

  def take() do
    expr = [:take, list(), 2]
    result = Scheme.eval(expr)
    assert result == [:list, 1, 2]
    result
  end

  def get() do
    result = Scheme.eval([:get, dict(), "a"])
    result
  end

  def put() do
    result = Scheme.eval([:put, dict(), "b", 1])
    result
  end

  def car() do
    result = Scheme.eval([:car, list()])
    assert result == 1
    result
  end

  def cdr() do
    result = Scheme.eval([:cdr, list()])
    assert result == [:list, 2, 3]
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
             :lambda,
             [:x],
             [:+, :x, 1]
           ]

    r
  end

  def get_to_scheme() do
    [:get | r] =
      Scheme.ast_to_scheme(
        quote do
          Map.get(%{a: %{b: 3}}, :a)
        end
      )

    [:get | r]
  end

  def filter_to_scheme() do
    [:filter | r] =
      Scheme.ast_to_scheme(
        quote do
          Enum.filter([1, 2, 3], fn finding ->
            :erlang.==(finding, 1)
          end)
        end
      )

    [:filter | r]
  end

  def struct_to_scheme_no_template() do
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

    assert Map.get(r, "__struct__") ==
             "Elixir.Anoma.LocalDomain.Resource"

    r
  end

  def struct_to_scheme() do
    s =
      quote do
        %Anoma.LocalDomain.Resource{
          data: 3,
          logic: fn x -> Examples.EScheme.inc_2(x) end,
          type: NA
        }
      end

    r = Scheme.ast_to_scheme(s)
    assert length(Map.keys(r)) == 4

    assert Map.get(r, "__struct__") ==
             "Elixir.Anoma.LocalDomain.Resource"

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

    assert hd(r) == :if
    r
  end
end
