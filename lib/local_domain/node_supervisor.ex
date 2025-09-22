defmodule Anoma.LocalDomain.NodeSupervisor do
  @moduledoc """
  I am the supervisor callback module for a local domain node
  """

  use Supervisor

  @spec child_spec(any()) :: map()
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary
    }
  end

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(args) do
    name = Anoma.LocalDomain.Registry.via(args[:node_id], __MODULE__)
    Supervisor.start_link(__MODULE__, args, name: name)
  end

  @impl true
  def init(args) do
    node_id = args[:node_id]

    children = [
      # {Anoma.LocalDomain.Scry.HandlerRegistry, node_id: node_id},
      {Anoma.LocalDomain.Storage, node_id: node_id},
      %{
        id: Anoma.LocalDomain.ApplicationStartup,
        restart: :transient,
        start:
          {Anoma.LocalDomain.ApplicationStartup, :start_applications,
           [[node_id: node_id]]}
      }
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
