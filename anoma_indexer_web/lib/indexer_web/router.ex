defmodule IndexerWeb.Router do
  use Plug.Router
  alias Anoma.LocalDomain.System.Poller, as: Poller

  plug Plug.Logger
  plug CORSPlug
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :match
  plug :dispatch

  defp ok(conn, data \\ %{}, status \\ 200),
    do: Plug.Conn.send_resp(conn, status, Jason.encode!(data))

  get "/add_key/:key" do
    send_resp(conn, 200, "TODO")
  end

  get "/all_tags/:key" do
    IO.puts(Anoma.LocalDomain.Storage.ls("/resource"))
    send_resp(conn, 200, "TODO")
  end

  get "/resource/:tag/:key" do
    send_resp(conn, 200, "TODO")
  end

    match _ do
    Plug.Conn.send_resp(conn, 404, Jason.encode!(%{error: "not_found"}))
  end
end
