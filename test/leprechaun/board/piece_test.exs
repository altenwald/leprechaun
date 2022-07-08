defmodule Leprechaun.Board.PieceTest do
  use ExUnit.Case
  alias Leprechaun.Board.Piece

  describe "generate" do
    test "new" do
      assert Piece.new() in 1..5
      assert Piece.push([6])
      assert Piece.new() == 6
      assert Piece.new() in 1..5
    end
  end
end
