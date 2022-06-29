defmodule Leprechaun.Game do
  @moduledoc """
  Leprechaun Game is controlling the progression of the game and the interface
  between all of the elements.

  The game is responsible to start a new process with all of the information
  for the game. In addition, it's also:

  - acting as an interface between the Board and the player applying the game
    rules and updating the internal data for the game: score, turns,
    extra_turns, and played_turns among others.
  - notify consumers about the progression of the game using events. But
    indeed the notifications are side-effects provoked by actions of the
    user and part of the interface.

  The game can be started using the function `start_link/1`, the only parameter
  required is the ID to localize the game. It could be a string or an atom.
  Usually from console it's more common to use an atom and from the web
  interface, based on security, it's better use strings. We are using
  `Registry` to register these names. Check the private `via/1` function.
  """
  use GenServer
  alias Leprechaun.{Board, Game, HiScore}
  require Logger

  @board_x 8
  @board_y 8

  @max_running_hours 2

  @init_turns 10

  @typedoc """
  Name of the game. It's going to be in use to register the name inside of
  the Registry.
  """
  @type game_name() :: String.t() | atom()

  @typedoc """
  It's telling if a match was or not found.
  """
  @type match?() :: boolean()

  @typedoc """
  The name provided for the high score.
  """
  @type username() :: String.t()

  @typedoc """
  The IP where the user is playing from.
  """
  @type remote_ip() :: String.t()

  @typedoc """
  The amount of points achieved by the user.
  """
  @type score() :: non_neg_integer()

  @typedoc """
  The representation of the turns. It could be in use for indicating the
  number of turns played, remained or extra.
  """
  @type turns() :: non_neg_integer()

  @typedoc """
  Options passed for the starting of the game process. The possible
  options are:

  - `max_running_time` is the amount of time the game could be running.
    Based on security we are configuring by default a game of 2 hours,
    if the player is playing for more than 2 hours, the game is
    automatically terminated. But even if the player leaves the game
    the game is terminated at that point. For testing purposes we could
    configure a smaller size.
  - `turns` is the amount of turns the game starts with. The default
    value is 10.
  """
  @type opts() :: [{:max_running_time, timeout()}, {:turns, turns()}]

  @typedoc """
  The internal storage for the game. We use an opaque term to avoid this
  could be handle from outside. Use the functions from this module to
  modify or retrieve information from this structure.

  The internal information stored is:

  - `board` is a representation of `Leprechaun.Board`.
  - `score` is the amount of points the user is getting from its turns.
  - `turns` is the amount of turns remaining in the game.
  - `played_turns` the amount of turns the user played.
  - `extra_turns` the amount of extra turns the user achieved. It's
    only counting the match of 5 or more pieces together.
  - `username` is the name of the user when it's provided for the
    high score table, see `Leprechaun.HiScore`.
  - `consumers` is the list of PIDs where we have to send the events.
  """
  @opaque t() :: %__MODULE__{
            board: Board.t() | nil,
            score: score(),
            turns: turns(),
            played_turns: turns(),
            extra_turns: turns(),
            username: username() | nil,
            consumers: [pid()]
          }

  defstruct board: nil,
            score: 0,
            turns: @init_turns,
            played_turns: 0,
            extra_turns: 0,
            username: nil,
            consumers: []

  @doc """
  Start the game process. It's providing options based on the `opts()` type.
  It's also adding the current process launching this new game as a consumer.
  """
  @spec start_link(game_name(), opts()) :: {:ok, pid}
  def start_link(name, opts \\ []) do
    {:ok, board} = GenServer.start_link(__MODULE__, opts, name: via(name))
    :ok = add_consumer(name)
    {:ok, board}
  end

  defp via(board) do
    {:via, Registry, {Leprechaun.Game.Registry, board}}
  end

  @doc """
  Check if the game process exists.
  """
  @spec exists?(game_name()) :: boolean()
  def exists?(board) do
    Registry.lookup(Leprechaun.Game.Registry, board) != []
  end

  @doc """
  Stop the game process.
  """
  @spec stop(game_name()) :: :ok
  def stop(name), do: GenServer.stop(via(name))

  @doc """
  Retrieve a representation of the board as a list of lists which is
  including numbers as the representation of the pieces, see
  `Leprechaun.Board.piece()`.
  """
  @spec show(game_name()) :: [[Board.piece()]]
  def show(name), do: GenServer.call(via(name), :show)

  @doc """
  Perform a move. If you have still turns the system is trying to perform
  this move. The result is always `:ok` but the game process will be triggering
  different events according to if the move was legit or not.
  """
  @spec move(game_name(), from :: Board.cell_pos(), to :: Board.cell_pos()) :: :ok
  def move(name, point_from, point_to) do
    GenServer.cast(via(name), {:move, point_from, point_to})
  end

  @doc """
  Check a move (dry-run). It's similar to `move/3` but it's not performing
  the move in the board, or the game data, it's only giving information about
  if there's a match and what will be the matches returning a tuple with two
  elements:

  - `match?` as the boolean information about if there is a match or not
    performing this move.
  - `matches` the detailed information for these matches, see
    `Leprechaun.Board.matches()`.

  Note that this function is useful for the implementation of bots.
  """
  @spec check_move(game_name(), from :: Board.cell_pos(), to :: Board.cell_pos()) ::
          {match?(), Board.matches()}
  def check_move(name, point_from, point_to) do
    GenServer.call(via(name), {:check_move, point_from, point_to})
  end

  @doc """
  Register a name for the High Score. This function is providing the name and
  the remote IP to be registered with the score in the High Score table. It's
  an action only valid when the game is in `:gameover` state, it means the
  number of turns are 0 and it could be only performed once.
  """
  @spec hiscore(game_name(), username(), remote_ip()) :: :ok | {:error, term()}
  def hiscore(name, username, remote_ip) do
    GenServer.call(via(name), {:hiscore, username, remote_ip})
  end

  @doc """
  Add a consumer to listen for the events coming from the game. These events
  are referred above in the Events section.
  """
  @spec add_consumer(game_name()) :: :ok
  def add_consumer(name) do
    GenServer.cast(via(name), {:consumer, self()})
  end

  @doc """
  Retrieve the score for the indicated game process.
  """
  @spec score(game_name()) :: score()
  def score(name), do: GenServer.call(via(name), :score)

  @doc """
  Retrieve the remaining turns for the indicated game process.
  """
  @spec turns(game_name()) :: turns()
  def turns(name), do: GenServer.call(via(name), :turns)

  @doc false
  @impl GenServer
  def init(opts) do
    board = Board.new(@board_x, @board_y)

    max_running_time = opts[:max_running_time] || :timer.hours(@max_running_hours)
    Process.send_after(self(), :stop, max_running_time)
    Logger.info("[board] started #{inspect(self())}")

    {:ok, %Game{board: board, turns: opts[:turns] || @init_turns}}
  end

  @doc false
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

  @doc false
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

  @doc false
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
    send_to(game.consumers, {:move, point1, point2})

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
