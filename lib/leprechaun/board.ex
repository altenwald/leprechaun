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
            username: nil

  def start_link(name) do
    GenServer.start_link __MODULE__, [], name: via(name)
  end

  defp via(board) do
    {:via, Registry, {Leprechaun.Registry, board}}
  end

  def exists?(board) do
    case Registry.lookup(Leprechaun.Registry, board) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  def stop(name), do: GenServer.stop(via(name))

  def show(name), do: GenServer.call(via(name), :show)

  def move(name, point_from, point_to) do
    GenServer.cast via(name), {:move, self(), point_from, point_to}
  end
  
  def hiscore(name, username, remote_ip) do
    GenServer.cast via(name), {:hiscore, self(), username, remote_ip}
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
  def handle_call(:stats, _form, board) do
    stats = %{"played_turns" => board.played_turns,
              "extra_turns" => board.extra_turns}
    {:reply, stats, board}
  end

  def handle_cast({:move, from, _point1, _point2}, %Board{turns: 0} = board) do
    send(from, {:error, :gameover})
    {:noreply, board}
  end
  def handle_cast({:move, from, {x1, y}, {x2, y}}, board) when abs(x1 - x2) == 1 do
    move(from, {x1, y}, {x2, y}, board)
  end
  def handle_cast({:move, from, {x, y1}, {x, y2}}, board) when abs(y1 - y2) == 1 do
    move(from, {x, y1}, {x, y2}, board)
  end
  def handle_cast({:move, from, point1, point2}, board) do
    send(from, {:error, {:illegal_move, point1, point2}})
    {:noreply, board}
  end
  def handle_cast({:hiscore, from, username, remote_ip}, %Board{turns: 0, username: nil} = board) do
    {:ok, hiscore} = HiScore.save(username, board.score, board.played_turns, board.extra_turns, remote_ip)
    send(from, {:hiscore, HiScore.get_order(hiscore.id)})
    {:noreply, %Board{board | username: username}}
  end
  def handle_cast(info, board) do
    Logger.warn "[board] info discarded => #{inspect info}"
    {:noreply, board}
  end

  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  def move(from, {x1, y1}, {x2, y2}, %Board{cells: cells} = board) do
    e1 = cells[y1][x1]
    e2 = cells[y2][x2]

    {cells, acc} = cells
                   |> put_in([y1, x1], e2)
                   |> put_in([y2, x2], e1)
                   |> check()
    moves = [{x1, y1}, {x2, y2}]
    if acc != [] do
      {cells, score, extra_turn} = check_and_clean(cells, from, acc, board.score, :decr_turn, moves)
      {turns, extra_turns} = update_turns(board.turns, board.extra_turns, extra_turn)
      if turns == 0, do: send(from, {:gameover, score})
      {:noreply, %Board{cells: cells,
                        score: score,
                        extra_turns: extra_turns,
                        played_turns: board.played_turns + 1,
                        turns: turns}}
    else
      send(from, {:error, {:illegal_move, {x1,y1}, {x2,y2}}})
      {:noreply, board}
    end
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

  defp check_extra_turns(:extra_turn, _), do: :extra_turn
  defp check_extra_turns(:no_action, acc) do
    sizes = for {_, p} <- acc, length(p) > 4 do
      length(p)
    end
    if sizes != [] do
      :extra_turn
    else
      :no_action
    end
  end
  defp check_extra_turns(:decr_turn, acc) do
    max = for {_, p} <- acc, length(p) > 3 do
            length(p)
          end
          |> Enum.max(fn -> 0 end)
    case max do
      0 -> :decr_turn
      4 -> :no_action
      n when is_integer(n) and n > 4 -> :extra_turn
    end
  end

  defp check_and_clean(cells, from, [], score, extra_turns, _moves) do
    send(from, :play)
    {cells, score, extra_turns}
  end
  defp check_and_clean(cells, from, acc, score, extra_turns, moves) do
    new_score = for({_dir, points} <- acc, do: points)
                |> List.flatten()
                |> Enum.map(fn {x, y} -> cells[y][x] end)
                |> Enum.sum()
    extra_turns = check_extra_turns(extra_turns, acc)
    send(from, {:match, new_score, extra_turns, acc, build_show(cells)})
    moves = add_moves(acc, moves)
    Logger.debug "[check_and_clean] moves => #{inspect moves}"
    {cells, acc} = cells
                   |> clean(acc, moves)
                   |> check()
    send(from, {:show, build_show(cells)})
    check_and_clean(cells, from, acc, score + new_score, extra_turns, [])
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

  defp clean({cells, acc}), do: clean(cells, acc)
  defp clean(cells, acc, moves \\ []) do
    points = for({_, elems} <- acc, do: elems)
             |> List.flatten()

    move_points = moves -- (moves -- points)
    cells = move_points
            |> Enum.reduce(cells, fn {x, y}, cells ->
                                    new_kind = incr_kind(cells[y][x])
                                    Logger.debug "[clean] add #{new_kind} to (#{x},#{y})"
                                    put_in cells[y][x], new_kind
                                  end)
    
    (points -- move_points)
    |> Enum.filter(fn elem -> elem not in moves end)
    |> Enum.sort_by(fn {x, y} -> {y, x} end)
    |> Enum.reduce(cells, fn {x, y}, cells -> slide(cells, x, y) end)
  end

  defp slide(cells, x, 1) do
    put_in cells[1][x], gen_symbol()
  end
  defp slide(cells, x, y) do
    put_in(cells[y][x], cells[y-1][x])
    |> slide(x, y - 1)
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
