defmodule Anoma.LocalDomain.System.Clerk do
  @moduledoc """
  I define the Clerk application for the local domain.

  Clerk is the local domain application that stores user settings and
  preferences, including information on which other local domain applications
  are registered.
  """

  use Anoma.LocalDomain.Application, name: "clerk"

  def get_applications() do
    Anoma.LocalDomain.Storage.read_local(~k"/clerk/applications")
  end

  def register_application(module) do
    current = Anoma.LocalDomain.Storage.read_local(~k"/clerk/applications")
    Anoma.LocalDomain.Storage.write_local(~k"/clerk/applications",
      current |> MapSet.put(module))
  end

  @impl true
  def init() do
    super()

    # if there is no set of applications registered, initialize with just
    # this application.
    case Anoma.LocalDomain.Storage.read_local(~k"/clerk/applications") do
      {:ok, _} ->
        :ok

      :absent ->
        Anoma.LocalDomain.Storage.write_local(~k"/clerk/applications",
          MapSet.new([__MODULE__]))
        :ok
    end
  end
end
