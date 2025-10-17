defmodule MerkleTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.MerkleTree

  test "Run the examples" do
    Examples.EMerkleTree.write_to_merkle_tree()
    Examples.EMerkleTree.expand_merkle_tree()
    Examples.EMerkleTree.generate_a_proof()
    Examples.EMerkleTree.generate_a_proof_wrongly()
    Examples.EMerkleTree.verify_a_proof()
    Examples.EMerkleTree.random_tree()
  end
end
