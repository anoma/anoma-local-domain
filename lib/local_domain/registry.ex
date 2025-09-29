defmodule Anoma.LocalDomain.Registry do
  @moduledoc """
  I am the Local Domain Node Registry module.

  I provide functionality for registering processes.
  """

  use TypedStruct

  typedstruct enforce: true, module: Address do
    @typedoc """
    I represent the Anoma Address.

    ### Fields
    - `:node_id` - The node id.
    - `:engine`  - The process name.
    """
    field(:node_id, String.t())
    field(:engine, atom())
  end

  def address(node_id, engine) do
    %Address{node_id: node_id, engine: engine}
  end

  def via(node_id, engine) do
    {:via, Registry, {__MODULE__, address(node_id, engine)}}
  end

  def dump_register() do
    Registry.select(__MODULE__, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Enum.sort()
  end

  def local_node_id() do
    pattern = {%{node_id: :"$1"}, :"$2", :"$3"}

    # shape: the shape of the results the registry should return
    shape = [:"$1"]

    Registry.select(__MODULE__, [{pattern, [], shape}])
    |> Enum.uniq()
    |> case do
      [] ->
        {:error, :no_node_running}

      [node_id] ->
        {:ok, node_id}

      [_, _ | _] ->
        {:error, :multiple_nodes}
    end
  end
end
