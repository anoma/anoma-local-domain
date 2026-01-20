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

  defscheme cdddr(sexpr) do
    [:cddr, [:cdr, :sexpr]]
  end

  defscheme cddr(sexpr) do
    [:cdr, [:cdr, :sexpr]]
  end

  defscheme quote(sexpr) do
    [[:function, :quote_aux, [:sexpr],
      [:if, [:is_null, :sexpr],
       [:string_to_atom, ":null"],
       [:if, [:is_pair, :sexpr],
        [:if,
         [:if, [:==, [:car, :sexpr], [:string_to_atom, ":unquote"]],
          [:is_null, [:cddr, :sexpr]],
          false],
         [:cadr, :sexpr],
         [:cons,
          [:string_to_atom, ":cons"],
          [:cons,
           [:quote_aux, [:car, :sexpr]],
           [:cons, [:quote_aux, [:cdr, :sexpr]], :null]]]],
        [:cons,
         [:string_to_atom, ":string_to_atom"],
         [:cons, [:atom_to_string, :sexpr], :null]]]]
    ], [:caddr, :sexpr]]
  end

  defscheme let(sexpr) do
    {:quote,
     [[:function, :let_aux,
       # binding names
       [:unquote, [:map, [:caddr, :sexpr], :car]],
       # body
       :unquote, [:cdddr, :sexpr]],
      # binding values
      :unquote, [:map, [:caddr, :sexpr], :cadr]]}
  end

  defscheme andm(sexpr) do
    [[:function, :andm_aux, [:sexpr],
      [:if, [:is_null, :sexpr],
       [:string_to_atom, ":true"],
       {:quote,
        {:let, [[:and_temp, [:unquote, [:car, :sexpr]]]],
         [:if, :and_temp, [:unquote, [:andm_aux, [:cdr, :sexpr]]], :and_temp]}}]
    ], [:cddr, :sexpr]]
  end

  defscheme orm(sexpr) do
    [[:function, :orm_aux, [:sexpr],
      [:if, [:is_null, :sexpr],
       [:string_to_atom, ":false"],
       {:quote,
        {:let, [[:or_temp, [:unquote, [:car, :sexpr]]]],
         [:if, :or_temp, :or_temp, [:unquote, [:orm_aux, [:cdr, :sexpr]]]]}}]
    ], [:cddr, :sexpr]]
  end

  defscheme list(sexpr) do
    [[:function, :list_aux, [:sexpr],
      [:if, [:is_null, :sexpr],
       [:string_to_atom, ":null"],
       {:quote,
        [:cons, [:unquote, [:car, :sexpr]], [:unquote, [:list_aux, [:cdr, :sexpr]]]]}]
    ], [:cddr, :sexpr]]
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
