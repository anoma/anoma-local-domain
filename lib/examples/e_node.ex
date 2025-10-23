defmodule Examples.ENode do
  @moduledoc """
  I provide the examples for LocalDomain nodes
  """
  
  require ExUnit.Assertions
  import ExUnit.Assertions

  use Anoma.LocalDomain
  use ExExample
  
  @spec start_node() ::
          {:ok, String.t(), pid()} | {:error, :failed_to_start_node}
  def start_node() do
    node_id = Base.encode16(:crypto.strong_rand_bytes(32))

    assert {:ok, pid} =
             Anoma.LocalDomain.OTPApplication.start_node(node_id)

    {:ok, node_id, pid}
  end

  @spec stop_node(pid()) :: :ok
  def stop_node(pid) do
    Supervisor.stop(pid)
    :ok
  end

  example extra_node_fails() do
    assert {:ok, pid1} = Anoma.LocalDomain.OTPApplication.start_node("id1")

    assert {:error, {:already_started, pid2}} = Anoma.LocalDomain.OTPApplication.start_node("id1")

    assert pid1 == pid2
    stop_node(pid1)
  end

  example start_two_different_nodes() do
    assert {:ok, pid1} = Anoma.LocalDomain.OTPApplication.start_node()
    assert {:ok, pid2} = Anoma.LocalDomain.OTPApplication.start_node()

    assert pid1 != pid2

    stop_node(pid1)
    stop_node(pid2)
  end
end
