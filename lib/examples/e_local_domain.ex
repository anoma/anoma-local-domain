defmodule Examples.ELocalDomain do
  @moduledoc """
  I provide the examples for Anoma.LocalDomain
  """

  use ExExample
  use Anoma.LocalDomain
  
  require ExUnit.Assertions
  import ExUnit.Assertions
  
  example sigil_key_segment_pattern_match do
    c = "segment c"

    assert ~k"/a/b/!c" == ["a", "b", "segment c"]

    ~k"/a/b/!c" = ["a", "b", "matched c"]

    assert c == "matched c"

    c    
  end

  example sigil_rest_segment_pattern_match do
    :rest

    ~k"/a/&rest" = ["a", "b", "c"]

    assert rest == ["b", "c"]
  end
  
  def rerun?(_), do: false

end
