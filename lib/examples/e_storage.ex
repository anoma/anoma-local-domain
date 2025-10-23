defmodule Examples.EStorage do
  @moduledoc """
  I contain examples that test Anoma.LocalDomain.Storage
  """
  
  use Anoma.LocalDomain
  use ExExample

  alias Examples.ENode
  alias Anoma.LocalDomain.Storage

  import ExUnit.Assertions

  example read_and_write_to_node() do
    {:ok, node_id, pid} = ENode.start_node()
    Storage.write_local(node_id, ~k"/k1/k2", "val")

    {:ok, val} =
      Storage.read_latest(node_id, ~k"/k1/k2")

    ENode.stop_node(pid)
    assert val == "val"
    val
  end
end
