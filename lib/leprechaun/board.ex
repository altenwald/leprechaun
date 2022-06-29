defmodule Leprechaun.Board do
  @moduledoc """
  The board and functions for handling the board and cells.

  ## Events

  Some functions are requesting a function in some parts which is going
  to be in use to be running passing a tuple with specific information
  when an action is going to happen. The possible tuples are:

  `{:insert, x, new_piece}`::
  It's indicating a new piece is going to be inserted in the board in the
  `x` position and the kind of piece is determined by `new_piece`.

  `{:slide, x, y1, y2}`::
  Perform a slide of the piece in the column `x` from the row `y1` to the
  row `y2`. It's sent when a gap is needed to be filled and exists a piece
  over this gap. Usually `(x, y1)` is the cell position of the piece to
  be moved down and `(x, y2)` the cell position of the gap to be filled.

  `{:new_kind, x, y, new_kind}`
  Perform a transformation of the piece in the position `(x, y)` to the
  new kind expressed by `new_kind`.
  """
  alias Leprechaun.Board
  @behaviour Access

  @board_size_y 8
  @board_size_x 8

  if Mix.env() != :test do
    @init_symbols_prob List.duplicate(1, 15) ++
                         List.duplicate(2, 12) ++
                         List.duplicate(3, 9) ++
                         List.duplicate(4, 6) ++
                         List.duplicate(5, 1)
  end

  @piece_max 8

  @typedoc """
  The piece is represented by a number, we have 8 different representations at
  the moment. Depending on the interface these could be:

  - 0 empty, when there's a gap, it's not usual and it should happen only
    during slides.
  - 1 bronze or 💰 on brown color.
  - 2 silver or 💰 on gray color.
  - 3 gold or 💰 on yellow color.
  - 4 sack or 💶 on brown color.
  - 5 chest or 💶 on gray color.
  - 6 big-chest or 💶 on yellow color.
  - 7 pot or MX on gray color.
  - 8 rainbow-pot or MX on yellow color.

  Note that the representation is responsibility of `Leprechaun.Board` and
  `Leprechaun.Console` and the information represented above could change.
  """
  @type piece() :: 1..8

  @typedoc """
  The X position on the board. It's in use for representing the position of
  a cell on the board.
  """
  @type pos_x :: pos_integer()

  @typedoc """
  The Y position on the board. It's in use for representing the position of
  a cell on the board.
  """
  @type pos_y :: pos_integer()

  @typedoc """
  The `(x, y)` position on the board. It's in use for representing the
  complete position of a cell on the board.
  """
  @type cell_pos :: {pos_x(), pos_y()}

  @typedoc """
  The X size of the board. It's in use for representing the size of the board.
  """
  @type size_x :: pos_integer()

  @typedoc """
  The Y size of the board. It's in use for representing the size of the board.
  """
  @type size_y :: pos_integer()

  @typedoc """
  Indicate the orientation of a match, we could find:

  - `vertical` when the match is in the Y axis.
  - `horizontal` when the match is in the X axis.
  - `mixed` when we process the matches and find adjacent `vertical` and
    `horizontal` we merge them to create a `mixed` one.
  """
  @type match_direction :: :vertical | :horizontal | :mixed

  @typedoc """
  The return for the function `find_matches/1` uses this type as the return
  type. The composition is a `MapSet` where we are including all of the
  matches found in the board (if any). Each element inside is a 2-element
  tuple where the first element is a `match_direction()` and the second
  element is another `MapSet` with the `cell_pos()` for the cells
  performing the match.
  """
  @type matches :: MapSet.t({match_direction(), MapSet.t(cell_pos())})

  @typedoc """
  The events which could be triggered. This will be in use as the only
  one parameter passed to the optional anonymous function for the
  function `apply_matches/4`.
  """
  @type event ::
          {:insert, pos_x(), piece()}
          | {:new_kind, pos_x(), pos_y(), piece()}
          | {:slide, pos_x(), pos_y(), pos_y()}

  @typedoc """
  The composition of a row inside of the cells which are used as board.
  This is based on the index as a `size_x()` type and the content as
  the `piece()`.
  """
  @type row :: %{size_x() => piece()}

  @typedoc """
  The cells are the board. It's a map where the index is the number of
  row using the type `size_y()` and the content is a `row()`.
  """
  @type cells :: %{size_y() => row()}

  @typedoc """
  The internal storage of the board is opaque, it's meaning it mustn't be in
  use outside of this module. The internal elements of this structure are:

  - `cells`: a map of maps where see the type `cells`.
  - `size_x`: the size of the map in X axis.
  - `size_y`: the size of the map in Y axis.

  Check the module functions to get information from this data type.
  """
  @opaque t() :: %__MODULE__{
            cells: cells(),
            size_x: size_x(),
            size_y: size_y()
          }

  defstruct cells: [],
            size_x: @board_size_x,
            size_y: @board_size_y

  @doc """
  Creates a new board. Using the default values for height and width
  (#{@board_size_x}x#{@board_size_y}), see `new/2`.
  """
  @spec new() :: t()
  def new, do: new(@board_size_x, @board_size_y)

  @doc """
  Creates a new board with the height and width passed as parameters.
  It is also filling the board with random pieces ensuring there are
  not matches (3 or more pieces together).
  """
  @spec new(size_x(), size_y()) :: t()
  def new(size_x, size_y) do
    cells =
      for y <- 1..size_y, into: %{} do
        {y, for(x <- 1..size_x, into: %{}, do: {x, new_piece()})}
      end

    %Board{cells: cells, size_x: size_x, size_y: size_y}
    |> clean()
  end

  defp clean(board) do
    matches = find_matches(board)

    if MapSet.size(matches) > 0 do
      board
      |> apply_matches(matches)
      |> clean()
    else
      board
    end
  end

  @doc """
  Return a representation of the board in list of lists form. Each
  cell is represented by a number from 1 to #{@piece_max}.
  """
  @spec show(t()) :: [[piece()]]
  def show(%__MODULE__{} = board) do
    for y <- 1..board.size_y do
      for x <- 1..board.size_x do
        board.cells[y][x]
      end
    end
  end

  @doc """
  Get the size for the board passed as parameter.
  """
  @spec get_size(t()) :: {size_x(), size_y()}
  def get_size(%__MODULE__{} = board), do: {board.size_x, board.size_y}

  defguardp valid_x(board, x) when is_integer(x) and x >= 1 and x <= board.size_x
  defguardp valid_y(board, y) when is_integer(y) and y >= 1 and y <= board.size_y
  defguardp valid_x(board, x1, x2) when valid_x(board, x1) and valid_x(board, x2)
  defguardp valid_y(board, y1, y2) when valid_y(board, y1) and valid_y(board, y2)
  defguardp valid_xy(board, x1, y1, x2, y2) when valid_x(board, x1, x2) and valid_y(board, y1, y2)
  defguardp offset(a, b) when abs(a - b) in 0..1

  defguardp valid_offset(x1, y1, x2, y2)
            when offset(x1, x2) and offset(y1, y2) and abs(x1 - x2) != abs(y1 - y2)

  defguardp valid_move(board, x1, y1, x2, y2)
            when valid_xy(board, x1, y1, x2, y2) and valid_offset(x1, y1, x2, y2)

  @doc """
  Performs the swap of two cells inside of the board. The only restriction
  is that the move must be legit, it means that it's not possible move a pieces
  which aren't adjacent horizontally or vertically.

  Note that it's not checking if the move is performing matches, it must be
  done using `find_matches/1`. In case there is no matches, you can drop the
  new board and still use the previous one.
  """
  @spec move(t(), from :: cell_pos(), to :: cell_pos()) ::
          t() | {:error, {:illegal_move, {cell_pos(), cell_pos()}}}
  def move(%__MODULE__{} = board, {x1, y1}, {x2, y2}) when valid_move(board, x1, y1, x2, y2) do
    cell1 = board[y1][x1]
    cell2 = board[y2][x2]

    board
    |> put_in([y1, x1], cell2)
    |> put_in([y2, x2], cell1)
  end

  def move(%__MODULE__{}, {x1, y1}, {x2, y2}) do
    {:error, {:illegal_move, {{x1, y1}, {x2, y2}}}}
  end

  if Mix.env() == :test do
    defp new_piece, do: Leprechaun.Support.Piece.new_piece()
  else
    defp new_piece, do: Enum.random(@init_symbols_prob)
  end

  defp slide(%Board{} = board, x, 1, f) do
    new_piece = new_piece()
    f.({:insert, x, new_piece})
    put_in(board[1][x], new_piece)
  end

  defp slide(%Board{} = board, x, y, f) do
    f.({:slide, x, y - 1, y})

    put_in(board[y][x], board[y - 1][x])
    |> slide(x, y - 1, f)
  end

  @doc """
  Find matches in the board passed as parameter. It returns a `MapSet`. The
  content of the `MapSet` will have 2-elements tuples where the first element
  could be `:vertical`, `:horizontal` or `:mixed` (depending on if the match
  is one of them) and the second element will be a `MapSet` containing cell
  positions.
  """
  @spec find_matches(t()) :: matches()
  def find_matches(%__MODULE__{} = board), do: find_matches(board, [], 1, 1)

  defp find_matches(board, matches, x, y) when x > board.size_x,
    do: find_matches(board, matches, 1, y + 1)

  defp find_matches(board, matches, _x, y) when y > board.size_y do
    matches
    |> Enum.filter(fn {_dir, elems} -> MapSet.size(elems) >= 3 end)
    |> Enum.sort_by(fn {dir, elems} -> {dir, MapSet.size(elems)} end, &>=/2)
    |> Enum.reduce(MapSet.new(), &remove_subsets/2)
    |> Enum.reduce(MapSet.new(), &find_mixed/2)
  end

  defp find_matches(%Board{} = board, matches, x, y) do
    current_cell = board[y][x]

    matches = [
      {:horizontal, find_adjacents(board, current_cell, MapSet.new(), x, y, 1, 0)},
      {:vertical, find_adjacents(board, current_cell, MapSet.new(), x, y, 0, 1)}
      | matches
    ]

    find_matches(board, matches, x + 1, y)
  end

  defp find_adjacents(board, current_cell, adjacents, x, y, inc_x, inc_y) do
    if board[y][x] == current_cell do
      new_x = inc_x + x
      new_y = inc_y + y
      adjacents = MapSet.put(adjacents, {x, y})

      if new_x in 1..board.size_x and new_y in 1..board.size_y do
        find_adjacents(board, current_cell, adjacents, new_x, new_y, inc_x, inc_y)
      else
        adjacents
      end
    else
      adjacents
    end
  end

  defp remove_subsets({_dir, matches} = entry, entries) do
    if Enum.any?(entries, fn {_dir, matches0} -> MapSet.subset?(matches, matches0) end) do
      entries
    else
      MapSet.put(entries, entry)
    end
  end

  defp find_mixed({_dir, elems} = entry, entries) do
    mixed =
      entries
      |> Enum.reject(fn {_, elems0} -> MapSet.disjoint?(elems, elems0) end)
      |> MapSet.new()

    if MapSet.size(mixed) > 0 do
      entries = MapSet.difference(entries, mixed)

      elems =
        MapSet.put(mixed, entry)
        |> Enum.flat_map(fn {_, e} -> e end)
        |> MapSet.new()

      MapSet.put(entries, {:mixed, elems})
    else
      MapSet.put(entries, entry)
    end
  end

  @doc """
  Apply the matches to the board. It's performing the following steps:

  1. Remove the matched cells.
  2. Put in place the increased piece for the match.
  3. Slide pieces down to fill the gaps generating new ones.

  You can set the `moved_cells` to indicate where the new increased pieces
  should appear and a function (`f`) which will be in use to indicate the
  movements performed inside of the board. See above the list of events
  which will be triggered.
  """
  @spec apply_matches(t(), matches()) :: t()
  @spec apply_matches(t(), matches(), MapSet.t(cell_pos())) :: t()
  @spec apply_matches(t(), matches(), MapSet.t(cell_pos()), (event -> any)) :: t()
  def apply_matches(
        %__MODULE__{} = board,
        matches,
        moved_cells \\ MapSet.new(),
        f \\ fn _ -> :ok end
      ) do
    matched_cells =
      matches
      |> Enum.reduce(MapSet.new(), fn {_dir, points}, acc_points ->
        MapSet.union(points, acc_points)
      end)

    new_kind_cells = MapSet.intersection(matched_cells, moved_cells)

    new_kind_cells =
      if MapSet.size(new_kind_cells) == 0 do
        MapSet.new(Enum.take(matched_cells, 1))
      else
        new_kind_cells
      end

    board =
      new_kind_cells
      |> Enum.reduce(board, fn {x, y}, board ->
        new_kind = incr_kind(board.cells[y][x])
        f.({:new_kind, x, y, new_kind})
        put_in(board[y][x], new_kind)
      end)

    matched_cells
    |> MapSet.difference(new_kind_cells)
    |> Enum.sort_by(fn {x, y} -> {y, x} end)
    |> Enum.reduce(board, fn {x, y}, board -> slide(board, x, y, f) end)
  end

  defp incr_kind(@piece_max), do: @piece_max
  defp incr_kind(i), do: i + 1

  @doc """
  Get the matched cells from a board.
  """
  @spec get_matched_cells(t(), matches()) :: [piece()]
  def get_matched_cells(board, matches) do
    matches
    |> Enum.flat_map(fn {_dir, points} -> Enum.to_list(points) end)
    |> Enum.map(fn {x, y} -> board[y][x] end)
  end

  @doc false
  @spec fetch(t(), pos_y()) :: {:ok, row()} | :error
  @impl Access
  def fetch(%__MODULE__{} = board, y) when valid_y(board, y) do
    {:ok, board.cells[y]}
  end

  def fetch(_board, _y), do: :error

  @doc false
  @impl Access
  @spec get_and_update(t(), pos_y(), (term | nil -> {row(), row()} | :pop)) :: {row(), t()}
  def get_and_update(%__MODULE__{} = board, y, f) when valid_y(board, y) do
    get_and_update_in(board.cells[y], f)
  end

  @doc false
  @spec pop(t(), pos_y()) :: {row(), t()}
  @impl Access
  def pop(%__MODULE__{} = board, y) do
    {board.cells[y], board}
  end
end
