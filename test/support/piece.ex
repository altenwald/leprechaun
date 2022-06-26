defmodule Leprechaun.Support.Piece do
  def set_pieces(pieces) when is_list(pieces) do
    :persistent_term.put(__MODULE__, pieces)
  end

  def add_pieces(pieces) when is_list(pieces) do
    current_pieces = :persistent_term.get(__MODULE__)
    :persistent_term.put(__MODULE__, current_pieces ++ pieces)
    :ok
  end

  def new_piece do
    [piece | pieces] = :persistent_term.get(__MODULE__)
    :persistent_term.put(__MODULE__, pieces)
    piece
  end
end
