defmodule Leprechaun.Http do
  @moduledoc """
  Plug routes for the browser game, static assets and WebSocket connections.
  """
  use Plug.Router

  plug(Plug.Head)

  plug(Plug.Static,
    at: "/",
    from: {:leprechaun, "priv"},
    only: ~w(audio img js css favicon.ico)
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:leprechaun, "priv/index.html"))
  end

  get "/websession" do
    conn
    |> WebSockAdapter.upgrade(Leprechaun.Websocket, [remote_ip: remote_ip(conn)], timeout: 60_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  @doc """
  Returns the client address, trusting forwarded addresses only from configured proxies.
  """
  @spec remote_ip(Plug.Conn.t()) :: String.t()
  def remote_ip(conn) do
    address =
      conn |> Plug.Conn.get_peer_data() |> Map.fetch!(:address) |> :inet.ntoa() |> to_string()

    trusted_proxies = Application.get_env(:leprechaun, :trusted_proxies, ["127.0.0.1", "::1"])

    if address in trusted_proxies do
      case get_req_header(conn, "x-forwarded-for") do
        [forwarded | _] -> forwarded
        [] -> address
      end
    else
      address
    end
  end
end
