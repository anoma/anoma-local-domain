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
  def start(node_id, contract) do
    args = %{
      contract: contract,
      cipher_keypairs: [],
      endpoint: "http://localhost:8080/v1/graphql",
      node_id: node_id
    }

    spec =
      Supervisor.child_spec({__MODULE__, args},
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
  def add_cipher_keypair(node_id, cipher_keypair) do
    name = Anoma.LocalDomain.Registry.via(node_id, __MODULE__)
    GenStateMachine.cast(name, {:add_keypair, cipher_keypair})
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
  def write_transaction_resource(
        node_id,
        contract,
        tag,
        discovery,
        resource,
        is_consumed
      ) do
    Anoma.LocalDomain.Storage.write_local(
      node_id,
      ~k"/!contract/resource/!tag",
      %{
        discovery: discovery,
        resource: resource,
        is_consumed: is_consumed
      }
    )
  end

  @doc """
  Writes a transaction resource to storage, associated with a public key representing the keypair the discovery payload was decrypted with
  """
  def write_transaction_resource(
        node_id,
        contract,
        tag,
        public_key,
        discovery,
        resource,
        is_consumed
      ) do
    Anoma.LocalDomain.Storage.write_local(
      node_id,
      ~k"/!contract/resource/!public_key/!tag",
      %{
        discovery: discovery,
        resource: resource,
        is_consumed: is_consumed
      }
    )
  end

  @doc """
  Reads a transaction resource
  """
  def read_transaction_resource(node_id, contract, tag) do
    Anoma.LocalDomain.Storage.read_latest(
      node_id,
      ~k"/!contract/resource/!tag"
    )
  end

  @doc """
  Reads a transaction resource associated with a public key
  """
  def read_transaction_resource(node_id, contract, tag, public_key) do
    Anoma.LocalDomain.Storage.read_latest(
      node_id,
      ~k"/!contract/resource/!public_key/!tag"
    )
  end

  @doc """
  Reads current known blockheight
  """
  def read_blockheight(node_id, contract) do
    Anoma.LocalDomain.Storage.read_latest(
      node_id,
      ~k"/!contract/blockheight"
    )
  end

  @doc """
  Writes the current known blockheight
  """
  def write_blockheight(node_id, contract, height) do
    Anoma.LocalDomain.Storage.write_local(
      node_id,
      ~k"/!contract/blockheight",
      height
    )
  end

  @doc """
  Writes a cipher keypair to storage
  """
  def write_keypair(node_id, contract, %{
        secret_key: secret,
        public_key: public
      }) do
    Anoma.LocalDomain.Storage.write_local(
      node_id,
      ~k"/!contract/discovery_keypair/!public",
      secret
    )
  end

  def prepare_payload_and_keypair(
        payload_bytes,
        secret_key_bytes,
        public_key_bytes
      ) do
    public_key_with_prefix =
      <<33, 0, 0, 0, 0, 0, 0, 0>> <> public_key_bytes

    payload_list = :binary.bin_to_list(payload_bytes)

    keypair =
      AnomaSDK.Arm.Keypair.from_map(%{
        secret_key: Base.encode64(secret_key_bytes),
        public_key: Base.encode64(public_key_with_prefix)
      })

    {payload_list, keypair}
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
           Base.decode16(discovery_payload_hex, case: :mixed),
         {payload_list, keypair} <-
           prepare_payload_and_keypair(
             payload_bytes,
             secret_key_bytes,
             public_key_bytes
           ) do
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

  def start_link(opts) do
    name = Anoma.LocalDomain.Registry.via(opts[:node_id], __MODULE__)
    GenStateMachine.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    data =
      Map.put(
        opts,
        :blockheight,
        case read_blockheight(opts[:node_id], opts[:contract]) do
          {:ok, blockheight} -> blockheight
          :absent -> 0
        end
      )

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
          contract: contract,
          node_id: node_id
        } = data
      ) do
    Logger.info("POLLING #{endpoint}")
    Logger.debug("Current Blockheight #{current_blockheight}")
    Logger.debug("Current Keypairs #{inspect(cipher_keypairs)}")

    ## TODO optimise the graphQL so we don't have to do two queries
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

          next_blockheight = Enum.at(transactions, 0)["blockNumber"]

          tags =
            transactions
            |> Enum.map(fn txs -> txs["tags"] end)
            |> Enum.concat()

          write_blockheight(node_id, contract, next_blockheight)

          {:keep_state, %{data | blockheight: next_blockheight},
           {:next_event, :internal, {:process_tags, tags}}}
        else
          Logger.debug("No new blocks")
          {:keep_state, data, {:state_timeout, 12_000, :tick}}
        end

      {:error, reason} ->
        Logger.error("Query failed #{inspect(reason)}")
        {:keep_state, data, {:state_timeout, 12_000, :tick}}
    end
  end

  @impl true
  def handle_event(
        :internal,
        {:process_tags, tags},
        :polling,
        %{
          endpoint: endpoint,
          contract: contract,
          cipher_keypairs: cipher_keypairs,
          node_id: node_id
        } = data
      ) do
    tags_with_indices = tags |> Enum.with_index()

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

          {_, index} =
            Enum.find(tags_with_indices, fn {tag, _} ->
              tag == discovery_payload["tag"]
            end)

          is_consumed =
            case rem(index, 2) do
              0 -> true
              1 -> false
            end

          write_transaction_resource(
            node_id,
            contract,
            discovery_payload["tag"],
            discovery_payload,
            resource_payloads,
            is_consumed
          )

          # Attempt decryption + store per cipher key
          for keypair <- cipher_keypairs do
            "0x" <> blob = discovery_payload["blob"]

            case can_decrypt(keypair, blob) do
              :ok ->
                Logger.debug("CAN DECRYPT #{blob}")

                write_transaction_resource(
                  node_id,
                  contract,
                  discovery_payload["tag"],
                  keypair[:public_key],
                  discovery_payload,
                  resource_payloads,
                  is_consumed
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

    {:keep_state, data, {:state_timeout, 12_000, :tick}}
  end

  @impl true
  def handle_event(
        :cast,
        {:add_keypair, keypair},
        :polling,
        %{
          cipher_keypairs: cipher_keypairs,
          contract: contract,
          node_id: node_id
        } = data
      ) do
    Logger.debug("Adding cipher keypair #{inspect(keypair)}")

    :ok = write_keypair(node_id, contract, keypair)

    {:next_state, :paused,
     %{data | cipher_keypairs: cipher_keypairs ++ [keypair]},
     {:next_event, :internal, {:reindex, keypair}}}
  end

  @impl true
  def handle_event(
        :internal,
        {:reindex, keypair},
        :paused,
        %{contract: contract, node_id: node_id} = data
      ) do
    {:ok, resource_keys} =
      Anoma.LocalDomain.Storage.ls(node_id, ~k"/!contract/resource")

    for resource_key <- resource_keys do
      {:ok, resource} =
        Anoma.LocalDomain.Storage.read_latest(node_id, resource_key)

      "0x" <> blob = resource[:discovery]["blob"]

      Logger.debug("Blob #{blob}")

      case can_decrypt(keypair, blob) do
        :ok ->
          Logger.debug("CAN DECRYPT #{blob}")

          write_transaction_resource(
            node_id,
            contract,
            List.last(resource_key),
            keypair[:public_key],
            resource[:discovery],
            resource[:resource],
            resource[:is_consumed]
          )

        {:error, reason} ->
          Logger.debug("Failed to decrypt #{blob} #{inspect(reason)}")

        r ->
          IO.puts(r)
      end
    end

    {:next_state, :polling, data, {:state_timeout, 0, :tick}}
  end
end
