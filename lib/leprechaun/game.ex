defmodule Leprechaun.Game do
  @moduledoc """
  Leprechaun Game is controlling the progression of the game and the
  interface between all of the elements.

  The board have different pieces inside. It cannot be empty. When we choose
  move one piece to achieve 3 or more connected similar symbols it needed
  to include new pieces going from top and filling down the gaps.

  The board is a 8x8 matrix where we are placing numbers from 1 until 8.
  If we can find 3 or more adjacent pieces in a row we are consider that
  a match and get points based on the numbers.

  A small example with a 4x4 matrix:

  ```
  [
    [ 1, 1, 1, 2 ],
    [ 1, 2, 3, 3 ],
    [ 1, 2, 3, 4 ],
    [ 2, 3, 4, 5 ]
  ]
  ```

  You can see that we have one match of 1s which is conformed by 5 pieces,
  this is because we have an horizontal adjacent line of 3 pieces and
  connected to that another adjacent line of 3 pieces (in a L form). That's
  meaning we have a match of 5 elements. That's going to be removed:

  ```
  [
    [ 0, 0, 0, 2 ],
    [ 0, 2, 3, 3 ],
    [ 0, 2, 3, 4 ],
    [ 2, 3, 4, 5 ]
  ]
  ```

  And then, there are 3 pieces which are going to be included in the first
  column, 1 piece more for the second column and 1 piece more for the third
  column.
  """
  use GenServer
  alias Leprechaun.{Game, HiScore}
  require Logger

  @board_x 8
  @board_y 8

  @max_tries 1000
  @max_hours_running 2

  @init_turns 10
  @init_symbols_prob List.duplicate(1, 15) ++
                       List.duplicate(2, 12) ++
                       List.duplicate(3, 9) ++
                       List.duplicate(4, 6) ++
                       List.duplicate(5, 1)

  defstruct cells: [],
            score: 0,
            turns: @init_turns,
            played_turns: 0,
            extra_turns: 0,
            username: nil,
            consumers: []

  @type game_name() :: String.t() | atom()
  @type cells() :: [[0..8]]
  @type x_pos() :: 1..8
  @type y_pos() :: 1..8
  @type point() :: {x_pos(), y_pos()}
  @type match() :: boolean()
  @type moves() :: [{:horizontal | :vertical, [point()]}]
  @type username() :: String.t()
  @type remote_ip() :: String.t()
  @type score() :: non_neg_integer()
  @type turns() :: non_neg_integer()
  @type stats() :: %{ String.t() => non_neg_integer() }

  @spec start_link(game_name()) :: {:ok, pid}
  def start_link(name) do
    {:ok, board} = GenServer.start_link(__MODULE__, [], name: via(name))
    :ok = add_consumer(name)
    {:ok, board}
  end

  defp via(board) do
    {:via, Registry, {Leprechaun.Game.Registry, board}}
  end

  @spec exists?(game_name()) :: boolean()
  def exists?(board) do
    Registry.lookup(Leprechaun.Game.Registry, board) != []
  end

  @spec stop(game_name()) :: :ok
  def stop(name), do: GenServer.stop(via(name))

  @spec show(game_name()) :: cells()
  def show(name), do: GenServer.call(via(name), :show)

  @spec move(game_name(), from :: point(), to :: point()) :: :ok
  def move(name, point_from, point_to) do
    GenServer.cast(via(name), {:move, point_from, point_to})
  end

  @spec check_move(game_name(), from :: point(), to :: point()) :: {match(), moves()}
  def check_move(name, point_from, point_to) do
    GenServer.call(via(name), {:check_move, point_from, point_to})
  end

  @spec hiscore(game_name(), username(), remote_ip()) :: :ok | {:error, term()}
  def hiscore(name, username, remote_ip) do
    GenServer.call(via(name), {:hiscore, username, remote_ip})
  end

  @spec add_consumer(game_name()) :: :ok
  def add_consumer(name) do
    GenServer.cast(via(name), {:consumer, self()})
  end

  @spec score(game_name()) :: score()
  def score(name), do: GenServer.call(via(name), :score)

  @spec turns(game_name()) :: turns()
  def turns(name), do: GenServer.call(via(name), :turns)

  @spec stats(game_name()) :: stats()
  def stats(name), do: GenServer.call(via(name), :stats)

  @impl GenServer
  def init([]) do
    cells =
      for y <- 1..@board_y, into: %{} do
        {y, for(x <- 1..@board_x, into: %{}, do: {x, new_piece()})}
      end

    Process.send_after(self(), :stop, :timer.hours(@max_hours_running))
    Logger.info("[board] started #{inspect(self())}")
    {:ok, %Game{cells: gen_clean(cells)}}
  end

  @impl GenServer
  def handle_call(:show, _from, %Game{cells: cells} = board) do
    {:reply, build_show(cells), board}
  end

  def handle_call(:score, _from, board) do
    {:reply, board.score, board}
  end

  def handle_call(:turns, _from, board) do
    {:reply, board.turns, board}
  end

  def handle_call(:stats, _from, board) do
    stats = %{"played_turns" => board.played_turns, "extra_turns" => board.extra_turns}
    {:reply, stats, board}
  end

  def handle_call({:check_move, _point1, _point2}, _from, %Game{turns: 0} = board) do
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

  def handle_call({:hiscore, username, remote_ip}, _from, %Game{turns: 0, username: nil} = board) do
    case HiScore.save(username, board.score, board.played_turns, board.extra_turns, remote_ip) do
      {:ok, hiscore} ->
        send_to(board.consumers, {:hiscore, HiScore.get_order(hiscore.id)})
        {:reply, :ok, %Game{board | username: username}}

      {:error, changeset} ->
        {:reply, {:error, changeset.errors}, board}
    end
  end

  def handle_call({:hiscore, _username, _remote_ip}, _from, %Game{username: nil} = board) do
    {:reply, {:error, :still_playing}, board}
  end

  def handle_call({:hiscore, _username, _remote_ip}, _from, board) do
    {:reply, {:error, :already_set}, board}
  end

  @impl GenServer
  def handle_cast({:move, _point1, _point2}, %Game{turns: 0} = board) do
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

  def handle_cast({:consumer, from}, board) do
    Process.monitor(from)
    {:noreply, %Game{board | consumers: [from | board.consumers]}}
  end

  def handle_cast(info, board) do
    Logger.warn("[board] info discarded => #{inspect(info)}")
    {:noreply, board}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %Game{consumers: consumers} = board) do
    {:noreply, %Game{board | consumers: consumers -- [pid]}}
  end

  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  defp send_to(consumers, message) do
    for consumer <- consumers, do: send(consumer, message)
    message
  end

  defp swap(
         {x1, y1},
         {x2, y2},
         %Game{
           cells: cells,
           consumers: consumers,
           score: score,
           turns: turns,
           extra_turns: extra_turns
         } = board
       ) do
    e1 = cells[y1][x1]
    e2 = cells[y2][x2]

    {cells, acc} =
      cells
      |> put_in([y1, x1], e2)
      |> put_in([y2, x2], e1)
      |> check()

    moves = [{x1, y1}, {x2, y2}]

    if acc != [] do
      {cells, score, extra_turn} =
        check_and_clean(cells, consumers, acc, score, turns, :decr_turn, moves)

      {turns, extra_turns} = update_turns(turns, extra_turns, extra_turn)
      if turns == 0, do: send_to(consumers, {:gameover, score, board.username != nil})

      {:noreply,
       %Game{
         board
         | cells: cells,
           score: score,
           extra_turns: extra_turns,
           played_turns: board.played_turns + 1,
           turns: turns
       }}
    else
      send_to(consumers, {:error, {:illegal_move, {x1, y1}, {x2, y2}}})
      {:noreply, board}
    end
  end

  defp check_swap({x1, y1}, {x2, y2}, %Game{cells: cells} = board)
       when x1 >= 1 and x1 <= 8 and y1 >= 1 and y1 <= 8 and
              x2 >= 1 and x2 <= 8 and y2 >= 1 and y2 <= 8 do
    e1 = cells[y1][x1]
    e2 = cells[y2][x2]

    {_cells, acc} =
      cells
      |> put_in([y1, x1], e2)
      |> put_in([y2, x2], e1)
      |> check()

    {:reply, {acc != [], acc}, board}
  end

  defp update_turns(turns, extra, :decr_turn), do: {turns - 1, extra}
  defp update_turns(turns, extra, {:extra_turn, n}), do: {turns + (n - 1), extra + (n - 1)}

  defp build_show(cells) do
    for y <- 1..8 do
      for x <- 1..8 do
        cells[y][x]
      end
    end
  end

  defp add_moves(acc, moves) do
    Enum.reduce(acc, moves, fn {_, points}, acc_moves ->
      if points -- points -- moves != [] do
        acc_moves
      else
        point =
          points
          |> Enum.sort_by(fn {x, y} -> {y, x} end)
          |> List.first()

        [point | acc_moves]
      end
    end)
  end

  defp check_extra_turns(_consumers, {:extra_turn, n}, _) when n > 1, do: {:extra_turn, n}

  defp check_extra_turns(consumers, previous, acc) do
    acc
    |> Enum.filter(fn {_, p} -> length(p) >= 4 end)
    |> Enum.split_with(fn {_, p} -> length(p) == 4 end)
    |> case do
      {[], []} ->
        previous

      {_, []} ->
        send_to(consumers, {:extra_turn, 1})

      _ ->
        send_to(consumers, {:extra_turn, 2})
    end
  end

  defp check_and_clean(cells, consumers, [], score, _turns, extra_turns, _moves) do
    send_to(consumers, :play)
    {cells, score, extra_turns}
  end

  defp check_and_clean(cells, consumers, acc, score, turns, extra_turns, moves) do
    new_score =
      acc
      |> Enum.flat_map(fn {_dir, points} -> points end)
      |> Enum.map(fn {x, y} -> cells[y][x] end)
      |> Enum.sum()

    extra_turns = check_extra_turns(consumers, extra_turns, acc)
    total_score = new_score + score
    send_to(consumers, {:match, new_score, total_score, acc, build_show(cells)})
    moves = add_moves(acc, moves)

    {cells, acc} =
      cells
      |> clean(consumers, acc, moves)
      |> check()

    send_to(consumers, {:show, build_show(cells)})
    check_and_clean(cells, consumers, acc, total_score, turns, extra_turns, [])
  end

  defp check(cells, n, acc, x, y, inc_x, inc_y) do
    if cells[y][x] == n do
      new_x = inc_x + x
      new_y = inc_y + y

      if new_x >= 1 and new_x <= @board_x and new_y >= 1 and new_y <= @board_y do
        check(cells, n, [{x, y} | acc], new_x, new_y, inc_x, inc_y)
      else
        [{x, y} | acc]
      end
    else
      acc
    end
  end

  defp gen_clean(cells, tries \\ @max_tries)

  defp gen_clean(_cells, 0), do: throw(:badluck)

  defp gen_clean(cells, tries) do
    {cells, acc} =
      cells
      |> check()
      |> clean()
      |> check()

    if acc != [] do
      gen_clean(cells, tries - 1)
    else
      Logger.debug("[gen_clean] achieved! in try #{tries}")
      cells
    end
  end

  defp incr_kind(8), do: 8
  defp incr_kind(i), do: i + 1

  defp clean({cells, acc}), do: clean(cells, [], acc)

  defp clean(cells, consumers, acc, moves \\ []) do
    points = Enum.flat_map(acc, fn {_, elems} -> elems end)
    move_points = moves -- moves -- points

    cells =
      move_points
      |> Enum.reduce(cells, fn {x, y}, cells ->
        new_kind = incr_kind(cells[y][x])
        Logger.debug("[clean] add #{new_kind} to (#{x},#{y})")
        send_to(consumers, {:new_kind, x, y, new_kind})
        put_in(cells[y][x], new_kind)
      end)

    (points -- move_points)
    |> Enum.filter(fn elem -> elem not in moves end)
    |> Enum.sort_by(fn {x, y} -> {y, x} end)
    |> Enum.reduce(cells, fn {x, y}, cells -> slide(cells, consumers, x, y) end)
  end

  defp slide(cells, consumers, x, 1) do
    new_piece = new_piece()
    send_to(consumers, {:slide_new, x, new_piece})
    put_in(cells[1][x], new_piece)
  end

  defp slide(cells, consumers, x, y) do
    send_to(consumers, {:slide, x, y - 1, y})

    cells[y][x]
    |> put_in(cells[y - 1][x])
    |> slide(consumers, x, y - 1)
  end

  defp check(cells, acc \\ [], x \\ 1, y \\ 1)

  defp check(cells, acc, x, y) when x > @board_x, do: check(cells, acc, 1, y + 1)

  defp check(cells, acc, _x, y) when y > @board_y do
    acc =
      acc
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
    Logger.debug("[remove_dups] #{inspect(entry)} in #{inspect(entries)}")

    if Enum.any?(entries, fn {d, elems0} -> d == dir and elems -- elems0 == [] end) do
      entries
    else
      [entry | entries]
    end
  end

  defp find_mixed({_dir, elems} = entry, entries) do
    mixed = Enum.filter(entries, fn {_, elems0} -> elems -- elems -- elems0 != [] end)

    if mixed != [] do
      entries = entries -- mixed

      elems =
        [entry | mixed]
        |> Enum.flat_map(fn {_, e} -> e end)
        |> Enum.uniq()

      [{:mixed, elems} | entries]
    else
      [entry | entries]
    end
  end

  defp new_piece, do: Enum.random(@init_symbols_prob)
end
