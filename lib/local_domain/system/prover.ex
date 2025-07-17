defmodule Anoma.LocalDomain.System.Prover do
  @moduledoc """
  I define the Prover application for the local domain.

  Prover dispatches to a proof system on the local machine. 
  """

  use Anoma.LocalDomain.Application, name: "prover"
  use Anoma.LocalDomain.DefScry

  # defscry do
  #   (_prev_prefixes, ~k"") -> {:ok, true}
  # end
  
end
