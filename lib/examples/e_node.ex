defmodule Examples.ENode do
  require ExUnit.Assertions
  import ExUnit.Assertions

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
    Anoma.LocalDomain.OTPApplication.stop_node(pid)
    :ok
  end

  @spec extra_node_fails() :: pid() | {:error, :failed_to_start_node}
  def extra_node_fails() do
    assert {:ok, pid1} =
             Anoma.LocalDomain.OTPApplication.start_node("id1")

    assert {:error, {:already_started, pid2}} =
             Anoma.LocalDomain.OTPApplication.start_node("id1")

    assert pid1 == pid2
    pid1
  end

  @spec start_two_different_nodes() ::
          {pid()} | {:error, :failed_to_start_node}
  def start_two_different_nodes() do
    assert {:ok, pid1} = Anoma.LocalDomain.OTPApplication.start_node()
    assert {:ok, pid2} = Anoma.LocalDomain.OTPApplication.start_node()

    assert pid1 != pid2

    {pid1, pid2}
  end
end
