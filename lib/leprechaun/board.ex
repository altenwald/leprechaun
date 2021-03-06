defmodule Leprechaun.Board do
  @moduledoc """
  The board have different pieces inside. It cannot be empty. When we choose
  move one piece to achieve 3 or more connected similar symbols 
  """

  use GenServer
  alias Leprechaun.{Board, HiScore}
  require Logger

  @board_x 8
  @board_y 8

  @max_tries 1000
  @max_hours_running 2

  @init_turns 10
  @init_symbols_prob [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                      2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
                      3, 3, 3, 3, 3, 3, 3, 3, 3,
                      4, 4, 4, 4, 4, 4,
                      5]

  defstruct cells: [],
            score: 0,
            turns: @init_turns,
            played_turns: 0,
            extra_turns: 0,
            username: nil,
            consumers: []

  def start_link(name) do
    {:ok, board} = GenServer.start_link __MODULE__, [], name: via(name)
    :ok = add_consumer(name)
    {:ok, board}
  end

  defp via(board) do
    {:via, Registry, {Leprechaun.Board.Registry, board}}
  end

  def exists?(board) do
    case Registry.lookup(Leprechaun.Board.Registry, board) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  def stop(name), do: GenServer.stop(via(name))

  def show(name), do: GenServer.call(via(name), :show)

  def move(name, point_from, point_to) do
    GenServer.cast via(name), {:move, point_from, point_to}
  end

  def check_move(name, point_from, point_to) do
    GenServer.call via(name), {:check_move, point_from, point_to}
  end

  def hiscore(name, username, remote_ip) do
    GenServer.cast via(name), {:hiscore, username, remote_ip}
  end

  def add_consumer(name) do
    GenServer.cast via(name), {:consumer, self()}
  end

  def score(name), do: GenServer.call(via(name), :score)

  def turns(name), do: GenServer.call(via(name), :turns)

  def stats(name), do: GenServer.call(via(name), :stats)

  def init([]) do
    cells = for y <- 1..@board_y, into: %{} do
      {y, for(x <- 1..@board_x, into: %{}, do: {x, gen_symbol()})}
    end
    Process.send_after self(), :stop, :timer.hours(@max_hours_running)
    Logger.info "[board] started #{inspect self()}"
    {:ok, %Board{cells: gen_clean(cells)}}
  end

  def handle_call(:show, _from, %Board{cells: cells} = board) do
    {:reply, build_show(cells), board}
  end
  def handle_call(:score, _from, board) do
    {:reply, board.score, board}
  end
  def handle_call(:turns, _from, board) do
    {:reply, board.turns, board}
  end
  def handle_call(:stats, _from, board) do
    stats = %{"played_turns" => board.played_turns,
              "extra_turns" => board.extra_turns}
    {:reply, stats, board}
  end
  def handle_call({:check_move, _point1, _point2}, _from, %Board{turns: 0} = board) do
    {:reply, {false, []}, board}
  end
  def handle_call({:check_move, {x1, y}, {x2, y}}, _from, board) when abs(x1 - x2) == 1 do
    check_swap({x1, y}, {x2, y}, board)
  end
  def handle_call({:check_move, {x, y1}, {x, y2}}, _from, board) when abs(y1 - y2) == 1 do
    check_swap({x, y1}, {x, y2}, board)
  end
  def handle_call({:check_move, _point1, _point2}, _from, board) do
    {:reply, {false, []}, board}
  end

  def handle_cast({:move, _point1, _point2}, %Board{turns: 0} = board) do
    send_to(board.consumers, {:error, :gameover})
    {:noreply, board}
  end
  def handle_cast({:move, {x1, y}, {x2, y}}, board) when abs(x1 - x2) == 1 do
    swap({x1, y}, {x2, y}, board)
  end
  def handle_cast({:move, {x, y1}, {x, y2}}, board) when abs(y1 - y2) == 1 do
    swap({x, y1}, {x, y2}, board)
  end
  def handle_cast({:move, point1, point2}, board) do
    send_to(board.consumers, {:error, {:illegal_move, point1, point2}})
    {:noreply, board}
  end
  def handle_cast({:hiscore, username, remote_ip}, %Board{turns: 0, username: nil} = board) do
    {:ok, hiscore} = HiScore.save(username, board.score, board.played_turns, board.extra_turns, remote_ip)
    send_to(board.consumers, {:hiscore, HiScore.get_order(hiscore.id)})
    {:noreply, %Board{board | username: username}}
  end
  def handle_cast({:consumer, from}, board) do
    Process.monitor(from)
    {:noreply, %Board{board | consumers: [from|board.consumers]}}
  end
  def handle_cast(info, board) do
    Logger.warn "[board] info discarded => #{inspect info}"
    {:noreply, board}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %Board{consumers: consumers} = board) do
    {:noreply, %Board{board | consumers: consumers -- [pid]}}
  end
  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  defp send_to(consumers, message) do
    for consumer <- consumers, do: send(consumer, message)
  end

  defp swap({x1, y1}, {x2, y2}, %Board{cells: cells,
                                       consumers: consumers,
                                       score: score,
                                       turns: turns,
                                       extra_turns: extra_turns} = board) do
    e1 = cells[y1][x1]
    e2 = cells[y2][x2]

    {cells, acc} = cells
                   |> put_in([y1, x1], e2)
                   |> put_in([y2, x2], e1)
                   |> check()
    moves = [{x1, y1}, {x2, y2}]
    if acc != [] do
      {cells, score, extra_turn} = check_and_clean(cells, consumers, acc, score, turns, :decr_turn, moves)
      {turns, extra_turns} = update_turns(turns, extra_turns, extra_turn)
      if turns == 0, do: send_to(consumers, {:gameover, score, board.username != nil})
      {:noreply, %Board{board | cells: cells,
                                score: score,
                                extra_turns: extra_turns,
                                played_turns: board.played_turns + 1,
                                turns: turns}}
    else
      send_to(consumers, {:error, {:illegal_move, {x1,y1}, {x2,y2}}})
      {:noreply, board}
    end
  end

  defp check_swap({x1, y1}, {x2, y2}, %Board{cells: cells} = board)
    when x1 >= 1 and x1 <= 8 and y1 >= 1 and y1 <= 8 and
         x2 >= 1 and x2 <= 8 and y2 >= 1 and y2 <= 8 do
    e1 = cells[y1][x1]
    e2 = cells[y2][x2]

    {_cells, acc} = cells
                   |> put_in([y1, x1], e2)
                   |> put_in([y2, x2], e1)
                   |> check()
    {:reply, {acc != [], acc}, board}
  end

  defp update_turns(turns, extra, :no_action), do: {turns, extra}
  defp update_turns(turns, extra, :decr_turn), do: {turns - 1, extra}
  defp update_turns(turns, extra, :extra_turn), do: {turns + 1, extra + 1}

  defp build_show(cells) do
    for y <- 1..8 do
      for x <- 1..8 do
        cells[y][x]
      end
    end
  end

  defp add_moves(acc, moves) do
    Enum.reduce(acc, moves, fn {_, points}, acc_moves ->
      if (points -- (points -- moves)) != [] do
        acc_moves
      else
        point = points
                |> Enum.sort_by(fn({x, y}) -> {y, x} end)
                |> List.first()
        [point|acc_moves]
      end
    end)
  end

  defp check_extra_turns(_consumers, :extra_turn, _), do: :extra_turn
  defp check_extra_turns(consumers, :no_action, acc) do
    sizes = for {_, p} <- acc, length(p) > 4 do
      length(p)
    end
    if sizes != [] do
      send_to(consumers, :extra_turn)
      :extra_turn
    else
      :no_action
    end
  end
  defp check_extra_turns(consumers, :decr_turn, acc) do
    max = for {_, p} <- acc, length(p) > 3 do
            length(p)
          end
          |> Enum.max(fn -> 0 end)
    case max do
      0 ->
        :decr_turn
      4 ->
        :no_action
      n when is_integer(n) and n > 4 ->
        send_to(consumers, :extra_turn)
        :extra_turn
    end
  end

  defp check_and_clean(cells, consumers, [], score, _turns, extra_turns, _moves) do
    send_to consumers, :play
    {cells, score, extra_turns}
  end
  defp check_and_clean(cells, consumers, acc, score, turns, extra_turns, moves) do
    new_score = for({_dir, points} <- acc, do: points)
                |> List.flatten()
                |> Enum.map(fn {x, y} -> cells[y][x] end)
                |> Enum.sum()
    extra_turns = check_extra_turns(consumers, extra_turns, acc)
    total_score = new_score + score
    send_to consumers, {:match, new_score, total_score, acc, build_show(cells)}
    moves = add_moves(acc, moves)
    Logger.debug "[check_and_clean] moves => #{inspect moves}"
    {cells, acc} = cells
                   |> clean(consumers, acc, moves)
                   |> check()
    send_to consumers, {:show, build_show(cells)}
    check_and_clean(cells, consumers, acc, total_score, turns, extra_turns, [])
  end

  defp check(cells, n, acc, x, y, inc_x, inc_y) do
    if cells[y][x] == n do
      new_x = inc_x + x
      new_y = inc_y + y
      if new_x >= 1 and new_x <= @board_x and new_y >= 1 and new_y <= @board_y do
        Logger.debug "[check] (#{x},#{y}) + (#{inc_x},#{inc_y}) -- #{n} #{inspect acc}"
        check(cells, n, [{x,y}|acc], new_x, new_y, inc_x, inc_y)
      else
        Logger.debug "[check] (#{x},#{y}) + (#{inc_x},#{inc_y}) -- #{n} #{inspect acc} limit reached"
        [{x,y}|acc]
      end
    else
      Logger.debug "[check] (#{x},#{y}) + (#{inc_x},#{inc_y}) -- #{cells[y][x]} != #{n} #{inspect acc}"
      acc
    end
  end

  defp gen_clean(cells, tries \\ @max_tries)
  defp gen_clean(_cells, 0), do: throw(:badluck)
  defp gen_clean(cells, tries) do
    {cells, acc} = cells
                   |> check()
                   |> clean()
                   |> check()
    if acc != [] do
      Logger.debug "[gen_clean] not clean, cleaning again, try #{tries}"
      gen_clean(cells, tries - 1)
    else
      Logger.debug "[gen_clean] achieved! in try #{tries}"
      cells
    end
  end

  defp incr_kind(8), do: 8
  defp incr_kind(i), do: i + 1

  defp clean({cells, acc}), do: clean(cells, [], acc)
  defp clean(cells, consumers, acc, moves \\ []) do
    points = for({_, elems} <- acc, do: elems)
             |> List.flatten()

    move_points = moves -- (moves -- points)
    cells = move_points
            |> Enum.reduce(cells, fn {x, y}, cells ->
                                    new_kind = incr_kind(cells[y][x])
                                    Logger.debug "[clean] add #{new_kind} to (#{x},#{y})"
                                    send_to consumers, {:new_kind, x, y, new_kind}
                                    put_in cells[y][x], new_kind
                                  end)

    (points -- move_points)
    |> Enum.filter(fn elem -> elem not in moves end)
    |> Enum.sort_by(fn {x, y} -> {y, x} end)
    |> Enum.reduce(cells, fn {x, y}, cells -> slide(cells, consumers, x, y) end)
  end

  defp slide(cells, consumers, x, 1) do
    new_piece = gen_symbol()
    send_to consumers, {:slide_new, x, new_piece}
    put_in cells[1][x], new_piece
  end
  defp slide(cells, consumers, x, y) do
    send_to consumers, {:slide, x, y - 1, y}
    put_in(cells[y][x], cells[y - 1][x])
    |> slide(consumers, x, y - 1)
  end

  defp check(cells, acc \\ [], x \\ 1, y \\ 1)
  defp check(cells, acc, x, y) when x > @board_x, do: check(cells, acc, 1, y + 1)
  defp check(cells, acc, _x, y) when y > @board_y do
    acc = acc
          |> Enum.filter(fn {_, elems} -> length(elems) >= 3 end)
          |> Enum.sort_by(fn {dir, elems} -> {dir, length(elems)} end, &>=/2)
          |> Enum.reduce([], &remove_dups/2)
          |> Enum.reduce([], &find_mixed/2)
    {cells, acc}
  end
  defp check(cells, acc, x, y) do
    n = cells[y][x]
    checks = [
      {:horizontal, check(cells, n, [], x, y, 1, 0)},
      {:vertical, check(cells, n, [], x, y, 0, 1)}
    ]
    check(cells, acc ++ checks, x + 1, y)
  end

  defp remove_dups({dir, elems} = entry, entries) do
    Logger.debug "[remove_dups] #{inspect entry} in #{inspect entries}"
    if Enum.any?(entries, fn {d, elems0} -> d == dir and (elems -- elems0) == [] end) do
      entries
    else
      [entry|entries]
    end
  end

  defp find_mixed({_dir, elems} = entry, entries) do
    mixed = Enum.filter(entries, fn {_, elems0} -> (elems -- (elems -- elems0)) != [] end)
    if mixed != [] do
      entries = entries -- mixed
      elems = for({_, e} <- [entry|mixed], do: e)
              |> List.flatten()
              |> Enum.uniq()
      [{:mixed, elems}|entries]
    else
      [entry|entries]
    end
  end

  defp gen_symbol, do: Enum.random(@init_symbols_prob)
end
