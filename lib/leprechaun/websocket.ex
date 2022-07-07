defmodule Leprechaun.Websocket do
  @moduledoc """
  Implements the modules needed to attend a websocket connection from
  cowboy. It's interacting with the websocket receiving information
  from the websocket and from the application and acting according to
  the message it receives from each part.

  The logic of the game is kept in `Leprechaun.Game` but here we can
  find the flow of the connection and how the client could interact
  with the game.
  """
  require Logger
  alias Leprechaun.{Game, Bot, HiScore}

  @doc false
  @spec init(:cowboy_req.req(), []) ::
          {:cowboy_websocket, :cowboy_req.req(), [{:remote_ip, Game.remote_ip()}]}
  def init(req, []) do
    Logger.info("[websocket] init req => #{inspect(req)}")

    remote_ip =
      case :cowboy_req.peer(req) do
        {{127, 0, 0, 1}, _} ->
          case :cowboy_req.header("x-forwarded-for", req) do
            remote_ip when is_binary(remote_ip) -> remote_ip
            :undefined -> "127.0.0.1"
          end

        {remote_ip, _} ->
          to_string(:inet.ntoa(remote_ip))
      end

    {:cowboy_websocket, req, [{:remote_ip, remote_ip}]}
  end

  @doc false
  def websocket_init(remote_ip: remote_ip) do
    vsn = to_string(Application.spec(:leprechaun)[:vsn])
    send(self(), {:send, Jason.encode!(%{"type" => "vsn", "vsn" => vsn})})
    {:ok, %{board: nil, remote_ip: remote_ip}}
  end

  @doc false
  def websocket_handle({:text, msg}, state) do
    msg
    |> Jason.decode!()
    |> process_data(state)
  end

  def websocket_handle(_any, state) do
    {:reply, {:text, "eh?"}, state}
  end

  @doc false
  def websocket_info({:send, data}, state) do
    {:reply, {:text, data}, state}
  end

  def websocket_info({:timeout, _ref, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info(:play, state) do
    turns = Game.turns(state.board)
    {:reply, {:text, Jason.encode!(%{"type" => "play", "turns" => turns})}, state}
  end

  def websocket_info({:insert, x, piece}, state) do
    msg = %{"type" => "slide_new", "row" => 1, "col" => x, "piece" => img(piece)}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:slide, x, y_orig, y_dest}, state) do

    msg = %{
      "type" => "slide",
      "orig" => %{"row" => y_orig, "col" => x},
      "dest" => %{"row" => y_dest, "col" => x}
    }

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:new_kind, x, y, new_kind}, state) do
    msg = %{"type" => "new_kind", "row" => y, "col" => x, "piece" => img(new_kind)}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:extra_turn, extra_turns}, state) do
    turns = Game.turns(state.board)
    msg = %{"type" => "extra_turn", "extra_turns" => extra_turns, "turns" => turns}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:match, score, global_score, acc, cells}, state) do

    acc =
      for {_, points} <- acc do
        for {x, y} <- points do
          %{"row" => y, "col" => x}
        end
      end
      |> List.flatten()

    msg = %{
      "type" => "match",
      "add_score" => score,
      "score" => global_score,
      "points" => acc,
      "cells" => build_show(cells)
    }

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:show, cells}, %{board: board} = state) do

    msg = %{
      "type" => "draw",
      "cells" => build_show(cells),
      "score" => Game.score(board),
      "turns" => Game.turns(board)
    }

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:gameover, score, has_username}, state) do
    msg = %{"type" => "gameover", "score" => score, "turns" => 0, "has_username" => has_username}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:error, :gameover}, state) do
    score = Game.score(state.board)
    msg = %{"type" => "gameover", "score" => score, "turns" => 0, "has_username" => true}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:error, {:illegal_move, {{x1, y1}, {x2, y2}}}}, state) do
    msg = %{
      "type" => "illegal_move",
      "points" => [%{"row" => y1, "col" => x1}, %{"row" => y2, "col" => x2}]
    }

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:hiscore, order}, state) do
    if order, do: send_hiscore(order, state)
  end

  def websocket_info(info, state) do
    Logger.info("info => #{inspect(info)}")
    {:ok, state}
  end

  @doc false
  def websocket_terminate(reason, _state) do
    Logger.info("reason => #{inspect(reason)}")
    :ok
  end

  defp build_show(cells) when is_list(cells) do
    for {row, y} <- Enum.with_index(cells, 1) do
      for {cell, x} <- Enum.with_index(row, 1) do
        %{"image" => img(cell), "row" => y, "col" => x}
      end
    end
  end

  defp build_show(board_id), do: build_show(Game.show(board_id))

  defp send_hiscore(order \\ nil, state) do
    top_list =
      HiScore.top_list()
      |> Enum.with_index()
      |> Enum.map(fn {%HiScore{} = hiscore, position} ->
        %{
          "position" => position,
          "name" => hiscore.name,
          "score" => hiscore.score,
          "turns" => hiscore.turns
        }
      end)

    msg = %{"type" => "hiscore", "top_list" => top_list, "position" => order}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "ping"}, state) do
    {:reply, {:text, Jason.encode!(%{"type" => "pong"})}, state}
  end

  defp process_data(%{"type" => "run", "code" => code} = info, state) do
    if state[:bot_id] != nil do
      if Bot.exists?(state.bot_id) do
        result = Bot.run(state.bot_id, code)
        msg = %{"type" => "log", "info" => result}
        {:reply, {:text, Jason.encode!(msg)}, state}
      else
        process_data(info, Map.delete(state, :bot_id))
      end
    else
      id = UUID.uuid4()
      Bot.start_link(id, state.board)
      result = Bot.run(id, code)
      msg = %{"type" => "log", "info" => result}
      send(self(), {:send, Jason.encode!(%{"type" => "bot_id", "id" => id})})
      {:reply, {:text, Jason.encode!(msg)}, Map.put(state, :bot_id, id)}
    end
  end

  defp process_data(%{"type" => "hiscore"}, state) do
    send_hiscore(state)
  end

  defp process_data(%{"type" => "set-hiscore-name", "name" => username}, state) do
    case Game.hiscore(state.board, username, state.remote_ip) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        msg = %{"type" => "set-hiscore-name-error", "reason" => "#{inspect(reason)}"}
        {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "create"}, state) do
    id = UUID.uuid4()
    {:ok, _board} = Game.start_link(id)
    msg = %{"type" => "id", "id" => id}
    {:reply, {:text, Jason.encode!(msg)}, Map.put(state, :board, id)}
  end

  defp process_data(%{"type" => "join", "id" => id} = info, state) do
    if Game.exists?(id) do
      state = Map.put(state, :board, id)

      if Game.turns(id) > 0 do
        Game.add_consumer(id)

        if info["bot_id"] != nil do
          Bot.set_websocket_pid(info["bot_id"])
          {:ok, Map.put(state, :bot_id, info["bot_id"])}
        else
          {:ok, state}
        end
      else
        msg = %{"type" => "gameover", "turns" => 0}
        {:reply, {:text, Jason.encode!(msg)}, state}
      end
    else
      msg = %{"type" => "gameover", "turns" => 0, "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(
         %{"type" => "move", "x1" => x1, "y1" => y1, "x2" => x2, "y2" => y2},
         state
       ) do
    if Game.exists?(state.board) do
      point1 = {x1, y1}
      point2 = {x2, y2}
      Game.move(state.board, point1, point2)
      {:ok, state}
    else
      msg = %{"type" => "gameover", "turns" => 0, "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "show"}, %{board: board} = state) do
    if Game.exists?(board) and Game.turns(board) > 0 do
      msg = %{
        "type" => "draw",
        "cells" => build_show(board),
        "score" => Game.score(board),
        "turns" => Game.turns(board)
      }

      {:reply, {:text, Jason.encode!(msg)}, state}
    else
      msg = %{"type" => "gameover", "turns" => 0, "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "restart"}, %{board: board} = state) do
    if Game.exists?(board), do: Game.stop(board)
    {:ok, _} = Game.start_link(board)

    msg = %{
      "type" => "draw",
      "cells" => build_show(state.board),
      "score" => Game.score(board),
      "turns" => Game.turns(board)
    }

    send(self(), {:send, Jason.encode!(%{"type" => "play"})})
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "stop"}, %{board: board} = state) do
    if Game.exists?(board), do: Game.stop(board)
    {:ok, state}
  end

  defp img(0), do: ""
  defp img(1), do: "bronze"
  defp img(2), do: "silver"
  defp img(3), do: "gold"
  defp img(4), do: "sack"
  defp img(5), do: "chest"
  defp img(6), do: "big-chest"
  defp img(7), do: "pot"
  defp img(8), do: "rainbow-pot"
end
