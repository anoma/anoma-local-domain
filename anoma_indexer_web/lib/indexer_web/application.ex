defmodule IndexerWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Anoma.LocalDomain.System.Poller.start()

    children = [
      {Plug.Cowboy, scheme: :http, plug: IndexerWeb.Router, options: [port: 4000]}
      # Starts a worker by calling: IndexerWeb.Worker.start_link(arg)
      # {IndexerWeb.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: IndexerWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
