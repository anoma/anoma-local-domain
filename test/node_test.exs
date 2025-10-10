defmodule NodeTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.NodeSupervisor

  test "Run the examples" do
    {:ok, _node_id, pid} = Examples.ENode.start_node()
    Examples.ENode.stop_node(pid)
    pid = Examples.ENode.extra_node_fails()
    Examples.ENode.stop_node(pid)
    {:ok, pid1, pid2} = Examples.ENode.start_two_different_nodes()
    Examples.ENode.stop_node(pid1)
    Examples.ENode.stop_node(pid2)
  end
end
