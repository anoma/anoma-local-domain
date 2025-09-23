defmodule Anoma.LocalDomain.System.Poller do
  @moduledoc """
  I poll for events from a graphQL endpoint for a protocol adapter contract indexer.
  """

  use GenStateMachine
  use Anoma.LocalDomain

  def start do
    args = [
      cipher_keypairs: [],
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

  def add_cipher_keypair(cipher_keypair) do
    GenStateMachine.cast(__MODULE__, {:add_keypair, cipher_keypair})
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
    Anoma.LocalDomain.Storage.write_local(~k"/resource/!tag", %{
      discovery: discovery,
      resource: resource
    })
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

  def write_keypair(%{secret_key: secret, public_key: public}) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/discovery_keypair/!public",
      secret
    )
  end

  def can_decrypt(
        %{secret_key: secret_key_hex, public_key: public_key_hex},
        discovery_payload_hex
      ) do
    with {:ok, secret_key_bytes} <-
           Base.decode16(secret_key_hex, case: :lower),
         {:ok, public_key_bytes} <-
           Base.decode16(public_key_hex, case: :lower),
         {:ok, payload_bytes} <-
           Base.decode16(discovery_payload_hex, case: :lower) do
      # The prefix format is [33, 0, 0, 0, 0, 0, 0, 0] where 33 is the compressed public key length
      public_key_with_prefix =
        <<33, 0, 0, 0, 0, 0, 0, 0>> <> public_key_bytes

      payload_list = :binary.bin_to_list(payload_bytes)

      keypair =
        AnomaSDK.Arm.Keypair.from_map(%{
          secret_key: Base.encode64(secret_key_bytes),
          public_key: Base.encode64(public_key_with_prefix)
        })

      case AnomaSDK.Arm.decrypt_cipher(payload_list, keypair) do
        {:ok, decrypted} -> {:ok, decrypted}
        decrypted when is_list(decrypted) -> {:ok, decrypted}
        nil -> {:error, "nil"}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, :bad_hex}
      other -> {:error, {:unexpected, other}}
    end
  end

  def start_link(opts),
    do: GenStateMachine.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    cipher_keypairs = opts[:cipher_keypairs]
    endpoint = opts[:endpoint]

    data = %{
      cipher_keypairs: cipher_keypairs,
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
          cipher_keypairs: cipher_keypairs,
          endpoint: endpoint,
          blockheight: current_blockheight
        } = data
      ) do
    IO.puts("POLLING")
    IO.puts("Current Blockheight #{current_blockheight}")
    IO.puts("Current Keypairs #{inspect(cipher_keypairs)}")

    ## TODO optimise the graphQL so we don't have to do two queries
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

        {:error, reason} ->
          IO.puts("Query failed #{inspect(reason)}")
          {current_blockheight, []}
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
          for keypair <- cipher_keypairs do
            "0x" <> blob = discovery_payload["blob"]

            case can_decrypt(keypair, blob) do
              {:ok, _} -> IO.puts("OK")
              {:error, reason} -> IO.puts("NOT OK #{inspect(reason)}")
            end
          end
        end

      reason ->
        IO.puts("Query failed #{inspect(reason)}")
    end

    write_blockheight(next_blockheight)

    {:keep_state, %{data | blockheight: next_blockheight},
     {:state_timeout, 12_000, :tick}}
  end

  @impl true
  def handle_event(
        :cast,
        {:add_keypair, keypair},
        :polling,
        %{cipher_keypairs: cipher_keypairs} = data
      ) do
    IO.puts("Adding cipher keypair #{inspect(keypair)}")

    :ok = write_keypair(keypair)

    {:next_state, :paused,
     %{data | cipher_keypairs: cipher_keypairs ++ [keypair]},
     {:next_event, :internal, {:reindex, keypair}}}
  end

  @impl true
  def handle_event(:internal, {:reindex, keypair}, :paused, data) do
    {:ok, resources} = Anoma.LocalDomain.Storage.ls(["resource"])

    for resource <- resources do
      {:ok, resource} = Anoma.LocalDomain.Storage.read_latest(resource)

      "0x" <> blob = resource[:discovery]["blob"]

      IO.puts("Blob #{blob}")

      case can_decrypt(keypair, blob) do
        {:ok, _} -> IO.puts("OK")
        {:error, reason} -> IO.puts("NOT OK #{inspect(reason)}")
      end
    end

    {:next_state, :polling, data, {:state_timeout, 0, :tick}}
  end
end
