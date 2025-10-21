defmodule Anoma.LocalDomain.MerkleTree do
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

    %Anoma.LocalDomain.MerkleTree{empty_nodes: empty_nodes}
  end

  def depth(tree) do
    tree.capacity |> :math.log2() |> trunc()
  end

  def root(tree) do
    Map.get(Map.get(tree.nodes, depth(tree)), 0)
  end

  def add(tree, values) do
    Enum.reduce(
      values,
      tree,
      fn leaf, acc_tree ->
        add_leaf(acc_tree, leaf)
      end
    )
  end

  def generate_proof(tree, leaf) do
    leaves = Map.get(tree.nodes, 0)

    # Get the index of the leaf
    found_elem =
      leaves
      |> Map.to_list()
      |> Enum.find(fn
        {_, ^leaf} ->
          true

        _ ->
          false
      end)

    if found_elem do
      {path, root, _index} =
        for i <- 0..(depth(tree) - 1),
            reduce: {[], leaf, elem(found_elem, 0)} do
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
  end

  def verify_proof(leaf, path, root) do
    calculated_root =
      Enum.reduce(path, leaf, fn {neighbour, is_left}, acc ->
        if is_left do
          hash(acc <> neighbour)
        else
          hash(neighbour <> acc)
        end
      end)

    calculated_root == root
  end

  defp add_leaf(tree, leaf) do
    index = tree.next_index
    depth = depth(tree)

    # Add a leaf and recompute needed intermediary nodes
    new_nodes =
      compute_nodes(depth, tree.nodes, tree.empty_nodes, index, leaf)

    if index + 1 == tree.capacity do
      # If the tree is fully filled, we need to recompute a new
      # root as if by adding an extra empty leaf at next index
      expanded_nodes =
        compute_nodes(
          depth + 1,
          new_nodes,
          tree.empty_nodes,
          index + 1,
          empty()
        )

      %MerkleTree{
        tree
        | nodes: expanded_nodes,
          next_index: index + 1,
          capacity: tree.capacity * 2
      }
    else
      %MerkleTree{tree | nodes: new_nodes, next_index: index + 1}
    end
  end

  defp compute_nodes(depth, nodes, empty_nodes, index, leaf) do
    # Iterate over each level of the tree, updating
    # only the parent nodes of the leaf
    {new_nodes, _, _} =
      for i <- 0..depth, reduce: {nodes, index, leaf} do
        {acc_nodes, index, node} ->
          # Fetch the current level of the tree
          current_nodes = Map.get(acc_nodes, i, %{})

          # Put the updated node at the given index
          updated_nodes =
            Map.put(acc_nodes, i, Map.put(current_nodes, index, node))

          is_left = (index &&& 1) == 0

          if is_left do
            # If the node is a left one, fetch its right sibling
            sibling =
              Map.get(current_nodes, index + 1, Map.get(empty_nodes, i))

            # Hash the node on the left and sibling on the right
            # The index of its parents is going to be index / 2
            {updated_nodes, div(index, 2), hash(node <> sibling)}
          else
            # If the node is a right one, fetch its left sibling
            sibling = Map.get(current_nodes, index - 1)
            # Hash the node on the left and sibling on the right
            # The index of its parents is going to be (index - 1) / 2
            {updated_nodes, div(index - 1, 2), hash(sibling <> node)}
          end
      end

    new_nodes
  end
end
