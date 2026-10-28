defmodule Leprechaun.WebsocketTest do
  use ExUnit.Case

  alias Leprechaun.{Game, HiScore, Repo, Websocket}

  test "sends the version when the WebSock session opens" do
    assert {:push, {:text, reply}, state} = Websocket.init(remote_ip: "192.0.2.1")
    assert Jason.decode!(reply)["type"] == "vsn"
    assert state == %{board: nil, remote_ip: "192.0.2.1"}
  end

  test "handles malformed input and game events without losing the state" do
    state = %{board: nil, remote_ip: "127.0.0.1"}
    assert {:push, {:text, "eh?"}, ^state} = Websocket.handle_in({"{", opcode: :text}, state)
    assert {:push, {:text, "eh?"}, ^state} = Websocket.handle_in({<<0>>, opcode: :binary}, state)
    assert {:ok, ^state} = Websocket.handle_info({:hiscore, nil}, state)
    assert {:push, {:text, reply}, ^state} = Websocket.handle_info({:insert, 2, 1}, state)

    assert Jason.decode!(reply) == %{
             "type" => "slide_new",
             "row" => 1,
             "col" => 2,
             "piece" => "bronze"
           }
  end

  test "retired code execution returns an error without closing the session" do
    state = %{board: nil, remote_ip: "127.0.0.1"}
    message = Jason.encode!(%{"type" => "run", "code" => "legacy script"})

    assert {:push, {:text, reply}, ^state} = Websocket.handle_in({message, opcode: :text}, state)
    assert Jason.decode!(reply) == %{"type" => "error", "reason" => "unsupported_message"}

    assert {:push, {:text, pong}, ^state} =
             Websocket.handle_in({~s({"type":"ping"}), opcode: :text}, state)

    assert Jason.decode!(pong) == %{"type" => "pong"}
  end

  test "a legacy bot identifier does not prevent joining a normal game" do
    state = %{board: nil, remote_ip: "127.0.0.1"}

    assert {:push, {:text, _reply}, %{board: id}} =
             Websocket.handle_in({~s({"type":"create"}), opcode: :text}, state)

    on_exit(fn -> if Game.exists?(id), do: Game.stop(id) end)
    message = Jason.encode!(%{"type" => "join", "id" => id, "bot_id" => "retired-bot"})

    assert {:ok, joined} = Websocket.handle_in({message, opcode: :text}, state)
    assert joined == %{state | board: id}
    assert Game.exists?(id)
  end

  test "serializes board updates and special pieces for the browser" do
    state = start_game()
    cells = [Enum.to_list(0..10)]

    images = [
      "",
      "bronze",
      "silver",
      "gold",
      "sack",
      "chest",
      "big-chest",
      "pot",
      "rainbow-pot",
      "leprechaun-head",
      "clover"
    ]

    draw = event({:show, cells}, state)
    assert draw["score"] == 0
    assert draw["turns"] == 10
    assert Enum.map(hd(draw["cells"]), & &1["image"]) == images
    assert Enum.map(hd(draw["cells"]), & &1["col"]) == Enum.to_list(1..11)
    assert Enum.all?(hd(draw["cells"]), &(&1["row"] == 1))

    match = event({:match, 5, 20, [vertical: [{1, 2}, {1, 3}]], cells}, state)
    assert match["type"] == "match"
    assert match["add_score"] == 5
    assert match["score"] == 20
    assert match["points"] == [%{"row" => 2, "col" => 1}, %{"row" => 3, "col" => 1}]
    assert match["cells"] == draw["cells"]

    assert event({:slide, 2, 1, 3}, state) == %{
             "type" => "slide",
             "orig" => %{"row" => 1, "col" => 2},
             "dest" => %{"row" => 3, "col" => 2}
           }

    assert event({:new_kind, 3, 4, 5}, state) == %{
             "type" => "new_kind",
             "row" => 4,
             "col" => 3,
             "piece" => "chest"
           }

    assert event({:extra_turn, 1}, state) == %{
             "type" => "extra_turn",
             "extra_turns" => 1,
             "turns" => 10
           }

    assert event(:play, state) == %{"type" => "play", "turns" => 10}
    assert event({:leprechaun, 3}, state) == %{"type" => "leprechaun", "cell" => 3}
    assert event({:clover, 4}, state) == %{"type" => "clover", "cell" => 4}
  end

  test "forwards queued frames and handles termination and unknown events" do
    state = %{board: nil, remote_ip: "127.0.0.1"}
    assert {:push, {:text, "queued"}, ^state} = Websocket.handle_info({:send, "queued"}, state)

    assert {:push, {:text, "timeout"}, ^state} =
             Websocket.handle_info({:timeout, make_ref(), "timeout"}, state)

    assert {:ok, ^state} = Websocket.handle_info(:unknown_event, state)
    assert :ok = Websocket.terminate(:normal, state)
  end

  test "moves, shows, restarts and stops a real game" do
    state = start_game()
    assert {:push, {:text, payload}, ^state} = command(%{"type" => "show"}, state)

    assert %{"type" => "draw", "score" => 0, "turns" => 10, "cells" => cells} =
             Jason.decode!(payload)

    assert length(cells) == 8

    assert {:ok, ^state} =
             command(%{"type" => "move", "x1" => 1, "y1" => 1, "x2" => 8, "y2" => 8}, state)

    assert_receive {:error, {:illegal_move, {{1, 1}, {8, 8}}}} = error

    assert event(error, state) == %{
             "type" => "illegal_move",
             "points" => [
               %{"row" => 1, "col" => 1},
               %{"row" => 8, "col" => 8}
             ]
           }

    assert {:push, {:text, restarted}, ^state} = command(%{"type" => "restart"}, state)
    assert Jason.decode!(restarted)["turns"] == 10
    assert_receive {:send, play}
    assert Jason.decode!(play) == %{"type" => "play"}
    assert {:ok, ^state} = command(%{"type" => "stop"}, state)
    assert_unregistered(state.board, 50)
    assert {:ok, ^state} = command(%{"type" => "stop"}, state)
  end

  test "missing and finished games return gameover, and missing games can restart" do
    missing = %{board: UUID.uuid4(), remote_ip: "127.0.0.1"}
    on_exit(fn -> if Game.exists?(missing.board), do: Game.stop(missing.board) end)

    for message <- [
          %{"type" => "join", "id" => missing.board},
          %{"type" => "show"},
          %{"type" => "move", "x1" => 1, "y1" => 1, "x2" => 2, "y2" => 1}
        ] do
      assert {:push, {:text, reply}, ^missing} = command(message, missing)
      assert Jason.decode!(reply) == %{"type" => "gameover", "turns" => 0, "error" => true}
    end

    assert {:push, {:text, _}, ^missing} = command(%{"type" => "restart"}, missing)
    assert Game.exists?(missing.board)
    finished = start_game(turns: 0)

    assert {:push, {:text, reply}, ^finished} =
             command(%{"type" => "join", "id" => finished.board}, finished)

    assert Jason.decode!(reply) == %{"type" => "gameover", "turns" => 0}
    assert {:push, {:text, reply}, ^finished} = command(%{"type" => "show"}, finished)
    assert Jason.decode!(reply)["error"]

    assert event({:gameover, 123, false}, finished) == %{
             "type" => "gameover",
             "score" => 123,
             "turns" => 0,
             "has_username" => false
           }

    assert event({:error, :gameover}, finished) == %{
             "type" => "gameover",
             "score" => 0,
             "turns" => 0,
             "has_username" => true
           }
  end

  test "saves a finished score once and returns the ranking" do
    Repo.delete_all(HiScore)
    on_exit(fn -> Repo.delete_all(HiScore) end)
    playing = start_game()

    assert {:push, {:text, error}, ^playing} =
             command(%{"type" => "set-hiscore-name", "name" => "Player"}, playing)

    assert Jason.decode!(error) == %{
             "type" => "set-hiscore-name-error",
             "reason" => ":still_playing"
           }

    finished = start_game(turns: 0)

    assert {:ok, ^finished} =
             command(%{"type" => "set-hiscore-name", "name" => "Player"}, finished)

    assert_receive {:hiscore, 1}
    assert Repo.get_by!(HiScore, name: "Player").remote_ip == finished.remote_ip
    ranking = event({:hiscore, 1}, finished)

    assert ranking == %{
             "type" => "hiscore",
             "position" => 1,
             "top_list" => [%{"position" => 0, "name" => "Player", "score" => 0, "turns" => 0}]
           }

    assert {:push, {:text, payload}, ^finished} = command(%{"type" => "hiscore"}, finished)
    assert Jason.decode!(payload) == %{ranking | "position" => nil}

    assert {:push, {:text, error}, ^finished} =
             command(%{"type" => "set-hiscore-name", "name" => "Again"}, finished)

    assert Jason.decode!(error)["reason"] == ":already_set"
    assert Repo.aggregate(HiScore, :count) == 1
  end

  defp assert_unregistered(name, attempts) do
    exists? = Game.exists?(name)

    if exists? and attempts > 0 do
      Process.sleep(10)
      assert_unregistered(name, attempts - 1)
    else
      refute exists?
    end
  end

  defp start_game(opts \\ []) do
    name = UUID.uuid4()
    {:ok, _} = Game.start(Keyword.put(opts, :name, name))
    on_exit(fn -> if Game.exists?(name), do: Game.stop(name) end)
    %{board: name, remote_ip: "192.0.2.15"}
  end

  defp command(message, state) do
    Websocket.handle_in({Jason.encode!(message), opcode: :text}, state)
  end

  defp event(message, state) do
    assert {:push, {:text, payload}, ^state} = Websocket.handle_info(message, state)
    Jason.decode!(payload)
  end
end
