defmodule Examples.EMerkleTree do
  require ExUnit.Assertions
  import ExUnit.Assertions
  alias Anoma.LocalDomain.MerkleTree
  alias Anoma.LocalDomain.MerkleTreeChunk

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

  def block_with_hundred_commits() do
    initial_leaf = :crypto.strong_rand_bytes(32)

    for _i <- 2..300, reduce: [initial_leaf] do
      [hd | tl] -> [:crypto.hash(:sha256, hd) | [hd | tl]]
    end
  end

  def five_k_blocks(tree, block) do
    for _i <- 1..5000, reduce: tree do
      tree -> MerkleTree.add(tree, block)
    end
  end

  def merkle_tree_differential() do
    tree1 = MerkleTree.new()
    tree2 = MerkleTreeChunk.new()

    for i <- 1..500000, reduce: {tree1, tree2} do
      {tree1, tree2} ->
        leaf = :crypto.hash(:sha256, :erlang.term_to_binary(i))
        upd_tree1 = MerkleTree.add(tree1, [leaf])
        upd_tree2 = MerkleTreeChunk.add(tree2, [leaf])
        assert MerkleTree.root(upd_tree1) == MerkleTreeChunk.root(upd_tree2)

        {upd_tree1, upd_tree2}
    end
  end

  def block(number) do
    initial_leaf = :crypto.strong_rand_bytes(32)

    for _i <- 2..number, reduce: [initial_leaf] do
      [hd | tl] -> [:crypto.hash(:sha256, hd) | [hd | tl]]
    end
  end

  def merkle_tree_comparisson(block_size, block_number) do
    tree1 = MerkleTree.new()
    tree2 = MerkleTreeChunk.new()

   {{t1, _}, {t2, _}} =  for _i <- 1..block_number, reduce: {{0, tree1}, {0, tree2}} do
      {{time1, tree1}, {time2, tree2}} ->
        block = block(block_size)
        {time_tree1, upd_tree1} = :timer.tc(fn -> MerkleTree.add(tree1, block) end)
        {time_tree2, upd_tree2} = :timer.tc(fn -> MerkleTreeChunk.add(tree2, block) end)

        {{time1 + time_tree1, upd_tree1}, {time2 + time_tree2, upd_tree2}}
    end

    if t1 > t2 do
      IO.puts("Batch Approach is Faster")
      IO.puts("Block size: #{inspect(block_size)}")
      IO.puts("Block number: #{inspect(block_number)}")
      IO.puts("Time factor difference: #{inspect(t1 / t2)}")
    else
      IO.puts("Sequential Approach is Faster")
      IO.puts("Block size: #{inspect(block_size)}")
      IO.puts("Block number: #{inspect(block_number)}")
      IO.puts("Time factor difference: #{inspect(t2 / t1)}")
    end
  end
end
