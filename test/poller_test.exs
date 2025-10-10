defmodule PollerTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.System.Poller

  test "Run the examples" do
    Examples.EPoller.decrypt_payload()
    Examples.EPoller.cipher_keypair_storage_retrieval()
  end
end
