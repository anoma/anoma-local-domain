defmodule Anoma.LocalDomain.DefScry do
  @moduledoc """
  I contain the defscry macro. Require or use me to use defscry.
  """
  
  defmacro __using__(_opts) do
    quote do
      import Anoma.LocalDomain.DefScry
    end
  end
  
  defmacro defscry(do: clauses) do
    expanded = Enum.map(clauses,
      fn {:->, _, [head, body]} ->
        quote do
          @impl true
          def scry unquote_splicing(head) do
            unquote(body)
          end
        end
      end
    )

    super_scry = quote do
      @impl true
      def scry(prev_prefixes, key) do
        super(prev_prefixes, key)
      end
    end
    
    expanded_with_super = expanded ++ [super_scry]
    
    {:__block__, [], expanded_with_super}
  end
end
