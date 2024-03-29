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
  alias Leprechaun.Board.Piece
  @behaviour Access

  @board_size_y 8
  @board_size_x 8

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
          {:insert, pos_x(), Piece.t()}
          | {:new_kind, pos_x(), pos_y(), Piece.t()}
          | {:slide, pos_x(), pos_y(), pos_y()}

  @typedoc """
  The composition of a row inside of the cells which are used as board.
  This is based on the index as a `size_x()` type and the content as
  the `Piece.t()`.
  """
  @type row :: %{size_x() => Piece.t()}

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
    bare_new(size_x, size_y)
    |> clean()
  end

  @doc """
  Generates a board without reduce it if a match is found. It's
  intended to be in use for specific tests and internal usage.
  """
  @spec bare_new(size_x(), size_y()) :: t()
  def bare_new(size_x, size_y) do
    cells =
      for y <- 1..size_y, into: %{} do
        {y, for(x <- 1..size_x, into: %{}, do: {x, Piece.new()})}
      end

    %Board{cells: cells, size_x: size_x, size_y: size_y}
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
  cell is represented by a number from 1 to the max number represented by
  the pieces (see `Piece` module).
  """
  @spec show(t()) :: [[Piece.t()]]
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

  defp slide(%Board{} = board, x, 1, f) do
    new_piece = Piece.new()
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
    {removed_cells, board} =
      Enum.reduce(matches, {MapSet.new(), board}, fn {_dir, matched_cells},
                                                     {removed_cells, board} ->
        {more_removed_cells, board} =
          marked_and_new_kind_cells(board, matched_cells, moved_cells, f)

        if MapSet.size(matched_cells) >= 5 and MapSet.size(moved_cells) > 0 do
          # gives a clover only 1/3 of times
          Enum.random(-9..5) > 0 && Piece.push([Piece.clover()])
        end

        {MapSet.union(removed_cells, more_removed_cells), board}
      end)

    removed_cells
    |> Enum.sort_by(fn {x, y} -> {y, x} end)
    |> Enum.reduce(board, fn {x, y}, board -> slide(board, x, y, f) end)
  end

  @doc """
  Remove the match cells from the board.
  """
  @spec remove_matches(t(), matches(), (event -> any)) :: t()
  def remove_matches(%__MODULE__{} = board, matches, f) do
    Enum.reduce(matches, MapSet.new(), fn {_dir, matched_cells}, removed_cells ->
      MapSet.union(removed_cells, matched_cells)
    end)
    |> Enum.sort_by(fn {x, y} -> {y, x} end)
    |> Enum.reduce(board, fn {x, y}, board -> slide(board, x, y, f) end)
  end

  defp marked_and_new_kind_cells(board, matched_cells, moved_cells, f) do
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
        new_kind = Piece.incr_kind(board.cells[y][x])
        f.({:new_kind, x, y, new_kind})
        put_in(board[y][x], new_kind)
      end)

    {MapSet.difference(matched_cells, new_kind_cells), board}
  end

  @doc """
  Return matches `mixed` for all of the cells matching the kind passed as
  second parameter.
  """
  @spec match_kind(t(), Piece.t()) :: matches()
  def match_kind(board, kind) do
    matched_cells =
      for y <- 1..board.size_y, x <- 1..board.size_x, reduce: MapSet.new() do
        matched_cells ->
          if board[y][x] == kind do
            MapSet.put(matched_cells, {x, y})
          else
            matched_cells
          end
      end

    MapSet.new([{:mixed, matched_cells}])
  end

  @spec incr_kind(t(), Piece.t(), (event -> any)) :: t()
  def incr_kind(board, old_kind, f) do
    new_kind = Piece.incr_kind(old_kind)

    if new_kind != old_kind do
      for y <- 1..board.size_y, x <- 1..board.size_x, reduce: board do
        board ->
          if board[y][x] == old_kind do
            f.({:new_kind, x, y, new_kind})
            put_in(board[y][x], new_kind)
          else
            board
          end
      end
    else
      board
    end
  end

  @doc """
  Get the matched cells from a board.
  """
  @spec get_matched_cells(t(), matches()) :: [Piece.t()]
  def get_matched_cells(board, matches) do
    matches
    |> Enum.flat_map(fn {_dir, points} -> Enum.to_list(points) end)
    |> then(&get_cells(board, MapSet.new(&1)))
  end

  @doc """
  Retrieve the content of the specified cells.
  """
  @spec get_cells(t(), MapSet.t(cell_pos())) :: [Piece.t()]
  def get_cells(board, positions) do
    Enum.map(positions, fn {x, y} -> board[y][x] end)
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
