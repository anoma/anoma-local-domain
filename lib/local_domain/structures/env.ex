defmodule Anoma.LocalDomain.Env do
  @moduledoc """
  I provide the compilation environment for resources and corresponding API
  """

  use TypedStruct

  typedstruct enforce: true do
    field(:consumed, any())
    field(:created, any())
  end

  def empty() do
    %__MODULE__{
      consumed: MapSet.new([]),
      created: MapSet.new([])
    }
  end
end
