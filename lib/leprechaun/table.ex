defmodule Leprechaun.Table do
  @moduledoc """
  The table have different pieces inside. It cannot be empty. When we choose
  move one piece to achieve 3 or more connected similar symbols 
  """

  use GenServer
  alias Leprechaun.Table
  require Logger

  @table_x 8
  @table_y 8

  @max_tries 1000

  @init_symbols_prob [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                      2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
                      3, 3, 3, 3, 3, 3, 3, 3, 3,
                      4, 4, 4, 4, 4, 4,
                      5]

  defstruct cells: [],
            score: 0

  def start_link(name \\ __MODULE__) do
    GenServer.start_link __MODULE__, [], name: name
  end

  def stop(name \\ __MODULE__), do: GenServer.stop(name)

  def show(name \\ __MODULE__), do: GenServer.call(name, :show)

  def move(name \\ __MODULE__, point_from, point_to) do
    GenServer.cast name, {:move, self(), point_from, point_to}
  end

  def score(name \\ __MODULE__), do: GenServer.call(name, :score)

  def init([]) do
    cells = for y <- 1..@table_y, into: %{} do
      {y, for(x <- 1..@table_x, into: %{}, do: {x, gen_symbol()})}
    end
    {:ok, %Table{cells: gen_clean(cells)}}
  end

  def handle_call(:show, _from, %Table{cells: cells} = table) do
    {:reply, build_show(cells), table}
  end

  def handle_call(:score, _from, table) do
    {:reply, table.score, table}
  end

  def handle_cast({:move, from, {x1, y}, {x2, y}}, table) when abs(x1 - x2) == 1 do
    move(from, {x1, y}, {x2, y}, table)
  end
  def handle_cast({:move, from, {x, y1}, {x, y2}}, table) when abs(y1 - y2) == 1 do
    move(from, {x, y1}, {x, y2}, table)
  end
  def handle_cast({:move, from, point1, point2}, table) do
    send(from, {:error, {:illegal_move, point1, point2}})
    {:noreply, table}
  end

  def move(from, {x1, y1}, {x2, y2}, %Table{cells: cells} = table) do
    e1 = cells[y1][x1]
    e2 = cells[y2][x2]

    {cells, acc} = cells
                   |> put_in([y1, x1], e2)
                   |> put_in([y2, x2], e1)
                   |> check()
    moves = [{x1, y1}, {x2, y2}]
    if acc != [] do
      {cells, score} = check_and_clean(cells, from, acc, table.score, moves)
      {:noreply, %Table{cells: cells, score: score}}
    else
      send(from, {:error, {:illegal_move, {x1,y1}, {x2,y2}}})
      {:noreply, table}
    end
  end

  defp build_show(cells) do
    for y <- 1..8 do
      for x <- 1..8 do
        cells[y][x]
      end
    end
  end

  defp add_moves(acc, moves) do
    Enum.reduce(acc, moves, fn {_, [point|_] = points}, acc_moves ->
      if (points -- (points -- moves)) != [] do
        acc_moves
      else
        [point|acc_moves]
      end
    end)
  end

  defp check_and_clean(cells, _from, [], score, _moves), do: {cells, score}
  defp check_and_clean(cells, from, acc, score, moves) do
    new_score = for({_dir, points} <- acc, do: points)
                |> List.flatten()
                |> Enum.map(fn {x, y} -> cells[y][x] end)
                |> Enum.sum()
    send(from, {:match, new_score, acc, build_show(cells)})
    moves = add_moves(acc, moves)
    Logger.debug "[check_and_clean] moves => #{inspect moves}"
    {cells, acc} = cells
                   |> clean(acc, moves)
                   |> check()
    send(from, {:show, build_show(cells)})
    check_and_clean(cells, from, acc, score + new_score, [])
  end

  defp check(cells, n, acc, x, y, inc_x, inc_y) do
    if cells[y][x] == n do
      new_x = inc_x + x
      new_y = inc_y + y
      if new_x >= 1 and new_x <= @table_x and new_y >= 1 and new_y <= @table_y do
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

  defp incr_kind(6), do: 6
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
  defp check(cells, acc, x, y) when x > @table_x, do: check(cells, acc, 1, y + 1)
  defp check(cells, acc, _x, y) when y > @table_y do
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
