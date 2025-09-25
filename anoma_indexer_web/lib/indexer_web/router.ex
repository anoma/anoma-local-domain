defmodule IndexerWeb.Router do
  use Plug.Router
  alias Anoma.LocalDomain.System.GraphQLPoller, as: Poller

  plug Plug.Logger
  plug CORSPlug
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :match
  plug :dispatch

  defp ok(conn, data \\ %{}, status \\ 200),
    do: Plug.Conn.send_resp(conn, status, Jason.encode!(data))

    match _ do
    Plug.Conn.send_resp(conn, 404, Jason.encode!(%{error: "not_found"}))
  end
end
