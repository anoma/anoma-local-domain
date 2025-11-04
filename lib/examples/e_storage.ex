defmodule Examples.EStorage do
  use Anoma.LocalDomain
  alias Examples.ENode
  alias Anoma.LocalDomain.Storage

  import ExUnit.Assertions

  @spec storage_read_write() :: String.t()
  def storage_read_write() do
    Anoma.LocalDomain.Storage.start_link(%{node_id: "a"})
    Anoma.LocalDomain.Storage.write_local("a", ~k"/a", 1)
    assert {:ok, 1} = Anoma.LocalDomain.Storage.read_local("a", ~k"a")
  end

  @spec read_and_write_to_node() :: String.t()
  def read_and_write_to_node() do
    {:ok, node_id, pid} = ENode.start_node()
    Storage.write_local(node_id, ~k"/k1/k2", "val")

    {:ok, val} =
      Storage.read_local(node_id, ~k"/k1/k2")

    ENode.stop_node(pid)
    assert val == "val"
    val
  end

  @spec storage_persistence() :: String.t()
  def storage_persistence() do
    node_id = :crypto.strong_rand_bytes(32)
    {:ok, pid} = Anoma.LocalDomain.OTPApplication.start_node(node_id)
    Anoma.LocalDomain.Storage.write_local(node_id, ~k"/a", 1)
    Anoma.LocalDomain.OTPApplication.stop_node(pid)

    {:ok, pid} = Anoma.LocalDomain.OTPApplication.start_node(node_id)
    {:ok, 1} = Anoma.LocalDomain.Storage.read_local(node_id, ~k"/a")
    Anoma.LocalDomain.OTPApplication.stop_node(pid)
  end
end
