defmodule Leprechaun.BoardTest do
  use ExUnit.Case

  alias Leprechaun.Board
  alias Leprechaun.Support.Piece

  describe "new" do
    test "correct new default board" do
      pieces = [
        [1, 2, 2, 3, 4, 3, 2, 1],
        [1, 2, 1, 4, 3, 2, 1, 1],
        [3, 1, 2, 3, 2, 1, 2, 2],
        [1, 2, 3, 2, 1, 2, 1, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      Piece.set_pieces(List.flatten(pieces))

      assert %Board{} = board = Board.new()
      assert pieces == Board.show(board)
      assert {8, 8} == Board.get_size(board)
    end
  end

  describe "playing" do
    setup do
      pieces = [
        [1, 8, 2, 3, 4, 1, 2, 1],
        [1, 8, 1, 4, 3, 3, 1, 1],
        [3, 1, 2, 3, 2, 1, 2, 2],
        [1, 8, 3, 2, 1, 1, 3, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      Piece.set_pieces(List.flatten(pieces))

      board = Board.new()
      %{board: board, pieces: pieces}
    end

    test "correct move (3 elements, type 8)", data do
      Piece.add_pieces([3, 4])
      assert moved_board = Board.move(data.board, {2, 4}, {2, 3})

      assert Board.show(moved_board) == [
               [1, 8, 2, 3, 4, 1, 2, 1],
               [1, 8, 1, 4, 3, 3, 1, 1],
               [3, 8, 2, 3, 2, 1, 2, 2],
               [1, 1, 3, 2, 1, 1, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ]

      matches = MapSet.new(vertical: MapSet.new([{2, 1}, {2, 2}, {2, 3}]))
      assert [8, 8, 8] = Board.get_matched_cells(moved_board, matches)
      assert matches == Board.find_matches(moved_board)

      moved = MapSet.new([{2, 4}, {2, 3}])
      parent = self()
      f = &send(parent, &1)
      assert new_board = Board.apply_matches(moved_board, matches, moved, f)

      assert Board.show(new_board) == [
               [1, 4, 2, 3, 4, 1, 2, 1],
               [1, 3, 1, 4, 3, 3, 1, 1],
               [3, 8, 2, 3, 2, 1, 2, 2],
               [1, 1, 3, 2, 1, 1, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ]

      assert_receive {:new_kind, 2, 3, 8}
      assert_receive {:insert, 2, 3}
      assert_receive {:slide, 2, 1, 2}
      assert_receive {:insert, 2, 4}

      refute_receive _, 500
    end

    test "correct move (4 elements + extra_turn 1)", data do
      Piece.add_pieces([3, 4, 1])
      assert moved_board = Board.move(data.board, {1, 3}, {2, 3})

      assert Board.show(moved_board) == [
               [1, 8, 2, 3, 4, 1, 2, 1],
               [1, 8, 1, 4, 3, 3, 1, 1],
               [1, 3, 2, 3, 2, 1, 2, 2],
               [1, 8, 3, 2, 1, 1, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ]

      matches = MapSet.new(vertical: MapSet.new([{1, 1}, {1, 2}, {1, 3}, {1, 4}]))
      assert [1, 1, 1, 1] = Board.get_matched_cells(moved_board, matches)
      assert matches == Board.find_matches(moved_board)

      moved = MapSet.new([{2, 3}, {1, 3}])
      parent = self()
      f = &send(parent, &1)
      assert new_board = Board.apply_matches(moved_board, matches, moved, f)

      assert Board.show(new_board) == [
               [1, 8, 2, 3, 4, 1, 2, 1],
               [4, 8, 1, 4, 3, 3, 1, 1],
               [3, 3, 2, 3, 2, 1, 2, 2],
               [2, 8, 3, 2, 1, 1, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ]

      assert_receive {:new_kind, 1, 3, 2}
      assert_receive {:insert, 1, 1}
      assert_receive {:insert, 1, 3}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:insert, 1, 4}
      assert_receive {:slide, 1, 3, 4}
      assert_receive {:slide, 1, 2, 3}
      assert_receive {:slide, 1, 1, 2}

      refute_receive _, 500
    end

    test "correct move (5 elements + extra_turn 2)", data do
      Piece.add_pieces([3, 4, 1, 1])
      assert moved_board = Board.move(data.board, {6, 1}, {6, 2})

      assert Board.show(moved_board) == [
               [1, 8, 2, 3, 4, 3, 2, 1],
               [1, 8, 1, 4, 3, 1, 1, 1],
               [3, 1, 2, 3, 2, 1, 2, 2],
               [1, 8, 3, 2, 1, 1, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ]

      matches = MapSet.new(mixed: MapSet.new([{6, 2}, {7, 2}, {8, 2}, {6, 3}, {6, 4}]))
      assert [1, 1, 1, 1, 1] = Board.get_matched_cells(moved_board, matches)
      assert matches == Board.find_matches(moved_board)

      moved = MapSet.new([{6, 1}, {6, 2}])
      parent = self()
      f = &send(parent, &1)
      assert new_board = Board.apply_matches(moved_board, matches, moved, f)

      assert Board.show(new_board) == [
               [1, 8, 2, 3, 4, 1, 3, 4],
               [1, 8, 1, 4, 3, 1, 2, 1],
               [3, 1, 2, 3, 2, 3, 2, 2],
               [1, 8, 3, 2, 1, 2, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ]

      assert_receive {:new_kind, 6, 2, 2}
      assert_receive {:slide, 7, 1, 2}
      assert_receive {:insert, 7, 3}
      assert_receive {:slide, 8, 1, 2}
      assert_receive {:insert, 8, 4}
      assert_receive {:slide, 6, 2, 3}
      assert_receive {:slide, 6, 1, 2}
      assert_receive {:insert, 6, 1}
      assert_receive {:slide, 6, 3, 4}
      assert_receive {:slide, 6, 2, 3}
      assert_receive {:slide, 6, 1, 2}
      assert_receive {:insert, 6, 1}

      refute_receive _, 500
    end

    test "incorrect move, no match", data do
      assert moved_board = Board.move(data.board, {3, 1}, {4, 1})

      assert Board.show(moved_board) == [
               [1, 8, 3, 2, 4, 1, 2, 1],
               [1, 8, 1, 4, 3, 3, 1, 1],
               [3, 1, 2, 3, 2, 1, 2, 2],
               [1, 8, 3, 2, 1, 1, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ]

      matches = MapSet.new()
      assert matches == Board.find_matches(moved_board)
      refute_receive _, 500
    end

    test "incorrect move, illegal offset", data do
      assert {:error, {:illegal_move, {{3, 1}, {5, 1}}}} = Board.move(data.board, {3, 1}, {5, 1})
      assert data.pieces == Board.show(data.board)
      refute_receive _, 500
    end
  end
end