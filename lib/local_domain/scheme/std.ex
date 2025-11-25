defmodule Anoma.LocalDomain.Scheme.Std do
  use Anoma.LocalDomain.Scheme

  defscheme length(xs) do
    [
      :if,
      [:==, :xs, nil],
      0,
      [:+, 1, [:self, [:cdr, :xs]]]
    ]
  end

  defscheme at(xs, n) do
    [
      :if,
      [:==, :n, 0],
      [:car, :xs],
      [:self, [:cdr, :xs], [:-, :n, 1]]
    ]
  end

  defscheme map(xs, f) do
    [
      :if,
      [:==, :xs, nil],
      nil,
      [
        :cons,
        [:f, [:car, :xs]],
        [:self, [:cdr, :xs], :f]
      ]
    ]
  end

  defscheme filter(xs, f) do
    [
      :if,
      [:==, :xs, nil],
      nil,
      [
        :if,
        [:f, [:car, :xs]],
        [
          :cons,
          [:car, :xs],
          [:self, [:cdr, :xs], :f]
        ],
        [:self, [:cdr, :xs], :f]
      ]
    ]
  end

  defscheme nthcdr(xs, n) do
    [
      :if,
      [:==, :n, 0],
      :xs,
      [:self, [:cdr, :xs], [:-, :n, 1]]
    ]
  end

  defscheme take(xs, n) do
    [
      :if,
      [:==, :n, 0],
      nil,
      [
        :cons,
        [:car, :xs],
        [:self, [:cdr, :xs], [:-, :n, 1]]
      ]
    ]
  end
end
