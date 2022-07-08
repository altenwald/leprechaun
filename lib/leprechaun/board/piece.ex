defmodule Leprechaun.Board.Piece do
  @moduledoc """
  Handle the pieces which are possible to be included in the board.
  """

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
  - 9 clover or 🍀
  - 10 leprechaun 🧚‍♀️

  Note that the representation is responsibility of `Leprechaun.Board` and
  `Leprechaun.Console` and the information represented above could change.
  """
  @type t() :: 1..10

  @init_symbols_prob List.duplicate(1, 15) ++
                       List.duplicate(2, 12) ++
                       List.duplicate(3, 9) ++
                       List.duplicate(4, 6) ++
                       List.duplicate(5, 1)

  @doc """
  Generates a new piece based on the random probability, by default it will
  be pondering the values of:

  - bronze (1) weight 15 (34.88%)
  - silver (2) weight 12 (27.90%)
  - gold (3) weight 9 (20.93%)
  - sack (4) weight 6 (13.95%)
  - chest (5) weight 1 (2.32%)
  """
  @spec new() :: t()
  def new do
    case Process.get(:pieces) do
      pieces when is_list(pieces) and length(pieces) > 0 ->
        {[piece], remain_pieces} = Enum.split(pieces, 1)
        Process.put(:pieces, remain_pieces)
        piece

      _ ->
        Enum.random(@init_symbols_prob)
    end
  end

  @doc """
  Push next pieces to be retrieved. If there are other pieces waiting, then
  the next pieces are pushed to the end of the queue of waiting pieces to
  be retrieved.
  """
  @spec push([t()]) :: :ok
  def push(next_pieces) when is_list(next_pieces) do
    if pieces = Process.get(:pieces) do
      set(pieces ++ next_pieces)
    else
      set(next_pieces)
    end
  end

  @doc """
  Remove the waiting pieces and set as the following pieces the one set by
  the function.
  """
  @spec set([t()]) :: :ok
  def set(pieces) when is_list(pieces) do
    Process.put(:pieces, pieces)
    :ok
  end

  @piece_max 8

  @doc """
  Increase the current piece generating the following level or deciding what
  should be the next piece to be dropped.
  """
  @spec incr_kind(t()) :: t()
  def incr_kind(@piece_max), do: @piece_max
  def incr_kind(i), do: i + 1
end
