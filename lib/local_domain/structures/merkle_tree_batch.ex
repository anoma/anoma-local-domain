defmodule Anoma.LocalDomain.MerkleTreeChunk do
  @moduledoc """
  I implement merkle tree behaviour for use within local domain applications.

  Has a variable depth.
  """

  import Bitwise
  use TypedStruct

  alias __MODULE__

  typedstruct enforce: true do
    # map from levels to the map from index to the node
    field(:nodes, %{integer() => %{integer() => binary()}},
      default: %{
        0 => %{0 => :crypto.hash(:sha256, "EMPTY")}
      }
    )

    field(:empty_nodes, %{integer() => binary()})
    field(:next_index, non_neg_integer(), default: 0)
    field(:capacity, non_neg_integer(), default: 1)
  end

  def hash(bytes) do
    :crypto.hash(:sha256, bytes)
  end

  def empty() do
    hash("EMPTY")
  end

  def new() do
    # Assume we have a tree at most of depth 32
    empty_nodes =
      for i <- 1..31, reduce: %{0 => :crypto.hash(:sha256, "EMPTY")} do
        acc ->
          previous_empty_hash = Map.get(acc, i - 1)

          Map.put(
            acc,
            i,
            :crypto.hash(
              :sha256,
              previous_empty_hash <> previous_empty_hash
            )
          )
      end

    %Anoma.LocalDomain.MerkleTreeChunk{empty_nodes: empty_nodes}
  end

  def depth(tree) do
    tree.capacity |> :math.log2() |> trunc()
  end

  def root(tree) do
    Map.get(Map.get(tree.nodes, depth(tree)), 0)
  end

  def add(tree, leaves) do
    index = tree.next_index
    new_commitment_length = index + length(leaves)

    {depth, capacity} =
      if new_commitment_length >= tree.capacity do
        # If the tree capacity is exceeded, calculate the new minimal depth
        new_depth =
          (new_commitment_length |> :math.log2() |> trunc()) + 1

        {new_depth, Integer.pow(2, new_depth)}
      else
        {depth(tree), tree.capacity}
      end

    # Add leaves and recompute needed intermediary nodes
    new_nodes =
      compute_nodes(depth, tree.nodes, tree.empty_nodes, index, leaves)

    %MerkleTreeChunk{
      tree
      | nodes: new_nodes,
        next_index: new_commitment_length,
        capacity: capacity
    }
  end

  def generate_proof(tree, leaf) do
    leaves = Map.get(tree.nodes, 0)

    # Get the index of the leaf
    {leaf_index, _} =
      leaves
      |> Map.to_list()
      |> Enum.find(fn
        {_, ^leaf} ->
          true

        _ ->
          false
      end)

    {path, root, _index} =
      for i <- 0..(depth(tree) - 1), reduce: {[], leaf, leaf_index} do
        {path, node, index} ->
          # Take the current level of the tree
          current_nodes = Map.get(tree.nodes, i)

          is_left = (index &&& 1) == 0

          if is_left do
            # If the node is a left one, take its right sibling
            sibling = Map.get(current_nodes, index + 1, empty())

            # Hash the node on the left and sibling on the right
            # The index of its parents is going to be index / 2
            {path ++ [{sibling, true}], hash(node <> sibling),
             div(index, 2)}
          else
            # If the node is a right one, take its left sibling
            sibling = Map.get(current_nodes, index - 1, empty())

            # Hash the node on the right and sibling on the left
            # The index of its parents is going to be (index - 1) / 2
            {path ++ [{sibling, false}], hash(sibling <> node),
             div(index - 1, 2)}
          end
      end

    if root == root(tree) do
      {path, root}
    else
      nil
    end
  end

  def verify_proof(leaf, frontiers, root) do
    calculated_root =
      Enum.reduce(frontiers, leaf, fn {neighbour, is_left}, acc ->
        if is_left do
          hash(acc <> neighbour)
        else
          hash(neighbour <> acc)
        end
      end)

    calculated_root == root
  end

  defp compute_nodes(depth, nodes, empty_nodes, index, leaves) do
    # Iterate over each level of the tree, updating
    # only the parent nodes of the given leaves
    {new_nodes, _, _} =
      for i <- 0..depth, reduce: {nodes, index, leaves} do
        {acc_nodes, index, nodes} ->
          # Fetch the current level of the tree
          current_nodes = Map.get(acc_nodes, i, %{})

          # Put the updated nodes as ordered by the list
          {updated_nodes, _} =
            Enum.reduce(nodes, {current_nodes, index}, fn node,
                                                          {acc, k} ->
              {Map.put(acc, k, node), k + 1}
            end)

          {full_nodes, new_index} =
            if is_left(index) do
              {nodes, index}
            else
              {[Map.get(current_nodes, index - 1) | nodes], index - 1}
            end

          # Calculate the parents of all the given nodes
          {parents, _, _} =
            for node <- full_nodes, reduce: {[], new_index, true} do
              {parents, j, is_left} ->
                if is_left do
                  # Get the right sibling
                  sibling =
                    Map.get(
                      updated_nodes,
                      j + 1,
                      Map.get(empty_nodes, i)
                    )

                  {[hash(node <> sibling) | parents], j + 1,
                   not is_left}
                else
                  {parents, j + 1, not is_left}
                end
            end

          {Map.put(acc_nodes, i, updated_nodes), div(index, 2),
           Enum.reverse(parents)}
      end

    new_nodes
  end

  defp is_left(index) do
    (index &&& 1) == 0
  end
end
