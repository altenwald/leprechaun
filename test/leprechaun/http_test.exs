defmodule Leprechaun.HttpTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Leprechaun.Http

  test "serves the game and static assets" do
    page = Http.call(conn(:get, "/"), Http.init([]))
    assert page.status == 200
    assert page.resp_body =~ "Leprechaun"
    assert Plug.Conn.get_resp_header(page, "content-type") == ["text/html; charset=utf-8"]

    for path <- ["/js/index.js", "/css/app.css", "/img/leprechaun.png", "/audio/extra_turn.mp3"] do
      assert Http.call(conn(:get, path), Http.init([])).status == 200
    end
  end

  test "does not serve removed features or private data" do
    for path <- ["/bot/", "/bot.html", "/data/mnesia/schema.DAT", "/repo/migrations", "/missing"] do
      assert Http.call(conn(:get, path), Http.init([])).status == 404
    end
  end

  test "trusts forwarded client addresses only from the loopback proxy" do
    local = conn(:get, "/") |> Plug.Conn.put_req_header("x-forwarded-for", "192.0.2.15")
    assert Http.remote_ip(local) == "192.0.2.15"
    assert Http.remote_ip(conn(:get, "/")) == "127.0.0.1"

    external = put_peer_data(local, %{address: {192, 0, 2, 20}, port: 1234, ssl_cert: nil})
    assert Http.remote_ip(external) == "192.0.2.20"
  end
end
