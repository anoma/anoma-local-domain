defmodule Anoma.LocalDomain.Storage do
  @moduledoc """
  Local storage subsystem. Timestamped, but not in an integrity-requiring way
  very much.

  Writes to all subspaces, but the main API writes to /anoma/local/[local id]/.
  """

  use Anoma.LocalDomain
  use GenServer
  use TypedStruct

  typedstruct enforce: true do
    field(:table, reference())
    field(:node_id, String.t())
    # last written time
    field(:time, non_neg_integer(), default: 0)
  end

  def start_link(args) do
    name = Anoma.LocalDomain.Registry.via(args[:node_id], __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Writes to /anoma/local/[local id]/ at the current time.
  """
  def write_local(node_id, key, value) when is_list(key) do
    name = Anoma.LocalDomain.Registry.via(node_id, __MODULE__)
    GenServer.cast(name, {:write, key, value})
  end

  @doc """
  Writes to any possible key, including timestamp. For populating controller
  value cache. Does not update local time (it's intended for non-local values).
  """
  def write_any(node_id, full_key, value) when is_list(full_key) do
    name = Anoma.LocalDomain.Registry.via(node_id, __MODULE__)
    GenServer.cast(name, {:write_any, full_key, value})
  end

  @doc """
  Deletes a value under /anoma/local/[local id]/ at the current time (it will
  give :absent if read).
  """
  def delete_local(node_id, key) when is_list(key) do
    name = Anoma.LocalDomain.Registry.via(node_id, __MODULE__)
    GenServer.cast(name, {:delete, key})
  end

  @doc """
  Deletes at any possible key.
  """
  def delete_any(full_key) when is_list(full_key) do
    {:ok, node_id} = Anoma.LocalDomain.Registry.local_node_id()
    name = Anoma.LocalDomain.Registry.via(node_id, __MODULE__)
    GenServer.cast(name, {:delete_any, full_key})
  end

  @doc """
  Reads from any possible key.
  """
  def read(node_id, full_key) when is_list(full_key) do
    name = Anoma.LocalDomain.Registry.via(node_id, __MODULE__)
    GenServer.call(name, {:read, full_key})
  end

  @doc """
  Reads from /anoma/local/[local id]/ at the current time.
  """
  def read_local(node_id, key) when is_list(key) do
    name = Anoma.LocalDomain.Registry.via(node_id, __MODULE__)
    GenServer.call(name, {:read_local, key})
  end

  @doc """
  Reads from any possible key, blocking if neither a value nor :absent.
  """
  def read_and_block(node_id, full_key) when is_list(full_key) do
    name = Anoma.LocalDomain.Registry.via(node_id, __MODULE__)
    GenServer.call(name, {:read_and_block, full_key}, :infinity)
  end

  # callbacks

  @impl true
  def init(args) do
    # Application.put_env(:mnesia, :schema_location, :ram)

    # IO.puts("OK")
    # IO.puts(Anoma.LocalDomain.Registry.local_node_id())
    # with :ok <- :mnesia.start() do
    #   IO.puts("STARTED MNESIA")
    # else
    #   {:error, :failed_to_create_schema, _error} ->
    #     {:error, :failed_to_create_schema}
    # end

    # todo: set this up with a real backend
    table = :ets.new(__MODULE__, [])
    {:ok, struct(__MODULE__, Enum.into(args, %{table: table}))}
  end

  @impl true
  def handle_call({:read, full_key}, _from, state) do
    with [{^full_key, value}] <- :ets.lookup(state.table, full_key) do
      {:reply, {:ok, value}, state}
    else
      [] -> {:reply, :absent, state}
      e -> {:reply, {:error, e}, state}
    end
  end

  @impl true
  def handle_call({:read_local, key}, _from, state) do
    # prefix the key
    local_id = state.node_id
    time_string = Integer.to_string(state.time)
    key = ~k"/anoma/local/!local_id/!time_string" ++ key

    with [{^key, value}] <- :ets.lookup(state.table, key) do
      {:reply, {:ok, value}, state}
    else
      [] -> {:reply, :absent, state}
      e -> {:reply, {:error, e}, state}
    end
  end

  @impl true
  def handle_call({:read_and_block, _full_key}, _from, state) do
    # hangs caller forever until implemented. this is still semantically correct
    {:noreply, state}
  end

  @impl true
  def handle_cast({:write, key, value}, state) do
    # prefix the key
    local_id = state.node_id
    time_string = Integer.to_string(state.time + 1)
    key = ~k"/anoma/local/!local_id/!time_string" ++ key

    :ets.insert(state.table, {key, value})

    {:noreply, %{state | time: state.time + 1}}
  end

  @impl true
  def handle_cast({:delete, key}, state) do
    # prefix the key
    local_id = state.node_id
    time_string = Integer.to_string(state.time + 1)
    key = ~k"/anoma/local/!local_id/!time_string" ++ key

    :ets.delete(state.table, key)

    {:noreply, %{state | time: state.time + 1}}
  end

  @impl true
  def handle_cast({:write_any, full_key, value}, state) do
    :ets.insert(state.table, {full_key, value})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_any, full_key}, state) do
    :ets.delete(state.table, full_key)
    {:noreply, state}
  end
end
