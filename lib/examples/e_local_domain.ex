defmodule LocalDomain.Examples.ELocalDomain do
  @moduledoc """
  I provide the examples for Anoma.LocalDomain
  """

  require ExUnit.Assertions
  import ExUnit.Assertions
  use Anoma.LocalDomain

  @spec sigil_key_segment_pattern_match() :: String.t()
  def sigil_key_segment_pattern_match() do
    c = "segment c"

    assert ~k"/a/b/!c" == ["a", "b", "segment c"]

    ~k"/a/b/!c" = ["a", "b", "matched c"]

    assert c == "matched c"

    c
  end

  @spec sigil_rest_segment_pattern_match() :: [String.t()]
  def sigil_rest_segment_pattern_match() do
    :rest

    ~k"/a/&rest" = ["a", "b", "c"]

    assert rest == ["b", "c"]
  end
end
