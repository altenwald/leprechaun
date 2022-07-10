defmodule Leprechaun.BoardTest do
  use ExUnit.Case

  alias Leprechaun.Board
  alias Leprechaun.Board.Piece

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

      Piece.set(List.flatten(pieces))

      assert %Board{} = board = Board.new()
      assert pieces == Board.show(board)
      assert {8, 8} == Board.get_size(board)
    end

    test "clean" do
      pieces = [
        [1, 2, 2, 2, 4, 3, 2, 1],
        [1, 2, 1, 4, 3, 2, 1, 1],
        [3, 1, 2, 3, 2, 1, 2, 2],
        [1, 2, 3, 2, 1, 2, 1, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        3,
        1
      ]

      new_board = [
        [1, 3, 3, 1, 4, 3, 2, 1],
        [1, 2, 1, 4, 3, 2, 1, 1],
        [3, 1, 2, 3, 2, 1, 2, 2],
        [1, 2, 3, 2, 1, 2, 1, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      Piece.set(List.flatten(pieces))

      assert %Board{} = board = Board.new()
      assert new_board == Board.show(board)
      assert {8, 8} == Board.get_size(board)
    end
  end

  describe "access behaviour" do
    test "incorrect position" do
      assert %Board{} = board = Board.new(2, 2)
      assert is_nil(board[0])
      assert is_nil(board[3])
    end

    test "pop" do
      assert %Board{} = board = Board.new(2, 2)
      assert {%{1 => _, 2 => _}, ^board} = Access.pop(board, 1)
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

      Piece.set(List.flatten(pieces))

      board = Board.new()
      %{board: board, pieces: pieces}
    end

    test "match kind", data do
      matches = MapSet.new(mixed: MapSet.new([{2, 1}, {2, 2}, {2, 4}]))
      assert matches == Board.match_kind(data.board, 8)
    end

    test "increment kind", data do
      parent = self()
      f = &send(parent, &1)
      board = Board.incr_kind(data.board, 4, f)

      assert [
               [1, 8, 2, 3, 5, 1, 2, 1],
               [1, 8, 1, 5, 3, 3, 1, 1],
               [3, 1, 2, 3, 2, 1, 2, 2],
               [1, 8, 3, 2, 1, 1, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ] == Board.show(board)

      assert_receive {:new_kind, 5, 1, 5}
      assert_receive {:new_kind, 4, 2, 5}
      refute_receive _, 500
    end

    test "increment maximum kind", data do
      parent = self()
      f = &send(parent, &1)

      board =
        data.board
        |> Board.incr_kind(8, f)
        |> Board.incr_kind(9, f)
        |> Board.incr_kind(10, f)

      assert [
               [1, 10, 2, 3, 4, 1, 2, 1],
               [1, 10, 1, 4, 3, 3, 1, 1],
               [3, 1, 2, 3, 2, 1, 2, 2],
               [1, 10, 3, 2, 1, 1, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ] == Board.show(board)

      assert_receive {:new_kind, 2, 1, 9}
      assert_receive {:new_kind, 2, 2, 9}
      assert_receive {:new_kind, 2, 4, 9}
      assert_receive {:new_kind, 2, 1, 10}
      assert_receive {:new_kind, 2, 2, 10}
      assert_receive {:new_kind, 2, 4, 10}
      refute_receive _, 500
    end

    test "remove match cells from the board", data do
      Piece.push([1, 2, 3, 4, 5, 6, 7, 8])
      parent = self()
      f = &send(parent, &1)
      matches = MapSet.new(mixed: MapSet.new(for y <- 1..8, do: {1, y}))
      board = Board.remove_matches(data.board, matches, f)

      assert [
               [8, 8, 2, 3, 4, 1, 2, 1],
               [7, 8, 1, 4, 3, 3, 1, 1],
               [6, 1, 2, 3, 2, 1, 2, 2],
               [5, 8, 3, 2, 1, 1, 3, 1],
               [4, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [1, 2, 3, 2, 3, 2, 3, 2]
             ] == Board.show(board)

      assert_receive {:insert, 1, 1}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:insert, 1, 2}
      assert_receive {:slide, 1, 2, 3}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:insert, 1, 3}
      assert_receive {:slide, 1, 3, 4}
      assert_receive {:slide, 1, 2, 3}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:insert, 1, 4}
      assert_receive {:slide, 1, 4, 5}
      assert_receive {:slide, 1, 3, 4}
      assert_receive {:slide, 1, 2, 3}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:insert, 1, 5}
      assert_receive {:slide, 1, 5, 6}
      assert_receive {:slide, 1, 4, 5}
      assert_receive {:slide, 1, 3, 4}
      assert_receive {:slide, 1, 2, 3}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:insert, 1, 6}
      assert_receive {:slide, 1, 6, 7}
      assert_receive {:slide, 1, 5, 6}
      assert_receive {:slide, 1, 4, 5}
      assert_receive {:slide, 1, 3, 4}
      assert_receive {:slide, 1, 2, 3}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:insert, 1, 7}
      assert_receive {:slide, 1, 7, 8}
      assert_receive {:slide, 1, 6, 7}
      assert_receive {:slide, 1, 5, 6}
      assert_receive {:slide, 1, 4, 5}
      assert_receive {:slide, 1, 3, 4}
      assert_receive {:slide, 1, 2, 3}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:insert, 1, 8}
      refute_receive _, 500
    end

    test "correct move (3 elements, type 8)", data do
      Piece.push([3, 4])
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
               [3, 9, 2, 3, 2, 1, 2, 2],
               [1, 1, 3, 2, 1, 1, 3, 1],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2],
               [2, 3, 2, 3, 2, 3, 2, 3],
               [3, 2, 3, 2, 3, 2, 3, 2]
             ]

      assert_receive {:new_kind, 2, 3, 9}
      assert_receive {:insert, 2, 3}
      assert_receive {:slide, 2, 1, 2}
      assert_receive {:insert, 2, 4}

      refute_receive _, 500
    end

    test "correct move (4 elements + extra_turn 1)", data do
      Piece.push([3, 4, 1])
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
      new_board = Board.apply_matches(moved_board, matches, moved, f)

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
      Piece.push([3, 4, 1, 1])
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

  describe "multi-matching" do
    test "double match no moves around" do
      pieces = [
        [4, 5, 4],
        [2, 2, 2],
        [3, 4, 6],
        [5, 6, 1],
        [6, 7, 1],
        [7, 8, 1]
      ]

      Piece.set(List.flatten(pieces ++ [2, 4, 1, 3]))

      board = Board.bare_new(3, 6)

      matches =
        MapSet.new(
          vertical: MapSet.new([{3, 4}, {3, 5}, {3, 6}]),
          horizontal: MapSet.new([{1, 2}, {2, 2}, {3, 2}])
        )

      assert [2, 2, 2, 1, 1, 1] = Board.get_matched_cells(board, matches)
      assert matches == Board.find_matches(board)

      moved = MapSet.new()
      parent = self()
      f = &send(parent, &1)

      new_board = Board.apply_matches(board, matches, moved, f)

      assert [
               [4, 2, 3],
               [3, 5, 1],
               [3, 4, 4],
               [5, 6, 4],
               [6, 7, 6],
               [7, 8, 2]
             ] == Board.show(new_board)

      assert_receive {:new_kind, 1, 2, 3}
      assert_receive {:slide, 2, 1, 2}
      assert_receive {:insert, 2, 2}
      assert_receive {:slide, 3, 1, 2}
      assert_receive {:insert, 3, 4}
      assert_receive {:new_kind, 3, 4, 2}
      assert_receive {:slide, 3, 4, 5}
      assert_receive {:slide, 3, 3, 4}
      assert_receive {:slide, 3, 2, 3}
      assert_receive {:slide, 3, 1, 2}
      assert_receive {:insert, 3, 1}
      assert_receive {:slide, 3, 5, 6}
      assert_receive {:slide, 3, 4, 5}
      assert_receive {:slide, 3, 3, 4}
      assert_receive {:slide, 3, 2, 3}
      assert_receive {:slide, 3, 1, 2}
      assert_receive {:insert, 3, 3}
      refute_receive _, 500
    end

    test "double horizontal match no moves around" do
      pieces = [
        [4, 5, 4, 3],
        [1, 2, 2, 2],
        [3, 4, 6, 2],
        [1, 1, 1, 5],
        [6, 7, 2, 3],
        [7, 8, 1, 4]
      ]

      Piece.set(List.flatten(pieces ++ [3, 1, 2, 1]))

      board = Board.bare_new(4, 6)

      matches =
        MapSet.new(
          horizontal: MapSet.new([{1, 4}, {2, 4}, {3, 4}]),
          horizontal: MapSet.new([{2, 2}, {3, 2}, {4, 2}])
        )

      assert [1, 1, 1, 2, 2, 2] = Enum.sort(Board.get_matched_cells(board, matches))
      assert matches == Board.find_matches(board)

      moved = MapSet.new()
      parent = self()
      f = &send(parent, &1)
      new_board = Board.apply_matches(board, matches, moved, f)

      assert [
               [4, 2, 1, 1],
               [1, 5, 3, 3],
               [3, 3, 4, 2],
               [2, 4, 6, 5],
               [6, 7, 2, 3],
               [7, 8, 1, 4]
             ] == Board.show(new_board)

      assert_receive {:new_kind, 1, 4, 2}
      assert_receive {:new_kind, 2, 2, 3}
      assert_receive {:slide, 3, 1, 2}
      assert_receive {:insert, 3, 3}
      assert_receive {:slide, 4, 1, 2}
      assert_receive {:insert, 4, 1}
      assert_receive {:slide, 2, 3, 4}
      assert_receive {:slide, 2, 2, 3}
      assert_receive {:slide, 2, 1, 2}
      assert_receive {:insert, 2, 2}
      assert_receive {:slide, 3, 3, 4}
      assert_receive {:slide, 3, 2, 3}
      assert_receive {:slide, 3, 1, 2}
      assert_receive {:insert, 3, 1}
      refute_receive _, 500
    end
  end
end
