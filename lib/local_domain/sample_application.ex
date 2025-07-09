defmodule Anoma.LocalDomain.SampleApplication do
  @moduledoc """
  I am a sample local domain application: a fake wallet.

  I can have fake "private keys" stored in my storage, and can be scried for
  either the "private key" or the "public key".
  """

  use Anoma.LocalDomain.Application, name: "sample"

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

  @impl true
  def scry(_, ~k"pubkey/!name") do
    with {:ok, privkey} <-
           Anoma.LocalDomain.Scry.scry(
             ~k"/anoma/local/foo/bar/sample/privkey/!name"
           ) do
      {:ok, "PUBLIC_" <> privkey}
    end
  end

  @impl true
  def scry(prev_prefixes, key) do
    super(prev_prefixes, key)
  end
end
