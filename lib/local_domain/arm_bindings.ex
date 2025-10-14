defmodule Anoma.LocalDomain.ArmBindings do
  @moduledoc """
  I define a few functions to test the ARM repo NIF interface.
  """

  use Rustler,
      otp_app: :anoma_local_domain,
      crate: :arm_bindings

  alias Anoma.LocalDomain.Keypair


  @doc """
  Generates a random private key (Scalar) and its corresponding public key (ProjectivePoint)
  """
  @spec random_key_pair :: Keypair.t()
  def random_key_pair, do: :erlang.nif_error(:nif_not_loaded)
  def test_key_pair(_), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Decrypt a ciphertext using a private key and public key.
  """
  @spec decrypt_cipher([byte()], Keypair.t()) :: [byte()]
  def decrypt_cipher(_, _), do: :erlang.nif_error(:nif_not_loaded)

end
