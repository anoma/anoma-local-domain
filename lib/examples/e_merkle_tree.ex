defmodule Examples.EMerkleTree do
  require ExUnit.Assertions
  import ExUnit.Assertions
  alias Anoma.LocalDomain.MerkleTree

  def add_leaf_to_merkle_tree() do
    empty_tree = MerkleTree.new()

    empty_tree |> MerkleTree.add_leaf(:crypto.hash(:sha256, "a"))
  end

  def write_to_merkle_tree() do
    empty_tree = MerkleTree.new()

    new_tree =
      empty_tree
      |> MerkleTree.add(:crypto.hash(:sha256, "a"))

    assert Enum.at(Map.get(new_tree.nodes, 1), 0) ==
             :crypto.hash(
               :sha256,
               :crypto.hash(:sha256, "a") <>
                 :crypto.hash(:sha256, "EMPTY")
             )

    new_tree
  end

  def expand_merkle_tree() do
    new_tree =
      write_to_merkle_tree()
      |> MerkleTree.add(:crypto.hash(:sha256, "b"))
      |> MerkleTree.add(:crypto.hash(:sha256, "c"))

    new_tree
  end

  def generate_a_proof() do
    tree = expand_merkle_tree()

    {frontiers, root} =
      MerkleTree.generate_proof(tree, :crypto.hash(:sha256, "b"))

    assert root == MerkleTree.root(tree)
    {frontiers, root}
  end

  def verify_a_proof() do
    {frontiers, root} = generate_a_proof()
    MerkleTree.verify_proof(:crypto.hash(:sha256, "b"), frontiers, root)
  end
end
