defmodule Examples.EMerkleTree do
  require ExUnit.Assertions
  import ExUnit.Assertions
  alias Anoma.LocalDomain.BatchMerkleTree
  alias Anoma.LocalDomain.MerkleTree

  def empty_tree() do
    MerkleTree.new()
  end

  def write_to_merkle_tree() do
    new_tree =
      empty_tree()
      |> MerkleTree.add([:crypto.hash(:sha256, "a")])

    assert Map.get(Map.get(new_tree.nodes, 1), 0) ==
             :crypto.hash(
               :sha256,
               :crypto.hash(:sha256, "a") <>
                 :crypto.hash(:sha256, "EMPTY")
             )

    assert new_tree.capacity == 2

    new_tree
  end

  def expand_merkle_tree() do
    new_tree =
      write_to_merkle_tree()
      |> MerkleTree.add([
        :crypto.hash(:sha256, "b"),
        :crypto.hash(:sha256, "c")
      ])

    assert new_tree.capacity == 4

    new_tree
  end

  def generate_a_proof() do
    tree = expand_merkle_tree()

    {frontiers, root} =
      MerkleTree.generate_proof(tree, :crypto.hash(:sha256, "b"))

    assert root == MerkleTree.root(tree)
    {frontiers, root}
  end

  def generate_a_proof_wrongly() do
    tree = expand_merkle_tree()

    assert nil ==
             MerkleTree.generate_proof(tree, :crypto.hash(:sha256, "d"))

    :ok
  end

  def verify_a_proof() do
    {frontiers, root} = generate_a_proof()
    MerkleTree.verify_proof(:crypto.hash(:sha256, "b"), frontiers, root)
  end

  def random_tree() do
    leaves_length = :rand.uniform(7000) + 500

    # For uniqueness of leaves, introduce initial bytes to hash
    initial_leaf = :crypto.strong_rand_bytes(32)

    leaves =
      for _i <- 2..leaves_length, reduce: [initial_leaf] do
        [hd | tl] -> [:crypto.hash(:sha256, hd) | [hd | tl]]
      end

    new_tree = MerkleTree.add(empty_tree(), leaves)

    sorted_leaves =
      Map.get(new_tree.nodes, 0)
      |> Map.to_list()
      |> Enum.sort(fn {ind1, _}, {ind2, _} -> ind1 < ind2 end)
      |> Enum.map(&elem(&1, 1))

    # Check that the leaves are as expected
    assert List.starts_with?(sorted_leaves, leaves)

    # Check that index is as expected
    assert new_tree.next_index == leaves_length

    # Check that the capacity is as expected
    expected_depth = (leaves_length |> :math.log2() |> trunc()) + 1
    assert new_tree.capacity == 2 ** expected_depth
    assert MerkleTree.depth(new_tree) == expected_depth

    new_tree
  end

  def merkle_tree_differential_root_comparisson(leaves_number \\ 10_000) do
    tree1 = MerkleTree.new()
    tree2 = BatchMerkleTree.new()

    for i <- 1..leaves_number, reduce: {tree1, tree2} do
      {tree1, tree2} ->
        leaf = :crypto.hash(:sha256, :erlang.term_to_binary(i))
        upd_tree1 = MerkleTree.add(tree1, [leaf])
        upd_tree2 = BatchMerkleTree.add(tree2, [leaf])

        assert MerkleTree.root(upd_tree1) ==
                 BatchMerkleTree.root(upd_tree2)

        {upd_tree1, upd_tree2}
    end
  end

  def merkle_tree_differential_proof_comparisson(leaves_number \\ 100) do
    {tree1, tree2} =
      merkle_tree_differential_root_comparisson(leaves_number)

    leaves = Map.get(tree1.nodes, 0)

    for leaf <- leaves do
      assert MerkleTree.generate_proof(tree1, leaf) ==
               BatchMerkleTree.generate_proof(tree2, leaf)
    end
  end
end
