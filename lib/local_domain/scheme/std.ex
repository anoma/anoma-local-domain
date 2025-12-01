defmodule Anoma.LocalDomain.Scheme.Std do
  use Anoma.LocalDomain.Scheme

  defscheme length(xs) do
    [
      :if,
      [:is_null, :xs],
      0,
      [:+, 1, [:length, [:cdr, :xs]]]
    ]
  end

  defscheme at(xs, n) do
    [
      :if,
      [:==, :n, 0],
      [:car, :xs],
      [:at, [:cdr, :xs], [:-, :n, 1]]
    ]
  end

  defscheme map(xs, f) do
    [
      :if,
      [:is_null, :xs],
      :null,
      [
        :cons,
        [:f, [:car, :xs]],
        [:map, [:cdr, :xs], :f]
      ]
    ]
  end

  defscheme filter(xs, f) do
    [
      :if,
      [:is_null, :xs],
      :null,
      [
        :if,
        [:f, [:car, :xs]],
        [
          :cons,
          [:car, :xs],
          [:filter, [:cdr, :xs], :f]
        ],
        [:filter, [:cdr, :xs], :f]
      ]
    ]
  end

  defscheme nthcdr(xs, n) do
    [
      :if,
      [:==, :n, 0],
      :xs,
      [:nthcdr, [:cdr, :xs], [:-, :n, 1]]
    ]
  end

  defscheme take(xs, n) do
    [
      :if,
      [:==, :n, 0],
      :null,
      [
        :cons,
        [:car, :xs],
        [:take, [:cdr, :xs], [:-, :n, 1]]
      ]
    ]
  end
end
