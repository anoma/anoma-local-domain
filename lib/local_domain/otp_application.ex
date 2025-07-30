defmodule Anoma.LocalDomain.OTPApplication do
  @moduledoc """
  I am the OTP application callback module for the local domain.

  Named `OTPApplication` rather than `Application` because of the unfortunate
  name collision with local domain applications.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Anoma.LocalDomain.Scry.HandlerRegistry,
      Anoma.LocalDomain.Storage,
      %{
        id: Anoma.LocalDomain.ApplicationStartup,
        restart: :transient,
        start:
          {Anoma.LocalDomain.ApplicationStartup, :start_applications,
           []}
      }
    ]

    opts = [strategy: :one_for_one, name: Anoma.LocalDomain.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
