defmodule IndexerWeb.Router do
  use Plug.Router
  use Anoma.LocalDomain

  alias Anoma.LocalDomain.System.Poller, as: Poller

  plug(Plug.Logger)
  plug(CORSPlug)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:match)
  plug(:dispatch)

  defp ok(conn, data \\ %{}, status \\ 200),
    do: Plug.Conn.send_resp(conn, status, Jason.encode!(data))

  post "/add_key" do
    keypair = %{
      public_key: conn.body_params["public_key"],
      secret_key: conn.body_params["secret_key"]
    }
    node_id = System.get_env("LOCAL_DOMAIN_NODE_ID")

    Anoma.LocalDomain.System.Poller.add_cipher_keypair(node_id, keypair)
    send_resp(conn, 200, "OK")
  end

  get "/tags/:public_key" do
    contract = System.get_env("PA_CONTRACT_ID")
    node_id = System.get_env("LOCAL_DOMAIN_NODE_ID")
    {:ok, ls} = Anoma.LocalDomain.Storage.ls(~k"!contract/resource/!public_key")

    send_resp(
      conn,
      200,
      ls
      |> Enum.map(fn k -> List.last(k) end)
      |> Jason.encode!()
    )
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, Jason.encode!(%{error: "not_found"}))
  end
end
