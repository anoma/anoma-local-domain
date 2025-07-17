defmodule Anoma.LocalDomain.Factory do
  @moduledoc """
  I am a sample local domain application: an API endpoint creator
  """

  use Anoma.LocalDomain.Application, name: "factory"
  use Anoma.LocalDomain.DefScry

  
  @spec store(String.t(), String.t(), (term() -> term())) :: term()
  def store(name, method, key) do
    Anoma.LocalDomain.Storage.write_local(
      ~k"/api_handler/!name/!method",
      key
    )
  end
  
 
  defscry do
    (_prev_prefixes, ~k"/!name/!method/&params") ->
      with {:ok, api_handler} <- Anoma.LocalDomain.Scry.scry(~k"/anoma/local/foo/bar/api_handler/!name/!method") do 
        {:ok, apply(api_handler, params)}
      end
  end
end

