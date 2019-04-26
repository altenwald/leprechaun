defmodule Leprechaun.Websocket do
  require Logger
  alias Leprechaun.{Board, Bot, HiScore}

  @throttle_time_to_wait 100

  defp check_throttle(_id), do: Process.sleep(@throttle_time_to_wait)

  def init(req, opts) do
    Logger.info "[websocket] init req => #{inspect req}"
    remote_ip = case :cowboy_req.peer(req) do
      {{127, 0, 0, 1}, _} ->
        case :cowboy_req.header("x-forwarded-for", req) do
          {remote_ip, _} -> remote_ip
          _ -> "127.0.0.1"
        end
      {remote_ip, _} ->
        to_string(:inet.ntoa(remote_ip))
    end
    {:cowboy_websocket, req, [{:remote_ip, remote_ip}|opts]}
  end

  def websocket_init(remote_ip: remote_ip) do
    vsn = to_string(Application.spec(:leprechaun)[:vsn])
    send self(), {:send, Jason.encode!(%{"type" => "vsn", "vsn" => vsn})}
    {:ok, %{board: nil, remote_ip: remote_ip}}
  end

  def websocket_handle({:text, msg}, state) do
    msg
    |> Jason.decode!()
    |> process_data(state)
  end

  def websocket_handle(_any, state) do
    {:reply, {:text, "eh?"}, state}
  end

  def websocket_info({:send, data}, state) do
    check_throttle(state.board)
    {:reply, {:text, data}, state}
  end
  def websocket_info({:timeout, _ref, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info(:play, state) do
    check_throttle(state.board)
    turns = Board.turns(state.board)
    {:reply, {:text, Jason.encode!(%{"type" => "play", "turns" => turns})}, state}
  end
  def websocket_info({:slide_new, x, piece}, state) do
    check_throttle(state.board)
    msg = %{"type" => "slide_new",
            "id" => "row1-col#{x}",
            "piece" => img_src(piece)}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:slide, x, y_orig, y_dest}, state) do
    check_throttle(state.board)
    msg = %{"type" => "slide",
            "orig" => "row#{y_orig}-col#{x}",
            "dest" => "row#{y_dest}-col#{x}"}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:new_kind, x, y, new_kind}, state) do
    check_throttle(state.board)
    msg = %{"type" => "new_kind",
            "id" => "row#{y}-col#{x}",
            "piece" => img_src(new_kind)}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info(:extra_turn, state) do
    check_throttle(state.board)
    turns = Board.turns(state.board)
    msg = %{"type" => "extra_turn",
            "extra_turn" => "extra_turn",
            "turns" => turns}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:match, score, global_score, acc, cells}, state) do
    check_throttle(state.board)
    acc = for {_, points} <- acc do
      for {x, y} <- points do
        "row#{y}-col#{x}"
      end
    end
    |> List.flatten()
    msg = %{"type" => "match",
            "add_score" => score,
            "score" => global_score,
            "points" => acc,
            "html" => build_show(cells)}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:show, cells}, state) do
    check_throttle(state.board)
    html = build_show(cells)
    msg = %{"type" => "draw", "html" => html}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:gameover, score, has_username}, state) do
    check_throttle(state.board)
    msg = %{"type" => "gameover",
            "score" => score,
            "turns" => 0,
            "has_username" => has_username}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:error, :gameover}, state) do
    score = Board.score(state.board)
    msg = %{"type" => "gameover",
            "score" => score,
            "turns" => 0,
            "has_username" => true}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:error, {:illegal_move, {x1, y1}, {x2, y2}}}, state) do
    msg = %{"type" => "illegal_move",
            "points" => ["row#{y1}-col#{x1}", "row#{y2}-col#{x2}"]}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:hiscore, {:ok, order}}, state) do
    send_hiscore(order, state)
  end
  def websocket_info(info, state) do
    Logger.info "info => #{inspect info}"
    {:ok, state}
  end

  def websocket_terminate(reason, _state) do
    Logger.info "reason => #{inspect reason}"
    :ok
  end

  defp send_hiscore(order \\ nil, state) do
    msg = %{"type" => "hiscore",
            "top_list" => build_top_list(),
            "position" => order}
    {:reply, {:text, Jason.encode!(msg)}, state}
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
      send self(), {:send, Jason.encode!(%{"type" => "bot_id", "id" => id})}
      {:reply, {:text, Jason.encode!(msg)}, Map.put(state, :bot_id, id)}
    end
  end
  defp process_data(%{"type" => "hiscore"}, state) do
    send_hiscore(state)
  end
  defp process_data(%{"type" => "set-hiscore-name", "name" => username}, state) do
    Board.hiscore(state.board, username, state.remote_ip)
    {:ok, state}
  end
  defp process_data(%{"type" => "create"}, state) do
    id = UUID.uuid4()
    {:ok, _board} = Board.start_link(id)
    msg = %{"type" => "id", "id" => id}
    {:reply, {:text, Jason.encode!(msg)}, Map.put(state, :board, id)}
  end
  defp process_data(%{"type" => "join", "id" => id} = info, state) do
    if Board.exists?(id) do
      state = Map.put(state, :board, id)
      if Board.turns(id) > 0 do
        Board.add_consumer(id)
        if info["bot_id"] != nil do
          Bot.join(info["bot_id"])
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
  defp process_data(%{"type" => "move", "x1" => x1, "y1" => y1, "x2" => x2,
                      "y2" => y2},
                    state) do
    if Board.exists?(state.board) do
      point1 = {x1, y1}
      point2 = {x2, y2}
      Board.move(state.board, point1, point2)
      {:ok, state}
    else
      msg = %{"type" => "gameover", "turns" => 0, "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}  
    end
  end

  defp process_data(%{"type" => "show"}, state) do
    if Board.exists?(state.board) and Board.turns(state.board) > 0 do
      msg = %{"type" => "draw", "html" => build_show(state.board)}
      {:reply, {:text, Jason.encode!(msg)}, state}
    else
      msg = %{"type" => "gameover", "turns" => 0, "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}  
    end
  end

  defp process_data(%{"type" => "restart"}, %{board: board} = state) do
    if Board.exists?(board), do: Board.stop(board)
    {:ok, _} = Board.start_link(board)
    turns = Board.turns(board)
    score = Board.score(board)
    msg = %{"type" => "draw",
            "html" => build_show(board),
            "score" => score,
            "turns" => turns}
    send self(), {:send, Jason.encode!(%{"type" => "play"})}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "stop"}, %{board: board} = state) do
    if Board.exists?(board), do: Board.stop(board)
    {:ok, state}
  end

  defp build_top_list do
    """
    <table class="table table-stripped table-sm" id="toplist">
    <thead>
      <tr>
        <th>#</th>
        <th>Name</th>
        <th class="text-right">Turns</th>
        <th class="text-right">Score</th>
      </tr>
    </thead>
    <tbody>
      <tr>
    """
    |> add(HiScore.top_list()
           |> Enum.with_index(1)
           |> Enum.map(&to_top_entry/1)
           |> Enum.join("</tr><tr>"))
    |> add("</tr></tbody></table>")
  end

  defp to_top_entry({entry, position}) do
    """
    <th scope="row">#{position}</td>
    <td>#{entry.name}</td>
    <td class="text-right">#{entry.turns}</td>
    <td class="text-right">#{entry.score}</td>
    """
  end

  defp build_show(cells) when is_list(cells) do
    "<table id='board'><tr>"
    |> add(cells
           |> Enum.with_index(1)
           |> Enum.map(&to_img/1)
           |> Enum.join("</tr><tr>"))
    |> add("</tr></table>")
  end
  defp build_show(board), do: build_show(Board.show(board))

  defp add(str1, str2), do: str1 <> str2

  defp img_src(piece), do: "img/cell_#{piece}.png"

  defp img(x, y, piece) do
    "<td><img src='#{img_src piece}' id='row#{y}-col#{x}' class='cell'></td>"
  end

  defp to_img({col, y}) do
    col
    |> Enum.with_index(1)
    |> Enum.map(fn {src, x} -> img(x, y, src) end)
    |> Enum.join()
  end
end
