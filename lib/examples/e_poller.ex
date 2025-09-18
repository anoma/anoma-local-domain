defmodule Anoma.LocalDomain.Examples.EPoller do
  def decrypt_payload_from_counter_example(
        secret_key_hex,
        public_key_hex,
        discovery_payload_hex
      ) do
    {:ok, secret_key_bytes} =
      Base.decode16(secret_key_hex, case: :lower)

    {:ok, public_key_bytes} =
      Base.decode16(public_key_hex, case: :lower)

    # The prefix format is [33, 0, 0, 0, 0, 0, 0, 0] where 33 is the compressed public key length
    public_key_with_prefix =
      <<33, 0, 0, 0, 0, 0, 0, 0>> <> public_key_bytes

    {:ok, payload_bytes} =
      Base.decode16(discovery_payload_hex, case: :lower)

    payload_list = :binary.bin_to_list(payload_bytes)

    keypair =
      Anoma.Arm.Keypair.from_map(%{
        secret_key: Base.encode64(secret_key_bytes),
        public_key: Base.encode64(public_key_with_prefix)
      })

    case Anoma.Arm.decrypt_cipher(payload_list, keypair) do
      {:ok, decrypted} -> {:ok, decrypted}
      decrypted when is_list(decrypted) -> {:ok, decrypted}
      nil -> {:error, :decryption_failed}
      other -> {:error, {:unexpected_result, other}}
    end
  end

  def decrypt_latest_payload() do
    secret_key_hex =
      "e458b7d0ea3333c9ffbc4a1b50ac5b786fa0fdf91789898c25ccdc3dff1c48e6"

    public_key_hex =
      "0385ef12ce29127dbf15a84e23cd9a1e9761a7704351641015f63996b2fcafe95d"

    discovery_payload_hex =
      "110000000000000000866b72791189682aaac5b81e387fdb0bae5b2a457aedc7c87af3334a210000000000000003b2fc87e9b9067e74db1f9e4f92bef38765977cbfe163a49725fad06ed178d21e0000"

    case decrypt_payload_from_counter_example(
           secret_key_hex,
           public_key_hex,
           discovery_payload_hex
         ) do
      {:ok, [0]} ->
        IO.puts(
          "Success! Decrypted discovery payload: [0] (null byte as expected)"
        )

        {:ok, [0]}

      {:ok, decrypted} ->
        IO.puts(
          "Success! Decrypted discovery payload: #{inspect(decrypted)}"
        )

        {:ok, decrypted}

      {:error, reason} ->
        IO.puts("Decryption failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
