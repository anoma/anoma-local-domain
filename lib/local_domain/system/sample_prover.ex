defmodule Anoma.LocalDomain.System.SampleProver do
  use Anoma.LocalDomain.Application, name: "SampleProver"
  use Anoma.LocalDomain.DefScry
  use Anoma.LocalDomain.System.Prover

  @impl true
  def prove(_provingkey, _instance, _witness) do
    :ok
  end

  @impl true
  def verify(_verifyingkey, _instance, _proof) do
    :ok
  end

  @impl true
  def init(args) do
    super(args)

    Anoma.LocalDomain.System.Prover.register_system(
      args[:node_id],
      "prover"
    )
  end
end
