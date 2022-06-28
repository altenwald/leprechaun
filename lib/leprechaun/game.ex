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
  alias Leprechaun.{Board, Game, HiScore}
  require Logger

  @board_x 8
  @board_y 8

  @max_running_hours 2

  @init_turns 10

  defstruct board: nil,
            score: 0,
            turns: @init_turns,
            played_turns: 0,
            extra_turns: 0,
            username: nil,
            consumers: []

  @type game_name() :: String.t() | atom()
  @type match() :: boolean()
  @type username() :: String.t()
  @type remote_ip() :: String.t()
  @type score() :: non_neg_integer()
  @type turns() :: non_neg_integer()
  @type opts() :: [{:max_running_time, timeout()}, {:turns, turns()}]
  @type cells() :: [[Board.piece()]]

  @spec start_link(game_name(), opts()) :: {:ok, pid}
  def start_link(name, opts \\ []) do
    {:ok, board} = GenServer.start_link(__MODULE__, opts, name: via(name))
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

  @spec move(game_name(), from :: Board.cell_pos(), to :: Board.cell_pos()) :: :ok
  def move(name, point_from, point_to) do
    GenServer.cast(via(name), {:move, point_from, point_to})
  end

  @spec check_move(game_name(), from :: Board.cell_pos(), to :: Board.cell_pos()) ::
          {match(), Board.matches()}
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

  @impl GenServer
  def init(opts) do
    board = Board.new(@board_x, @board_y)

    max_running_time = opts[:max_running_time] || :timer.hours(@max_running_hours)
    Process.send_after(self(), :stop, max_running_time)
    Logger.info("[board] started #{inspect(self())}")

    {:ok, %Game{board: board, turns: opts[:turns] || @init_turns}}
  end

  @impl GenServer
  def handle_call(:show, _from, %Game{} = game) do
    {:reply, Board.show(game.board), game}
  end

  def handle_call(:score, _from, game) do
    {:reply, game.score, game}
  end

  def handle_call(:turns, _from, game) do
    {:reply, game.turns, game}
  end

  def handle_call({:check_move, _point1, _point2}, _from, %Game{turns: 0} = game) do
    {:reply, {false, MapSet.new()}, game}
  end

  def handle_call({:check_move, point1, point2}, _from, game) do
    {:reply, check_swap(point1, point2, game), game}
  end

  def handle_call({:hiscore, username, remote_ip}, _from, %Game{turns: 0, username: nil} = game) do
    case HiScore.save(username, game.score, game.played_turns, game.extra_turns, remote_ip) do
      {:ok, hiscore} ->
        send_to(game.consumers, {:hiscore, HiScore.get_order(hiscore.id)})
        {:reply, :ok, %Game{game | username: username}}

      {:error, changeset} ->
        {:reply, {:error, changeset.errors}, game}
    end
  end

  def handle_call({:hiscore, _username, _remote_ip}, _from, %Game{username: nil} = game) do
    {:reply, {:error, :still_playing}, game}
  end

  def handle_call({:hiscore, _username, _remote_ip}, _from, game) do
    {:reply, {:error, :already_set}, game}
  end

  @impl GenServer
  def handle_cast({:move, _point1, _point2}, %Game{turns: 0} = game) do
    send_to(game.consumers, {:error, :gameover})
    {:noreply, game}
  end

  def handle_cast({:move, point1, point2}, game) do
    {:noreply, swap(point1, point2, game)}
  end

  def handle_cast({:consumer, from}, game) do
    Process.monitor(from)
    {:noreply, %Game{game | consumers: [from | game.consumers]}}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %Game{consumers: consumers} = game) do
    {:noreply, %Game{game | consumers: consumers -- [pid]}}
  end

  def handle_info(:stop, state) do
    Logger.warn("game stopped")
    {:stop, :normal, state}
  end

  defp send_to(consumers, message) do
    Logger.debug("consumers (#{inspect(consumers)}): #{inspect(message)}")
    for consumer <- consumers, do: send(consumer, message)
    message
  end

  defp update_turns(_matches, 1), do: 1

  defp update_turns(matches, turns_mod) do
    matches
    |> Enum.map(fn {_dir, points} -> MapSet.size(points) end)
    |> Enum.filter(&(&1 > 3))
    |> Enum.split_with(&(&1 == 4))
    |> case do
      {[], []} -> turns_mod
      {_, []} -> 0
      {_, _} -> 1
    end
  end

  defp swap(point1, point2, game) do
    Logger.info("swap #{inspect(point1)} to #{inspect(point2)}")

    case Board.move(game.board, point1, point2) do
      {:error, _} = error ->
        send_to(game.consumers, error)
        game

      moved_board ->
        moves = MapSet.new([point1, point2])
        find_and_apply_matches(game, moved_board, moves, -1)
    end
  end

  defp find_and_apply_matches(game, board, moves, turns_mod) do
    matches = Board.find_matches(board)

    if MapSet.size(matches) == 0 do
      if MapSet.size(moves) > 0 do
        [point1, point2] = Enum.to_list(moves)
        send_to(game.consumers, {:error, {:illegal_move, {point1, point2}}})
        game
      else
        case turns_mod do
          -1 -> :ok
          0 -> send_to(game.consumers, {:extra_turn, 1})
          1 -> send_to(game.consumers, {:extra_turn, 2})
        end

        send_to(game.consumers, {:show, Board.show(board)})

        turns = game.turns + turns_mod

        if turns == 0 do
          send_to(game.consumers, {:gameover, game.score, game.username != nil})
        else
          send_to(game.consumers, :play)
        end

        %Game{
          game
          | board: board,
            turns: turns,
            extra_turns: if(turns_mod == 1, do: game.extra_turns + 1, else: game.extra_turns),
            played_turns: game.played_turns + 1
        }
      end
    else
      turns_mod = update_turns(matches, turns_mod)

      score =
        board
        |> Board.get_matched_cells(matches)
        |> Enum.sum()

      send_match_events(game.consumers, board, matches, game.score)

      board =
        Enum.reduce(matches, board, fn match, board ->
          Board.apply_matches(board, MapSet.new([match]), moves, &send_to(game.consumers, &1))
        end)

      %Game{game | score: game.score + score}
      |> find_and_apply_matches(board, MapSet.new(), turns_mod)
    end
  end

  defp send_match_events(consumers, moved_board, matches, score) do
    pieces = Board.show(moved_board)

    Enum.reduce(matches, score, fn {dir, cells} = match, current_score ->
      new_score = Enum.sum(Board.get_matched_cells(moved_board, MapSet.new([match])))
      total_score = current_score + new_score
      cells = Enum.to_list(cells)

      send_to(consumers, {:match, new_score, total_score, [{dir, cells}], pieces})
      total_score
    end)
  end

  defp check_swap(point1, point2, %Game{} = game) do
    case Board.move(game.board, point1, point2) do
      {:error, _} ->
        {false, MapSet.new()}

      moved_board ->
        matches = Board.find_matches(moved_board)
        {MapSet.size(matches) > 0, matches}
    end
  end
end
