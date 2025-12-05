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

  defscheme cadr(sexpr) do
    [:car, [:cdr, :sexpr]]
  end

  defscheme caddr(sexpr) do
    [:cadr, [:cdr, :sexpr]]
  end

  defscheme cadddr(sexpr) do
    [:caddr, [:cdr, :sexpr]]
  end

  defscheme let(sexpr) do
    [:cons,
     [:cons,
      [:string_to_atom, ":function"],
      [:cons, [:string_to_atom, ":let_aux"],
       [:cons,
        [:map, [:caddr, :sexpr], :car],
        [:cons, [:cadddr, :sexpr], :null]]]],
     [:map, [:caddr, :sexpr], :cadr]]
  end

  defscheme apply(fun, args) do
    [:if, [:is_null, :args],
     [:fun],
     {:let, [[:arg0, [:car, :args]], [:args, [:cdr, :args]]],
       [:if, [:is_null, :args],
        [:fun, :arg0],
        {:let, [[:arg1, [:car, :args]], [:args, [:cdr, :args]]],
          [:if, [:is_null, :args],
           [:fun, :arg0, :arg1],
           {:let, [[:arg2, [:car, :args]], [:args, [:cdr, :args]]],
             [:if, [:is_null, :args],
              [:fun, :arg0, :arg1, :arg2],
              {:let, [[:arg3, [:car, :args]], [:args, [:cdr, :args]]],
                [:if, [:is_null, :args],
                 [:fun, :arg0, :arg1, :arg2, :arg3],
                 {:let, [[:arg4, [:car, :args]], [:args, [:cdr, :args]]],
                   [:if, [:is_null, :args],
                    [:fun, :arg0, :arg1, :arg2, :arg3, :arg4],
                    [:fun, :arg0, :arg1, :arg2, :arg3, :arg4, :args]]}]}]}]}]}]
  end
end
