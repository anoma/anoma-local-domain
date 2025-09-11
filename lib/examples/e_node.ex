defmodule Anoma.LocalDomain.Examples.ENode do
  require ExUnit.Assertions
  import ExUnit.Assertions

  @spec start_node() :: pid() | {:error, :failed_to_start_node}
  def start_node() do
    assert {:ok, pid} = Anoma.LocalDomain.OTPApplication.start_node()

    pid
  end

  @spec stop_node(pid()) :: :ok
  def stop_node(pid) do
    Supervisor.stop(pid)
    :ok
  end

  @spec extra_node_fails() :: :ok | {:error, :failed_to_start_node}
  def extra_node_fails() do
    assert {:ok, pid1} =
             Anoma.LocalDomain.OTPApplication.start_node("id1")

    assert {:error, {:already_started, pid2}} =
             Anoma.LocalDomain.OTPApplication.start_node("id1")

    assert pid1 == pid2
    :ok
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
