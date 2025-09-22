defmodule Examples.EFactory do
  @moduledoc """
  I provide the examples for Anoma.LocalDomain.Factory
  """

  alias Anoma.LocalDomain.Factory

  require ExUnit.Assertions
  import ExUnit.Assertions

  use Anoma.LocalDomain

  @spec store_api_handler() :: String.t()
  def store_api_handler() do
    Factory.store("constantly", "get", fn name -> name end)

    assert {:ok, func} =
             Anoma.LocalDomain.Storage.read_local(
               ~k"/api_handler/constantly/get"
             )

    assert func.("constant") == "constant"

    func
  end

  @spec factorial_api_handler() :: String.t()
  def factorial_api_handler() do
    Anoma.LocalDomain.Factory.init()

    factorial_fn = fn
      "1" ->
        1

      n ->
        n1 = Integer.to_string(String.to_integer(n) - 1)

        {:ok, result} =
          Anoma.LocalDomain.Scry.scry(
            ~k"/anoma/local/foo/bar/factory/factorial/get/!n1"
          )

        String.to_integer(n) * result
    end

    Factory.store("factorial", "get", factorial_fn)

    Anoma.LocalDomain.Scry.scry(
      ~k"/anoma/local/foo/bar/factory/factorial/get/5"
    )
  end
end
