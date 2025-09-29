defmodule StorageTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain.Storage

  test "Run the examples" do
    Examples.EStorage.read_and_write_to_node()
  end
end
