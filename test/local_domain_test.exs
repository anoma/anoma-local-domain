defmodule LocalDomainTest do
  use ExUnit.Case
  doctest Anoma.LocalDomain

  test "Run the examples" do
    Examples.ELocalDomain.sigil_key_segment_pattern_match()
    Examples.ELocalDomain.sigil_rest_segment_pattern_match()
  end
end
