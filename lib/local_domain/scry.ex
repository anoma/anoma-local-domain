defmodule Anoma.LocalDomain.Scry do
  @moduledoc """
  Scrying via Elixir.

  Keyspaces:
    - /anoma/local/[unique id]/[time]/key: local storage
    - /anoma/controller/[node id]/[time]/key: Perform read-only tx on
      controller and cache
  """

  use Anoma.LocalDomain
  alias Anoma.LocalDomain.Scry.HandlerRegistry
  alias Anoma.LocalDomain.Storage

  @spec scry(String.t(), []) :: :absent
  def scry(_node_id, ~k"") do
    :absent
  end

  @spec scry(String.t(), list()) ::
          {:ok, term()} | :absent | {:error, term()}
  def scry(node_id, path) when is_list(path) do
    scry_inner(node_id, [], path)
  end

  def scry_inner(node_id, prev_prefixes, key) do
    with {matched_prefix, handler} <-
           HandlerRegistry.match(node_id, prev_prefixes, key) do
      prev_prefixes = prev_prefixes ++ [matched_prefix]
      key = Enum.drop(key, Enum.count(matched_prefix))
      handler.(node_id, prev_prefixes, key)
    else
      _ -> {:error, :no_handler}
    end
  end

  def scry_local(node_id, prev_prefixes = [~k"/anoma/local"], key) do
    # todo: local ids, time
    [_local_id, _time | subkey] = key
    # use the subkey's handler, if any
    with {:ok, result} <- scry_inner(node_id, prev_prefixes, subkey) do
      {:ok, result}
    else
      :absent ->
        :absent

      {:error, :no_handler} ->
        Storage.read_local(node_id, subkey)

      {:error, e} ->
        {:error, e}
    end
  end

  def scry_controller(_node_id, _prev_prefixes, key) do
    # todo: get controller id, submit ro tx
    {:error, key}
  end
end
