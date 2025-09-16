defmodule Anoma.LocalDomain.SampleApplication do
  @moduledoc """
  I am a sample local domain application: a fake wallet.

  I can have fake "private keys" stored in my storage, and can be scried for
  either the "private key" or the "public key".
  """

  use Anoma.LocalDomain.Application, name: "sample"
  use Anoma.LocalDomain.DefScry

  # Public API

  @spec store(String.t(), String.t(), String.t()) :: any()
  def store(node_id, name, key) do
    Anoma.LocalDomain.Storage.write_local(
      node_id,
      ~k"/sample/privkey/!name",
      key
    )
  end

  def privkey(node_id, name) do
    Anoma.LocalDomain.Scry.scry(
      node_id,
      ~k"/anoma/local/!node_id/bar/sample/privkey/!name"
    )
  end

  def pubkey(node_id, name) do
    Anoma.LocalDomain.Scry.scry(
      node_id,
      ~k"/anoma/local/!node_id/bar/sample/pubkey/!name"
    )
  end

  # Callbacks

  defscry do
    node_id, _prev_prefixes, ~k"!node_id/pubkey/!name" ->
      with {:ok, privkey} <-
             Anoma.LocalDomain.Scry.scry(
               node_id,
               ~k"/anoma/local/!node_id/bar/sample/privkey/!name"
             ) do
        {:ok, "PUBLIC_" <> privkey}
      end
  end
end
