defmodule Anoma.LocalDomain.OTPApplication do
  @moduledoc """
  I am the top level OTP application callback module for the Anoma Local Domain.
  I manage the nodepool and other shared processes.

  Named `OTPApplication` rather than `Application` because of the unfortunate
  name collision with local domain applications.
  """

  use Application

  @impl true
  def start(_, _args) do
    children = [
      {DynamicSupervisor,
       name: AppTasksSupervisor, strategy: :one_for_one},
      {Elixir.Registry,
       keys: :unique, name: Anoma.LocalDomain.Registry},
      {DynamicSupervisor, name: Anoma.LocalDomain.NodePool}
    ]

    opts = [strategy: :one_for_one, name: Anoma.LocalDomain.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_node(
        node_id \\ Base.encode16(:crypto.strong_rand_bytes(32))
      ) do
    DynamicSupervisor.start_child(
      Anoma.LocalDomain.NodePool,
      {Anoma.LocalDomain.NodeSupervisor, [node_id: node_id]}
    )
  end
end
