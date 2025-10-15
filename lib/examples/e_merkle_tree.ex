defmodule Examples.EMerkleTree do
  require ExUnit.Assertions
  import ExUnit.Assertions
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

  def add_100k_leaves() do
    initial_leaf = :crypto.hash(:sha256, "25 k")

    leaves =
      for _i <- 2..100_000, reduce: [initial_leaf] do
        [hd | tl] -> [:crypto.hash(:sha256, hd) | [hd | tl]]
      end

    MerkleTree.add(empty_tree(), leaves)
  end

  def add_100k_leaves_on_top() do
    tree = add_100k_leaves()
    initial_leaf = :crypto.hash(:sha256, "another one")

    leaves =
      for _i <- 2..100_000, reduce: [initial_leaf] do
        [hd | tl] -> [:crypto.hash(:sha256, hd) | [hd | tl]]
      end

    MerkleTree.add(tree, leaves)
  end

  def add_100k_leaves_more_on_top() do
    tree = add_100k_leaves_on_top()
    initial_leaf = :crypto.hash(:sha256, "and another one")

    leaves =
      for _i <- 2..100_000, reduce: [initial_leaf] do
        [hd | tl] -> [:crypto.hash(:sha256, hd) | [hd | tl]]
      end

    MerkleTree.add(tree, leaves)
  end
end
