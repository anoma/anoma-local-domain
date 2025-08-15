defmodule Anoma.LocalDomain.System.GraphQLPoller do
  @moduledoc """
  I define the GraphQLPoller application for the local domain.

  GraphQLPoller is an application that polls for events from a graphQL endpoint for a protocol adapter contract.
  """

  use Anoma.LocalDomain.Application, name: "graphQLPoller"
  use Anoma.LocalDomain.DefScry

  def write_cipherkey(name, key) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/poller/cipherkey/!name",
      key
    )
  end

  def set_endpoint(url) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/poller/graphql_endpoint",
      url
    )
  end

  def read_endpoint() do
    Anoma.LocalDomain.Storage.read_latest(~k"/poller/graphql_endpoint")
  end

  def read_blockheight() do
    Anoma.LocalDomain.Storage.read_latest(~k"/poller/blockheight")
  end

  def write_blockheight(height) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/poller/blockheight",
      height
    )
  end

  def write_cipher(tag, cipher, cipherkey) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/cipher/!tag",
      {:key, cipherkey, :cipher, cipher}
    )
  end

  def read_cipher_keys() do
    cipher_keys =
      case Anoma.LocalDomain.Storage.ls(~k"/poller/cipherkey") do
        :absent ->
          []

        {:ok, cipher_key_keys} ->
          cipher_key_keys
          |> MapSet.to_list()
          |> Enum.map(fn k ->
            with {:ok, v} <- Anoma.LocalDomain.Storage.read_latest(k) do
              v
            end
          end)
      end

    {:ok, cipher_keys}
  end

  def write_transaction_resource(tag, owner, resource) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/resource/!tag",
      {:owner, owner, :resource, resource}
    )
  end

  @impl true
  def init() do
    super()

    case read_blockheight() do
      {:ok, _} ->
        :ok

      :absent ->
        write_blockheight(0)
    end

    Supervisor.start_link([{__MODULE__.Poller, {}}],
      strategy: :one_for_one,
      name: __MODULE__.Supervisor
    )

    :ok
  end

  ## TODO Add scry paths for adding a cipher key (add to storage + dispatch to polling app) + retrieval of transaction resource from storage

  # defscry do
  #   _prev_prefixes, ~k"/" ->
  #     with {:ok, s} <-
  #     Anoma.LocalDomain.Scry.scry
  # end
end
