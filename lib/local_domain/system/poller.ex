defmodule Anoma.LocalDomain.System.Poller do
  @moduledoc """
  I poll for events from a graphQL endpoint for a protocol adapter contract indexer.
  """

  use GenStateMachine
  use Anoma.LocalDomain

  def start do
    args = [
      cipher_keys: [%{private_key: "s", public_key: "p"}],
      endpoint: "http://localhost:8080/v1/graphql"
    ]

    spec =
      Supervisor.child_spec({Anoma.LocalDomain.System.Poller, args},
        restart: :temporary
      )

    DynamicSupervisor.start_child(AppTasksSupervisor, spec)
  end

  def stop(pid) do
    DynamicSupervisor.terminate_child(AppTasksSupervisor, pid)
  end

  def add_cipher_key(cipher_key) do
    GenStateMachine.cast(__MODULE__, {:add_key, cipher_key})
  end

  def transactionExecutedQuery() do
    """
    query($min: Int!) {
    ProtocolAdapter_TransactionExecuted(order_by: {blockNumber: desc}, where: {blockNumber:   {_gt: $min}}) {
    id
    tags
    blockNumber
    }
    }
    """
  end

  def payloadQuery() do
    """
    query($tags: [String!]!) {
    ProtocolAdapter_DiscoveryPayload(where: {tag: {_in: $tags}}) {
    id
    blob
    tag
    }
    ProtocolAdapter_ResourcePayload(where: {tag: {_in: $tags}}) {
    id
    blob
    tag
    }
    }
    """
  end

  def write_transaction_resource(tag, discovery, resource) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/resource/!tag",
      {:discovery, discovery, :resource, resource}
    )
  end

  def read_transaction_resource(tag) do
    Anoma.LocalDomain.Storage.read_latest(~k"/resource/!tag")
  end

  def read_blockheight() do
    Anoma.LocalDomain.Storage.read_latest(~k"/poller/blockheight")
  end

  def write_blockheight(height) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/poller/blockheight",
      height
    )
  end

  def can_decrypt(_cipher_key, resource) do
    {:ok, _resource} = Anoma.LocalDomain.Storage.read_latest(resource)
    true
  end

  def start_link(opts),
    do: GenStateMachine.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    cipher_keys = opts[:cipher_keys]
    endpoint = opts[:endpoint]

    data = %{
      cipher_keys: cipher_keys,
      endpoint: endpoint,
      blockheight:
        case read_blockheight() do
          {:ok, blockheight} -> blockheight
          :absent -> 0
        end
    }

    {:ok, :polling, data, {:state_timeout, 0, :tick}}
  end

  @impl true
  def handle_event(
        :state_timeout,
        :tick,
        _state,
        %{
          cipher_keys: _cipher_keys,
          endpoint: endpoint,
          blockheight: current_blockheight
        } = data
      ) do
    IO.puts("POLLING")
    IO.puts("Current Blockheight #{current_blockheight}")
    # IO.puts(cipher_keys)

    {next_blockheight, tags} =
      case Req.post(endpoint,
             json: %{
               query: transactionExecutedQuery(),
               variables: %{"min" => current_blockheight}
             }
           ) do
        {:ok, %{status: 200, body: body}} ->
          transactions =
            body["data"]["ProtocolAdapter_TransactionExecuted"]

          if length(transactions) > 0 do
            IO.puts("New blocks found")

            {Enum.at(transactions, 0)["blockNumber"],
             transactions
             |> Enum.map(fn t -> t["tags"] end)
             |> Enum.concat()}
          else
            IO.puts("No new blocks")
            {current_blockheight, []}
          end

        _other ->
          IO.puts("TransactionExecuted query failed")
      end

    case Req.post(endpoint,
           json: %{query: payloadQuery(), variables: %{"tags" => tags}}
         ) do
      {:ok, %{status: 200, body: body}} ->
        discovery_payloads =
          body["data"]["ProtocolAdapter_DiscoveryPayload"]

        resource_payloads =
          body["data"]["ProtocolAdapter_ResourcePayload"]

        for discovery_payload <- discovery_payloads,
            resource_payload <-
              Enum.filter(resource_payloads, fn p ->
                p["tag"] == discovery_payload["tag"]
              end) do
          IO.puts(
            "Found discovery payload for #{discovery_payload["tag"]}"
          )

          write_transaction_resource(
            discovery_payload["tag"],
            discovery_payload,
            resource_payload
          )

          # Attempt decryption + store per cipher key
        end

      _other ->
        IO.puts("Payload query failed")
    end

    {:keep_state, %{data | blockheight: next_blockheight},
     {:state_timeout, 12_000, :tick}}
  end

  @impl true
  def handle_event(
        :cast,
        {:add_key, key},
        :polling,
        %{cipher_keys: cipher_keys} = data
      ) do
    IO.puts("Adding cipher key...")

    {:next_state, :paused, %{data | cipher_keys: cipher_keys ++ [key]},
     {:next_event, :internal, {:reindex, key}}}
  end

  @impl true
  def handle_event(:internal, {:reindex, key}, :paused, data) do
    {:ok, resources} = Anoma.LocalDomain.Storage.ls(["resource"])

    Enum.filter(resources, fn resource -> can_decrypt(key, resource) end)
    |> Enum.map(fn _ -> IO.puts("OK") end)

    {:next_state, :polling, data, {:state_timeout, 0, :tick}}
  end
end
