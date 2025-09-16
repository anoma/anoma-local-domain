defmodule Anoma.LocalDomain.Examples.EStorage do
  use Anoma.LocalDomain
  alias Anoma.LocalDomain.Examples.ENode
  alias Anoma.LocalDomain.Storage

  import ExUnit.Assertions

  @spec read_and_write_to_node() :: String.t()
  def read_and_write_to_node() do
    {:ok, node_id, pid} = ENode.start_node()
    Storage.write_local(node_id, ~k"/k1/k2", "val")

    {:ok, val} =
      Storage.read(node_id, ~k"/anoma/local/!node_id/3/k1/k2")

    ENode.stop_node(pid)
    assert val == "val"
    val
  end
end
