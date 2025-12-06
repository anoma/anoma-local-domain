defmodule Examples.EScheme do
  require ExUnit.Assertions
  import ExUnit.Assertions

  alias Anoma.LocalDomain.Scheme
  use Anoma.LocalDomain.Scheme

  defrisc(inc(x), do: :erlang.+(x, 1))

  def list() do
    {:list, 1, 2, 3}
  end

  def dict() do
    %{"a" => 3}
  end

  def lambda() do
    [:function, :_, [:a], [:+, :a, 1]]
  end

  def apply() do
    {result, _env} = Scheme.eval([[:apply, lambda(), [:list, 1]]])
    assert result == 2
    result
  end

  def native_plus() do
    {result, _env} = Scheme.eval([[:+, 1, 2]])
    assert result == 3
    result
  end

  def and_macro() do
    {false, _env} = Scheme.eval([{:andm, :true, :false}])
    {true, _env} = Scheme.eval([{:andm, :true, :true, :true}])
    {false, _env} = Scheme.eval([{:andm, :false, :true}])
    {false, _env} = Scheme.eval([{:andm, :false, :false}])
  end

  def or_macro() do
    {true, _env} = Scheme.eval([{:orm, :true, :false}])
    {true, _env} = Scheme.eval([{:orm, :true, :true, :true}])
    {true, _env} = Scheme.eval([{:orm, :false, :true}])
    {false, _env} = Scheme.eval([{:orm, :false, :false}])
  end

  def native_at() do
    expr = [:at, list(), 2]
    {result, _env} = Scheme.eval([expr])
    assert result == 3
    result
  end

  def map() do
    expr = [:map, list(), lambda()]
    {result, _env} = Scheme.eval([expr])
    assert result == [2, 3, 4]
    result
  end

  def apply_map() do
    expr = [
      :apply,
      [:function, :_, [:x], [:+, :x, 1]],
      [:map, [:list, 1], [:function, :_, [:x], [:+, :x, 1]]]
    ]

    {result, _env} = Scheme.eval([expr])
    assert result == 3
    result
  end

  def mutual_recursion() do
    expr = [
      [
        :function,
        :_,
        [],
        [
          :function,
          :odd,
          [:n],
          [:if, [:==, :n, 0], false, [:even, [:-, :n, 1]]]
        ],
        [
          :function,
          :even,
          [:n],
          [:if, [:==, :n, 0], true, [:odd, [:-, :n, 1]]]
        ],
        [:even, 8]
      ]
    ]

    {result, _env} = Scheme.eval([expr])
    assert result == true
    result
  end

  def filter() do
    filter = [:function, :_, [:x], [:==, :x, 1]]
    expr = [:filter, list(), filter]
    {result, _env} = Scheme.eval([expr])
    assert result == [1]
    result
  end

  def nthcdr() do
    expr = [:nthcdr, list(), 2]
    {result, _env} = Scheme.eval([expr])
    assert result == [3]
    result
  end

  def take() do
    expr = [:take, list(), 2]
    {result, _env} = Scheme.eval([expr])
    assert result == [1, 2]
    result
  end

  def get() do
    result = Scheme.eval([[:get, dict(), "a"]])
    result
  end

  def put() do
    result = Scheme.eval([[:put, dict(), "b", 1]])
    result
  end

  def car() do
    {result, _env} = Scheme.eval([[:car, list()]])
    assert result == 1
    result
  end

  def cdr() do
    {result, _env} = Scheme.eval([[:cdr, list()]])
    assert result == [2, 3]
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
             :function,
             :_,
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
