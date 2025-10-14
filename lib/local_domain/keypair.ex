defmodule Anoma.LocalDomain.Keypair do
  @moduledoc """
  I define the datastructure `Keypair` that holds a public key and a private key.
  """
  use TypedStruct

  typedstruct do
    field(:secret_key, binary())
    field(:public_key, binary())
  end
end
