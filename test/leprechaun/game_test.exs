defmodule Leprechaun.GameTest do
  use ExUnit.Case
  alias Leprechaun.Game
  alias Leprechaun.Support.Piece

  describe "starting" do
    test "correct start and stoping manually" do
      board = [
        [1, 2, 2, 3, 4, 3, 2, 1],
        [1, 2, 1, 4, 3, 2, 1, 1],
        [3, 1, 2, 3, 2, 1, 2, 2],
        [1, 2, 3, 2, 1, 2, 1, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      Piece.set_pieces(List.flatten(board))

      name = :game1
      assert {:ok, pid} = Game.start_link(name)
      assert Game.exists?(name)
      assert is_pid(pid) and Process.alive?(pid)
      assert board == Game.show(name)
      assert :ok = Game.stop(name)
      refute is_pid(pid) and Process.alive?(pid)
      Process.sleep(100)
      refute Game.exists?(name)
    end

    test "correct start and stoping by timeout" do
      board = [
        [1, 2, 2, 3, 4, 3, 2, 1],
        [1, 2, 1, 4, 3, 2, 1, 1],
        [3, 1, 2, 3, 2, 1, 2, 2],
        [1, 2, 3, 2, 1, 2, 1, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      Piece.set_pieces(List.flatten(board))

      name = :game1
      assert {:ok, pid} = Game.start_link(name, max_running_time: 250)
      Process.monitor(pid)
      assert Game.exists?(name)
      assert is_pid(pid) and Process.alive?(pid)
      assert board == Game.show(name)

      assert_receive {:DOWN, _ref, :process, ^pid, :normal}, 500
      refute is_pid(pid) and Process.alive?(pid)
      Process.sleep(100)
      refute Game.exists?(name)
    end

    test "cannot setup the cells" do
      board = [
        [1, 2, 2, 3, 4, 3, 2, 1],
        [1, 2, 1, 4, 3, 2, 1, 1],
        [1, 3, 2, 3, 2, 1, 2, 2],
        [1, 2, 3, 2, 1, 2, 1, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      Piece.set_pieces(List.flatten(board))
      Piece.add_pieces([3, 1, 1, 1])

      name = :game1

      {pid, ref} =
        spawn_monitor(fn ->
          Game.start_link(name, max_tries: 1)
        end)

      assert_receive {:DOWN, ^ref, :process, ^pid,
                      {{:badmatch, {:error, {:bad_return_value, :badluck}}}, _stack_trace}}
    end
  end

  describe "consumers" do
    test "adding and terminating consumer" do
      board = [
        [1, 2, 2, 3, 4, 3, 2, 1],
        [1, 2, 1, 4, 3, 2, 1, 1],
        [3, 1, 2, 3, 2, 1, 2, 2],
        [1, 2, 3, 2, 1, 2, 1, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      Piece.set_pieces(List.flatten(board))

      name = :gameC
      assert {:ok, pid} = Game.start_link(name)
      assert Game.exists?(name)
      assert is_pid(pid) and Process.alive?(pid)
      assert board == Game.show(name)

      mypid = self()
      assert %Game{consumers: [^mypid]} = :sys.get_state(pid)

      spawn_link(fn ->
        Game.add_consumer(name)
        thispid = self()
        assert %Game{consumers: [^thispid, ^mypid]} = :sys.get_state(pid)
        send(mypid, :continue)
      end)

      assert_receive :continue
      assert %Game{consumers: [^mypid]} = :sys.get_state(pid)
    end
  end

  describe "playing" do
    setup do
      board = [
        [1, 8, 2, 3, 4, 1, 2, 1],
        [1, 8, 1, 4, 3, 3, 1, 1],
        [3, 1, 2, 3, 2, 1, 2, 2],
        [1, 8, 3, 2, 1, 1, 3, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      Piece.set_pieces(List.flatten(board))

      name = :game2
      {:ok, pid} = Game.start_link(name)
      %{board: board, pid: pid, name: name}
    end

    test "correct move (3 elements, type 8)", data do
      Piece.add_pieces([3, 4])
      assert :ok = Game.move(data.name, {2, 4}, {2, 3})

      assert_receive {:match, 24, 24,
                      [
                        vertical: [{2, 3}, {2, 2}, {2, 1}]
                      ],
                      [
                        [1, 8, 2, 3, 4, 1, 2, 1],
                        [1, 8, 1, 4, 3, 3, 1, 1],
                        [3, 8, 2, 3, 2, 1, 2, 2],
                        [1, 1, 3, 2, 1, 1, 3, 1],
                        [2, 3, 2, 3, 2, 3, 2, 3],
                        [3, 2, 3, 2, 3, 2, 3, 2],
                        [2, 3, 2, 3, 2, 3, 2, 3],
                        [3, 2, 3, 2, 3, 2, 3, 2]
                      ]}

      new_board = [
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
      assert_receive {:slide_new, 2, 3}
      assert_receive {:slide, 2, 1, 2}
      assert_receive {:slide_new, 2, 4}

      assert_receive {:show, ^new_board}
      assert_receive :play
      assert new_board == Game.show(data.name)
      assert 24 == Game.score(data.name)
      assert 9 == Game.turns(data.name)
      refute_receive _, 500
    end

    test "correct move (4 elements + extra_turn 1)", data do
      Piece.add_pieces([3, 4, 1])
      assert :ok = Game.move(data.name, {1, 3}, {2, 3})
      assert_receive {:extra_turn, 1}

      assert_receive {:match, 4, 4,
                      [
                        vertical: [{1, 4}, {1, 3}, {1, 2}, {1, 1}]
                      ],
                      [
                        [1, 8, 2, 3, 4, 1, 2, 1],
                        [1, 8, 1, 4, 3, 3, 1, 1],
                        [1, 3, 2, 3, 2, 1, 2, 2],
                        [1, 8, 3, 2, 1, 1, 3, 1],
                        [2, 3, 2, 3, 2, 3, 2, 3],
                        [3, 2, 3, 2, 3, 2, 3, 2],
                        [2, 3, 2, 3, 2, 3, 2, 3],
                        [3, 2, 3, 2, 3, 2, 3, 2]
                      ]}

      assert_receive {:new_kind, 1, 3, 2}
      assert_receive {:slide_new, 1, 1}
      assert_receive {:slide_new, 1, 3}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:slide_new, 1, 4}
      assert_receive {:slide, 1, 3, 4}
      assert_receive {:slide, 1, 2, 3}
      assert_receive {:slide, 1, 1, 2}

      new_board = [
        [1, 8, 2, 3, 4, 1, 2, 1],
        [4, 8, 1, 4, 3, 3, 1, 1],
        [3, 3, 2, 3, 2, 1, 2, 2],
        [2, 8, 3, 2, 1, 1, 3, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      assert_receive {:show, ^new_board}
      assert_receive :play
      assert new_board == Game.show(data.name)
      assert 4 == Game.score(data.name)
      assert 10 == Game.turns(data.name)
      refute_receive _, 500
    end

    test "correct move (5 elements + extra_turn 2)", data do
      Piece.add_pieces([3, 4, 1, 1])
      assert :ok = Game.move(data.name, {6, 1}, {6, 2})
      assert_receive {:extra_turn, 2}

      assert_receive {:match, 5, 5,
                      [
                        mixed: [{6, 4}, {6, 3}, {6, 2}, {8, 2}, {7, 2}]
                      ],
                      [
                        [1, 8, 2, 3, 4, 3, 2, 1],
                        [1, 8, 1, 4, 3, 1, 1, 1],
                        [3, 1, 2, 3, 2, 1, 2, 2],
                        [1, 8, 3, 2, 1, 1, 3, 1],
                        [2, 3, 2, 3, 2, 3, 2, 3],
                        [3, 2, 3, 2, 3, 2, 3, 2],
                        [2, 3, 2, 3, 2, 3, 2, 3],
                        [3, 2, 3, 2, 3, 2, 3, 2]
                      ]}

      assert_receive {:new_kind, 6, 2, 2}
      assert_receive {:slide, 7, 1, 2}
      assert_receive {:slide_new, 7, 3}
      assert_receive {:slide, 8, 1, 2}
      assert_receive {:slide_new, 8, 4}
      assert_receive {:slide, 6, 2, 3}
      assert_receive {:slide, 6, 1, 2}
      assert_receive {:slide_new, 6, 1}
      assert_receive {:slide, 6, 3, 4}
      assert_receive {:slide, 6, 2, 3}
      assert_receive {:slide, 6, 1, 2}
      assert_receive {:slide_new, 6, 1}

      new_board = [
        [1, 8, 2, 3, 4, 1, 3, 4],
        [1, 8, 1, 4, 3, 1, 2, 1],
        [3, 1, 2, 3, 2, 3, 2, 2],
        [1, 8, 3, 2, 1, 2, 3, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      assert_receive {:show, ^new_board}
      assert_receive :play
      assert new_board == Game.show(data.name)
      assert 5 == Game.score(data.name)
      assert 11 == Game.turns(data.name)
      refute_receive _, 500
    end

    test "incorrect move, no match", data do
      assert :ok = Game.move(data.name, {3, 1}, {4, 1})
      assert_receive {:error, {:illegal_move, {3, 1}, {4, 1}}}
      assert data.board == Game.show(data.name)
      refute_receive _, 500
    end

    test "incorrect move, illegal offset", data do
      assert :ok = Game.move(data.name, {3, 1}, {5, 1})
      assert_receive {:error, {:illegal_move, {3, 1}, {5, 1}}}
      assert data.board == Game.show(data.name)
      refute_receive _, 500
    end
  end

  describe "game over" do
    setup do
      Leprechaun.Repo.delete_all(Leprechaun.HiScore)

      board = [
        [1, 2, 2, 3, 4, 1, 2, 1],
        [1, 2, 1, 4, 3, 3, 1, 1],
        [3, 1, 2, 3, 2, 1, 2, 2],
        [4, 2, 3, 2, 1, 1, 3, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      Piece.set_pieces(List.flatten(board))

      name = :game2
      {:ok, pid} = Game.start_link(name, turns: 1)
      %{board: board, pid: pid, name: name}
    end

    test "receive game over", data do
      Piece.add_pieces([3, 4])
      assert {:error, :still_playing} = Game.hiscore(data.name, "Manuel Rubio", "127.0.0.1")
      assert :ok = Game.move(data.name, {1, 3}, {2, 3})

      assert_receive {:match, 3, 3,
                      [
                        vertical: [{1, 3}, {1, 2}, {1, 1}]
                      ],
                      [
                        [1, 2, 2, 3, 4, 1, 2, 1],
                        [1, 2, 1, 4, 3, 3, 1, 1],
                        [1, 3, 2, 3, 2, 1, 2, 2],
                        [4, 2, 3, 2, 1, 1, 3, 1],
                        [2, 3, 2, 3, 2, 3, 2, 3],
                        [3, 2, 3, 2, 3, 2, 3, 2],
                        [2, 3, 2, 3, 2, 3, 2, 3],
                        [3, 2, 3, 2, 3, 2, 3, 2]
                      ]}

      assert_receive {:new_kind, 1, 3, 2}
      assert_receive {:slide_new, 1, 3}
      assert_receive {:slide, 1, 1, 2}
      assert_receive {:slide_new, 1, 4}

      new_board = [
        [4, 2, 2, 3, 4, 1, 2, 1],
        [3, 2, 1, 4, 3, 3, 1, 1],
        [2, 3, 2, 3, 2, 1, 2, 2],
        [4, 2, 3, 2, 1, 1, 3, 1],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2],
        [2, 3, 2, 3, 2, 3, 2, 3],
        [3, 2, 3, 2, 3, 2, 3, 2]
      ]

      assert_receive {:show, ^new_board}
      assert_receive {:gameover, 3, false}
      assert :ok = Game.hiscore(data.name, "Manuel Rubio", "127.0.0.1")
      assert {:error, :already_set} = Game.hiscore(data.name, "Manuel Rubio", "127.0.0.1")
      assert_receive {:hiscore, {:ok, 1}}
      assert :ok = Game.move(data.name, {1, 3}, {2, 3})
      assert_receive {:error, :gameover}
      refute_receive _, 500
    end
  end
end
