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

  defscheme apply(fun, args) do
    [:if, [:is_null, :args],
     [:fun],
     [[:function, :_, [:arg0, :args],
       [:if, [:is_null, :args],
        [:fun, :arg0],
        [[:function, :_, [:arg1, :args],
          [:if, [:is_null, :args],
           [:fun, :arg0, :arg1],
           [[:function, :_, [:arg2, :args],
             [:if, [:is_null, :args],
              [:fun, :arg0, :arg1, :arg2],
              [[:function, :_, [:arg3, :args],
                [:if, [:is_null, :args],
                 [:fun, :arg0, :arg1, :arg2, :arg3],
                 [[:function, :_, [:arg4, :args],
                   [:if, [:is_null, :args],
                    [:fun, :arg0, :arg1, :arg2, :arg3, :arg4],
                    [:fun, :arg0, :arg1, :arg2, :arg3, :arg4, :args]]
                 ], [:car, :args], [:cdr, :args]]]
              ], [:car, :args], [:cdr, :args]]]
           ], [:car, :args], [:cdr, :args]]]
        ], [:car, :args], [:cdr, :args]]]
     ], [:car, :args], [:cdr, :args]]]
  end
end
