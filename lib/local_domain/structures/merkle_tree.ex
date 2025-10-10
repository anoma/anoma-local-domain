defmodule Anoma.LocalDomain.MerkleTree do
  @moduledoc """
  I implement merkle tree behaviour for use within local domain applications.

  Has a variable depth.
  """

  import Bitwise
  use TypedStruct

  typedstruct enforce: true do
    field(:nodes, %{integer() => list(binary())},
      default: %{
        0 => [:crypto.hash(:sha256, "EMPTY")]
      }
    )
  end

  def hash(bytes) do
    :crypto.hash(:sha256, bytes)
  end

  def empty() do
    hash("EMPTY")
  end

  def new() do
    %Anoma.LocalDomain.MerkleTree{}
  end

  def depth(tree) do
    length(Map.keys(tree.nodes)) - 1
  end

  def root(tree) do
    Enum.at(Map.get(tree.nodes, depth(tree)), 0)
  end

  def generate_empty_branch(n) do
    Enum.map(1..n, fn _ -> empty() end)
  end

  def add_leaf(tree, leaf) do
    leaves = Map.get(tree.nodes, 0)

    leaf_index =
      leaves
      |> Enum.find_index(&(&1 == empty()))

    new_leaves = List.replace_at(leaves, leaf_index, leaf)

    if leaf_index + 1 == length(leaves) do
      new_leaves ++ generate_empty_branch(length(leaves))
    else
      new_leaves
    end
  end

  def calculate_nodes(leaves, i) do
    next_level =
      Enum.chunk_every(leaves, 2, 2, :discard)
      |> Enum.map(fn [a, b] -> hash(a <> b) end)

    if length(next_level) > 1 do
      Map.merge(%{i => next_level}, calculate_nodes(next_level, i + 1))
    else
      %{i => next_level}
    end
  end

  def add(tree, value) do
    new_leaves = add_leaf(tree, value)

    %Anoma.LocalDomain.MerkleTree{
      nodes:
        Map.merge(%{0 => new_leaves}, calculate_nodes(new_leaves, 1))
    }
  end

  def generate_proof(tree, leaf) do
    {frontiers, root} =
      for i <- 0..(depth(tree) - 1), reduce: {[], leaf} do
        {acc, leaf} ->
          leaves = Map.get(tree.nodes, i)

          leaf_index =
            leaves
            |> Enum.find_index(&(&1 == leaf))

          is_left = (leaf_index &&& 1) == 0

          if is_left do
            neighbour = Enum.at(leaves, leaf_index + 1)

            {acc ++ [{neighbour, true}], hash(leaf <> neighbour)}
          else
            neighbour = Enum.at(leaves, leaf_index - 1)

            {acc ++ [{neighbour, false}], hash(neighbour <> leaf)}
          end
      end

    if root == root(tree) do
      {frontiers, root}
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
end
