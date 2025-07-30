defmodule Anoma.LocalDomain.SampleApplication do
  @moduledoc """
  I am a sample local domain application: a fake wallet.

  I can have fake "private keys" stored in my storage, and can be scried for
  either the "private key" or the "public key".
  """

  use Anoma.LocalDomain.Application, name: "sample"
  use Anoma.LocalDomain.DefScry

  # Public API

  @spec store(String.t(), String.t()) :: any()
  def store(name, key) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/sample/privkey/!name",
      key
    )
  end

  def privkey(name) do
    Anoma.LocalDomain.Scry.scry(
      ~k"/anoma/local/foo/bar/sample/privkey/!name"
    )
  end

  def pubkey(name) do
    Anoma.LocalDomain.Scry.scry(
      ~k"/anoma/local/foo/bar/sample/pubkey/!name"
    )
  end

  # Callbacks

  defscry do
    _prev_prefixes, ~k"pubkey/!name" ->
      with {:ok, privkey} <-
             Anoma.LocalDomain.Scry.scry(
               ~k"/anoma/local/foo/bar/sample/privkey/!name"
             ) do
        {:ok, "PUBLIC_" <> privkey}
      end
  end
end
