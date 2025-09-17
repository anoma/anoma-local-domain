defmodule Anoma.LocalDomain.Examples.EPoller do
  # import ExUnit.Assertions

  def decrypt_payload() do
    secret_key_encoded =
      "MTE4MTI0NjRjNmUzM2UyNzljZmM4MmM4NDQ5OWJjODUwZDZlZGZmM2NjYTlmNDc3MDg2NTc5YjZkOTFjZjFmZA=="

    public_key_encoded =
      "MDJiZDE3NmI1OTEzNjc5NzU1NTFmYWIzZmM1ZTgwMGJmYWRlNjg0YzAwMDUzMjZiZTgzMzg2OTFmMTEyODU2YmU4"

    discovery_payload_encoded =
      "11000000000000009c4e37edfb9aaf05fe59f44361ee36ccfbd2740bf8d4a2f626b1696974210000000000000002a358a0fd4aae7cb85ed1dd92e0c3ab73d9ca705edca6bb52e6cc65bcdb369cc10000"

    {:ok, discovery_payload} = Base.decode64(discovery_payload_encoded)
    discovery_payload = :binary.bin_to_list(discovery_payload)

    keypair =
      Anoma.Arm.Keypair.from_map(%{
        secret_key: secret_key_encoded,
        public_key: public_key_encoded
      })

    require IEx
    IEx.pry()

    Anoma.Arm.decrypt_cipher(discovery_payload, keypair)
  end
end
