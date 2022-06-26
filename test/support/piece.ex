defmodule Leprechaun.Support.Piece do
  @moduledoc """
  Let us configure the following pieces to be in use when we are in test
  environment. We have to put in a list all of the pieces which are going
  to be required to be inserted into the board.
  """

  @type piece() :: 1..8
  @type pieces() :: [piece()]

  @doc """
  Set the following pieces to be retrieved.
  """
  @spec set_pieces(pieces()) :: :ok
  def set_pieces(pieces) when is_list(pieces) do
    :persistent_term.put(__MODULE__, pieces)
  end

  @doc """
  Add pieces to the existing ones to be retrieved.
  """
  @spec add_pieces(pieces()) :: :ok
  def add_pieces(pieces) when is_list(pieces) do
    current_pieces = :persistent_term.get(__MODULE__)
    :persistent_term.put(__MODULE__, current_pieces ++ pieces)
  end

  @doc """
  Retrieve the piece.
  """
  @spec new_piece() :: piece()
  def new_piece do
    [piece | pieces] = :persistent_term.get(__MODULE__)
    :persistent_term.put(__MODULE__, pieces)
    piece
  end
end
