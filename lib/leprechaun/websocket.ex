defmodule Leprechaun.Websocket do
  require Logger
  alias Leprechaun.Board

  @throttle_time_to_wait 100
  @tries 100

  defp check_throttle(tries \\ @tries)
  defp check_throttle(0) do
    Logger.error "[websocket] overloaded!"
    {:error, :overload}
  end
  defp check_throttle(tries) do
    case :throttle.check(:websocket, :global) do
      {:ok, _, _} ->
        :ok
      {:limit_exceeded, _, _} ->
        Process.sleep @throttle_time_to_wait
        check_throttle(tries - 1)
    end
  end

  def init(req, opts) do
    {:cowboy_websocket, req, opts}
  end

  def websocket_init(_opts) do
    {:ok, %{board: nil}}
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
    {:reply, {:text, data}, state}
  end
  def websocket_info({:timeout, _ref, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info(:play, state) do
    {:reply, {:text, Jason.encode!(%{"type" => "play"})}, state}
  end
  def websocket_info({:match, score, extra, acc, cells}, state) do
    check_throttle()
    acc = for {_, points} <- acc do
      for {x, y} <- points do
        "row#{y}-col#{x}"
      end
    end
    |> List.flatten()
    extra = to_string(extra)
    turns = Board.turns(state.board)
    global_score = Board.score(state.board)
    msg = %{"type" => "match",
            "add_score" => score,
            "score" => global_score,
            "extra_turn" => extra,
            "points" => acc,
            "turns" => turns,
            "html" => build_show(cells)}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:show, cells}, state) do
    check_throttle()
    html = build_show(cells)
    msg = %{"type" => "draw", "html" => html}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:gameover, score}, state) do
    check_throttle()
    msg = %{"type" => "gameover", "score" => score, "turns" => 0}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:error, :gameover}, state) do
    score = Board.score(state.board)
    msg = %{"type" => "gameover", "score" => score, "turns" => 0}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info({:error, {:illegal_move, {x1, y1}, {x2, y2}}}, state) do
    msg = %{"type" => "illegal_move",
            "points" => ["row#{y1}-col#{x1}", "row#{y2}-col#{x2}"]}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  def websocket_info(info, state) do
    Logger.info "info => #{inspect info}"
    {:ok, state}
  end

  def websocket_terminate(reason, _state) do
    Logger.info "reason => #{inspect reason}"
    :ok
  end

  defp process_data(%{"type" => "create"}, state) do
    id = UUID.uuid4()
    {:ok, _board} = Board.start_link(id)
    msg = %{"type" => "id", "id" => id}
    {:reply, {:text, Jason.encode!(msg)}, Map.put(state, :board, id)}
  end
  defp process_data(%{"type" => "join", "id" => id}, state) do
    if Board.exists?(id) do
      state = Map.put(state, :board, id)
      if Board.turns(id) > 0 do
        {:ok, state}
      else
        msg = %{"type" => "gameover", "turns" => 0}
        {:reply, {:text, Jason.encode!(msg)}, state}
      end
    else
      msg = %{"type" => "gameover", "turns" => 0}
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
      msg = %{"type" => "gameover", "turns" => 0}
      {:reply, {:text, Jason.encode!(msg)}, state}  
    end
  end

  defp process_data(%{"type" => "show"}, state) do
    if Board.exists?(state.board) and Board.turns(state.board) > 0 do
      msg = %{"type" => "draw", "html" => build_show(state.board)}
      {:reply, {:text, Jason.encode!(msg)}, state}
    else
      msg = %{"type" => "gameover", "turns" => 0}
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

  defp build_show(cells) when is_list(cells) do
    "<table id='board'><tr>"
    |> add("</tr><tr>")
    |> add(cells
           |> Enum.with_index(1)
           |> Enum.map(&to_img/1)
           |> Enum.join("</tr><tr>"))
    |> add("</tr><tr>")
    |> add("</tr></table>")
  end
  defp build_show(board), do: build_show(Board.show(board))

  defp add(str1, str2), do: str1 <> str2

  defp img(x, y, src) do
    "<td><img src='img/cell_#{src}.png' id='row#{y}-col#{x}' class='cell'></td>"
  end

  defp to_img({col, y}) do
    col
    |> Enum.with_index(1)
    |> Enum.map(fn {src, x} -> img(x, y, src) end)
    |> Enum.join()
  end
end
