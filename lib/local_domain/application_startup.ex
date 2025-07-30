defmodule Anoma.LocalDomain.ApplicationStartup do
  @moduledoc """
  I am a one-time startup task to start registered applications.
  """

  use Anoma.LocalDomain

  def start_applications() do
    application_modules =
      case Anoma.LocalDomain.Storage.read_local(~k"/clerk/applications") do
        {:ok, modules} ->
          modules

        :absent ->
          MapSet.new([Anoma.LocalDomain.System.Clerk])
      end

    for module <- application_modules do
      Anoma.LocalDomain.Application.register(module)
    end

    :ignore
  end
end
