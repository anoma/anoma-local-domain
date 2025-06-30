defmodule Anoma.LocalDomain.SampleApplication do
  @moduledoc """
  I am a sample local domain application: a fake wallet.

  I can have fake "private keys" stored in my storage, and can be scried for
  either the "private key" or the "public key".
  """

  use Anoma.LocalDomain.Application, name: "sample"
end
