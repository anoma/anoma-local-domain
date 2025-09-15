defmodule Anoma.LocalDomain.System.Poller do
  @moduledoc """
  I poll for events from a graphQL endpoint for a protocol adapter contract indexer.
  """

  use GenStateMachine
  use Anoma.LocalDomain

  def transactionExecutedQuery() do
    """
    query($min: numeric!) {
    ProtocolAdapter_TransactionExecuted(order_by: {blockNumber: desc}, where: {blockNumber:   {_gt: $min}}) {
      id
      transaction {
        id
        deltaProof
        actions {
          id
          logicVerifierInputs {
            appData {
              id
              discoveryPayload {
                id
                blob
              }
              resourcePayload {
                id
                blob
              }
            }
            tag
          }
        }
      }
      blockNumber
    }
    }
    """
  end

  def transactionExecutedFullQuery() do
    """
    query {
    ProtocolAdapter_TransactionExecuted(order_by: {blockNumber: desc}) {
      id
      transaction {
        id
        deltaProof
        actions {
          id
          logicVerifierInputs {
            appData {
              id
              discoveryPayload {
                id
                blob
              }
              resourcePayload {
                id
                blob
              }
            }
            tag
          }
        }
      }
      blockNumber
    }
    }
    """
  end

  def blockHeightQuery() do
    """
    query {
    ProtocolAdapter_TransactionExecuted(limit: 1, order_by: {blockNumber: desc}) {
    blockNumber
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
          cipher_keys: cipher_keys,
          endpoint: endpoint,
          blockheight: current_blockheight
        } = data
      ) do
    IO.puts("POLLING")
    IO.puts(cipher_keys)

    next_blockheight =
      case Req.post(endpoint, json: %{query: blockHeightQuery()}) do
        {:ok, %{status: 200, body: body}} ->
          next_blockheight =
            Enum.at(
              body["data"]["ProtocolAdapter_TransactionExecuted"],
              0
            )["blockNumber"]

          case current_blockheight < next_blockheight and
                 next_blockheight != nil do
            true ->
              case Req.post(endpoint,
                     json: %{
                       query: transactionExecutedQuery(),
                       variables: %{"min" => current_blockheight}
                     }
                   ) do
                {:ok, %{status: 200, body: body}} ->
                  for event <-
                        body["data"][
                          "ProtocolAdapter_TransactionExecuted"
                        ],
                      action <- event["transaction"]["actions"],
                      logicVerifierInput <-
                        action["logicVerifierInputs"] do
                    appData = logicVerifierInput["appData"]

                    write_transaction_resource(
                      logicVerifierInput["tag"],
                      appData["discoveryPayload"],
                      appData["resourcePayload"]
                    )

                    IO.puts(logicVerifierInput["tag"])

                    # for key <- cipher_keys do
                    #   IO.puts(key)

                    # TODO Attempt decode and store for each cipher key

                    #   write_transaction_resource(
                    #     logicVerifierInput["tag"],
                    #     discoveryPayload["blob"],
                    #     owner,
                    #     appData["resourcePayload"]
                    #   )
                    # end
                  end

                other ->
                  IO.puts("FAILED TO QUERY EVENTS")
              end

              write_blockheight(next_blockheight)
              next_blockheight

            false ->
              IO.puts("No New")
              current_blockheight
          end

        other ->
          IO.puts("FAILED BLOCKHEIGHT QUERY")
          current_blockheight
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

  def start do
    DynamicSupervisor.start_child(
      AppTasksSupervisor,
      {Anoma.LocalDomain.System.Poller,
       [
         cipher_keys: [
           "c5de8df2dff5964d9ff981282fea2b5e3bbee6801039f25a426b73d239f8694a"
         ],
         endpoint: "http://localhost:8080/v1/graphql"
       ]}
    )
  end

  def add_cipher_key(cipher_key) do
    GenStateMachine.cast(__MODULE__, {:add_key, cipher_key})
  end
end
