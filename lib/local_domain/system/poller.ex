defmodule Anoma.LocalDomain.System.Poller do
  @moduledoc """
  I poll for events from a graphQL endpoint for a protocol adapter contract indexer.
  """

  use GenServer
  use Anoma.LocalDomain

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    cipher_keys = opts[:cipher_keys]
    endpoint = opts[:endpoint]

    state = %{
      cipher_keys: cipher_keys,
      endpoint: endpoint,
      blockheight:
        case read_blockheight() do
          {:ok, blockheight} -> blockheight
          :absent -> 0
        end
    }

    Process.send_after(self(), :tick, 0)

    {:ok, state}
  end

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
    raw_events(limit: 1, order_by: {block_number: desc}) {
    block_number
    }
    }
    """
  end

  def write_transaction_resource(tag, owner, resource) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/resource/!tag",
      {:owner, owner, :resource, resource}
    )
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

  @impl true
  def handle_info(
        :tick,
        %{
          cipher_keys: cipher_keys,
          endpoint: endpoint,
          blockheight: current_blockheight
        } = state
      ) do
    IO.puts("Polling now...")
    IO.puts(cipher_keys)
    IO.puts(endpoint)

    next_blockheight =
      case Req.post(endpoint, json: %{query: blockHeightQuery()}) do
        {:ok, %{status: 200, body: body}} ->
          next_blockheight =
            Enum.at(body["data"]["raw_events"], 0)["block_number"]

          case current_blockheight < next_blockheight do
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
                        action["logicVerifierInputs"],
                      discoveryPayload <-
                        logicVerifierInput["appData"][
                          "discoveryPayload"
                        ] do
                    appData = logicVerifierInput["appData"]

                    IO.puts(logicVerifierInput["tag"])

                    # require IEx; IEx.pry;
                    # TODO Attempt decode and store for each cipher key
                    write_transaction_resource(
                      logicVerifierInput["tag"],
                      discoveryPayload["blob"],
                      appData["resourcePayload"]
                    )
                  end

                other ->
                  IO.puts(other)
              end

              write_blockheight(next_blockheight)
              next_blockheight

            false ->
              IO.puts("No New")
              current_blockheight
          end

        other ->
          IO.puts(other)
          current_blockheight
      end

    IO.puts(next_blockheight)

    # every 12s
    Process.send_after(self(), :tick, 12000)

    {:noreply, %{state | blockheight: next_blockheight}}
  end

  @impl true
  def handle_info(
        {:new_cipher_key, new_cipher_key},
        %{endpoint: endpoint, cipher_keys: cipher_keys} = state
      ) do
    IO.puts("Adding cipher key...")

    case Req.post(endpoint,
           json: %{query: transactionExecutedFullQuery()}
         ) do
      {:ok, %{status: 200, body: body}} ->
        for event <-
              body["data"]["ProtocolAdapter_TransactionExecuted"],
            action <- event["transaction"]["actions"],
            logicVerifierInput <- action["logicVerifierInputs"],
            discoveryPayload <-
              logicVerifierInput["appData"]["discoveryPayload"] do
          appData = logicVerifierInput["appData"]

          IO.puts(logicVerifierInput["tag"])

          # require IEx; IEx.pry;
          # TODO Attempt decode and store for each cipher key
          write_transaction_resource(
            logicVerifierInput["tag"],
            discoveryPayload["blob"],
            appData["resourcePayload"]
          )
        end

      other ->
        IO.puts(other)
    end

    %{state | cipher_keys: cipher_keys ++ [new_cipher_key]}
  end

  def start do
    DynamicSupervisor.start_child(
      AppTasksSupervisor,
      {Anoma.LocalDomain.System.Poller,
       [cipher_keys: [], endpoint: "http://localhost:8080/v1/graphql"]}
    )
  end
end
