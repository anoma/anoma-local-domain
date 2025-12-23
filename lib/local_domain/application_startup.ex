defmodule Anoma.LocalDomain.ApplicationStartup do
  @moduledoc """
  I am a one-time startup task to start registered applications.
  """

  use Anoma.LocalDomain

  def start_applications(args) do
    application_modules =
      case Anoma.LocalDomain.Storage.read_local(
             args[:node_id],
             ~k"/clerk/applications"
           ) do
        {:ok, modules} ->
          modules

        :absent ->
          MapSet.new([Anoma.LocalDomain.System.Clerk])
      end

    for module <- application_modules do
      Anoma.LocalDomain.Application.register(module, args)
    end

    GtBridge.View.register(Anoma.LocalDomain.Views)
    :ignore
  end
end
