defmodule Anoma.LocalDomain.System.Poller do
  @moduledoc """
  I poll for events from a graphQL endpoint for a protocol adapter contract indexer.
  """

  use GenStateMachine
  use Anoma.LocalDomain
  require Logger

  @doc """
  Starts a poller for indexing a ProtocolAdapter contract
  """
  def start(contract) do
    args = [
      contract: contract,
      cipher_keypairs: [],
      endpoint: "http://localhost:8080/v1/graphql"
    ]

    spec =
      Supervisor.child_spec({Anoma.LocalDomain.System.Poller, args},
        restart: :temporary
      )

    DynamicSupervisor.start_child(AppTasksSupervisor, spec)
  end

  @doc """
  Stops the PA contract poller
  """
  def stop(pid) do
    DynamicSupervisor.terminate_child(AppTasksSupervisor, pid)
  end

  @doc """
  Adds a cipher keypair
  """
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

  @doc """
  Writes a transaction resource to storage
  """
  def write_transaction_resource(contract, tag, discovery, resource) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/!contract/resource/!tag",
      %{
        discovery: discovery,
        resource: resource
      }
    )
  end

  @doc """
  Writes a transaction resource to storage, associated with a public key representing the keypair the discovery payload was decrypted with
  """
  def write_transaction_resource(
        contract,
        tag,
        public_key,
        discovery,
        resource
      ) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/!contract/resource/!public_key/!tag",
      %{
        discovery: discovery,
        resource: resource
      }
    )
  end

  @doc """
  Reads a transaction resource
  """
  def read_transaction_resource(contract, tag) do
    Anoma.LocalDomain.Storage.read_latest(~k"/!contract/resource/!tag")
  end

  @doc """
  Reads a transaction resource associated with a public key
  """
  def read_transaction_resource(contract, tag, public_key) do
    Anoma.LocalDomain.Storage.read_latest(
      ~k"/!contract/resource/!public_key/!tag"
    )
  end

  @doc """
  Reads current known blockheight
  """
  def read_blockheight(contract) do
    Anoma.LocalDomain.Storage.read_latest(~k"/!contract/blockheight")
  end

  @doc """
  Writes the current known blockheight
  """
  def write_blockheight(contract, height) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/!contract/blockheight",
      height
    )
  end

  @doc """
  Writes a cipher keypair to storage
  """
  def write_keypair(contract, %{secret_key: secret, public_key: public}) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/!contract/discovery_keypair/!public",
      secret
    )
  end

  @doc """
  Attempts to discovery payload, given a keypair
  """
  def can_decrypt(
        %{secret_key: secret_key_hex, public_key: public_key_hex},
        discovery_payload_hex
      ) do
    with {:ok, secret_key_bytes} <-
           Base.decode16(secret_key_hex, case: :mixed),
         {:ok, public_key_bytes} <-
           Base.decode16(public_key_hex, case: :mixed),
         {:ok, payload_bytes} <-
           Base.decode16(discovery_payload_hex, case: :mixed) do
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
        {:ok, _} -> :ok
        decrypted when is_list(decrypted) -> :ok
        nil -> {:error, nil}
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
    data = %{
      opts
      | blockheight:
          case read_blockheight(opts[:contract]) do
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
          blockheight: current_blockheight,
          contract: contract
        } = data
      ) do
    Logger.info("POLLING #{endpoint}")
    Logger.debug("Current Blockheight #{current_blockheight}")
    Logger.debug("Current Keypairs #{inspect(cipher_keypairs)}")

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
            Logger.debug("New blocks found")

            {Enum.at(transactions, 0)["blockNumber"],
             transactions
             |> Enum.map(fn t -> t["tags"] end)
             |> Enum.concat()}
          else
            Logger.debug("No new blocks")
            {current_blockheight, []}
          end

        {:error, reason} ->
          Logger.error("Query failed #{inspect(reason)}")
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

        for discovery_payload <- discovery_payloads do
          resource_payloads =
            Enum.filter(resource_payloads, fn p ->
              p["tag"] == discovery_payload["tag"]
            end)

          Logger.debug(
            "Found discovery payload for #{discovery_payload["tag"]}"
          )

          write_transaction_resource(
            contract,
            discovery_payload["tag"],
            discovery_payload,
            resource_payloads
          )

          # Attempt decryption + store per cipher key
          for keypair <- cipher_keypairs do
            "0x" <> blob = discovery_payload["blob"]

            case can_decrypt(keypair, blob) do
              :ok ->
                Logger.debug("CAN DECRYPT #{blob}")

                write_transaction_resource(
                  contract,
                  discovery_payload["tag"],
                  keypair[:public_key],
                  discovery_payload,
                  resource_payloads
                )

              {:error, reason} ->
                Logger.debug(
                  "Failed to decrypt #{blob} #{inspect(reason)}"
                )
            end
          end
        end

      reason ->
        Logger.error("Query failed #{inspect(reason)}")
    end

    write_blockheight(contract, next_blockheight)

    {:keep_state, %{data | blockheight: next_blockheight},
     {:state_timeout, 12_000, :tick}}
  end

  @impl true
  def handle_event(
        :cast,
        {:add_keypair, keypair},
        :polling,
        %{cipher_keypairs: cipher_keypairs, contract: contract} = data
      ) do
    Logger.debug("Adding cipher keypair #{inspect(keypair)}")

    :ok = write_keypair(contract, keypair)

    {:next_state, :paused,
     %{data | cipher_keypairs: cipher_keypairs ++ [keypair]},
     {:next_event, :internal, {:reindex, keypair}}}
  end

  @impl true
  def handle_event(
        :internal,
        {:reindex, keypair},
        :paused,
        %{contract: contract} = data
      ) do
    {:ok, resource_tags} = Anoma.LocalDomain.Storage.ls(["resource"])

    for resource_tag <- resource_tags do
      {:ok, resource} =
        Anoma.LocalDomain.Storage.read_latest(resource_tag)

      "0x" <> blob = resource[:discovery]["blob"]

      Logger.debug("Blob #{blob}")

      case can_decrypt(keypair, blob) do
        :ok ->
          Logger.debug("CAN DECRYPT #{blob}")

          write_transaction_resource(
            contract,
            resource_tag,
            keypair[:public_key],
            resource[:discovery],
            resource[:resource]
          )

        {:error, reason} ->
          Logger.debug("Failed to decrypt #{blob} #{inspect(reason)}")
      end
    end

    {:next_state, :polling, data, {:state_timeout, 0, :tick}}
  end
end
