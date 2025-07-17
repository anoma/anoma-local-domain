defmodule Anoma.LocalDomain.System.Prover do
  @moduledoc """
  I define the Prover application for the local domain.
  Prover acts as an interface for proof systems available within local domain, storing information on which proof systems are available.
  """

  use Anoma.LocalDomain.Application, name: "prover"
  use Anoma.LocalDomain.DefScry

  defmacro __using__(_opts) do
    quote do

      @behaviour Anoma.LocalDomain.System.Prover

      def prove(_provingkey, _instance, _witness) do
        {:error, :no_handler}
      end
      
      defoverridable prove: 3

      def verify(_verifyingkey, _instance, _proof) do
        {:error, :no_handler}
      end
      
      defoverridable verify: 3
    end    
  end

  @callback prove(binary(), term(), term()) :: {:ok, term()} | {:error, term()}
  @callback verify(binary(), term(), term()) :: {:ok, term()} | {:error, term()}

  def get_systems() do
    Anoma.LocalDomain.Storage.read_local(~k"/prover/systems")
  end

  def register_system(name) do
    {:ok, current} =
      Anoma.LocalDomain.Storage.read_local(~k"/prover/systems")

    Anoma.LocalDomain.Storage.write_local(
      ~k"/prover/systems",
      current |> MapSet.put(name)
    )
    end

  @impl true
  def init() do
    super()

    # if there is no set of systems registered, initialize with an empty list
    case Anoma.LocalDomain.Storage.read_local(~k"/prover/systems") do
      {:ok, _} ->
        :ok

      :absent ->
        Anoma.LocalDomain.Storage.write_local(
          ~k"/prover/systems",
          MapSet.new([])
        )

        :ok
    end
  end
  
 
  # defscry do
  #   (_prev_prefixes, ~k"/prove/!system/!provingkey/!instance/!witness") ->
  #     :instance
  #     :witness
  #     :provingkey
  #     :system
  #   (_prev_prefixes, ~k"/verify/!system/!instancekey/!instance/!proof") ->
  #     :instancekey
  #     :instance
  #     :proof
  #     :system
  #     true
  # end
  
end
