defmodule Anoma.LocalDomain.System.GraphQLPoller.Poller do
  @moduledoc """
  """

  use GenServer
  use Anoma.LocalDomain

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    {:ok, cipher_keys} =
      Anoma.LocalDomain.System.GraphQLPoller.read_cipher_keys()

    {:ok, endpoint} =
      Anoma.LocalDomain.System.GraphQLPoller.read_endpoint()

    state = %{
      cipher_keys: cipher_keys,
      endpoint: endpoint
    }

    Process.send_after(self(), :tick, 0)

    {:ok, state}
  end

  def transactionExecutedQuery() do
    """
      query($min: Int!, $max: Int!) {
      raw_events(order_by: {block_number: desc}, where: {block_number: {_gt: $min, _lte: $max}}) {
      block_hash
      block_number
      block_fields
      event_name
      params
      }
      }
    """
  end

  def transactionExecutedFullQuery() do
    """
      query {
      raw_events {
      block_hash
      block_number
      block_fields
      event_name
      params
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

  @impl true
  def handle_info(
        :tick,
        %{cipher_keys: cipher_keys, endpoint: endpoint} = state
      ) do
    IO.puts("Polling now...")
    IO.puts(cipher_keys)
    IO.puts(endpoint)

    case Req.post(endpoint, json: %{query: blockHeightQuery()}) do
      {:ok, %{status: 200, body: body}} ->
        next_blockheight =
          Enum.at(body["data"]["raw_events"], 0)["block_number"]

        {:ok, current_blockheight} =
          Anoma.LocalDomain.System.GraphQLPoller.read_blockheight()

        case current_blockheight < next_blockheight do
          true ->
            case Req.post(endpoint,
                   json: %{
                     query: transactionExecutedQuery(),
                     variables: %{
                       "min" => current_blockheight,
                       "max" => next_blockheight
                     }
                   }
                 ) do
              {:ok, %{status: 200, body: body}} ->
                # IO.puts(body)

                for event <- body["data"]["raw_events"] do
                  if event["event_name"] == "TransactionExecuted" do
                    # TODO Attempt decode and store for each cipher key
                    Anoma.LocalDomain.System.GraphQLPoller.write_transaction_resource(
                      event["params"]["tag"],
                      event["params"]["discoveryPayload"],
                      event["params"]["resourcePayload"]
                    )
                  end
                end

                Anoma.LocalDomain.System.GraphQLPoller.write_blockheight(
                  next_blockheight
                )

              other ->
                IO.puts(other)
            end

          false ->
            IO.puts(current_blockheight)
        end

      other ->
        IO.puts(other)
    end

    # every 5s
    Process.send_after(self(), :tick, 5000)
    {:noreply, state}
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
        IO.puts("Hi")

        for event <- body["data"]["raw_events"] do
          if event["event_name"] == "TransactionExecuted" do
            # TODO Attempt decode and store for new cipher key only
            Anoma.LocalDomain.System.GraphQLPoller.write_transaction_resource(
              event["params"]["tag"],
              event["params"]["discoveryPayload"],
              event["params"]["resourcePayload"]
            )

            IO.puts(event["params"]["tag"])
          end
        end

      other ->
        IO.puts(other)
    end

    %{state | cipher_keys: cipher_keys ++ [new_cipher_key]}
  end
end
