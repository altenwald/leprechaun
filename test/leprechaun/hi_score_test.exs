defmodule Leprechaun.HiScoreTest do
  use ExUnit.Case
  alias Leprechaun.{HiScore, Repo}

  describe "top list" do
    setup do
      Repo.delete_all(HiScore)
      HiScore.save("User1", 6000, 200, 100, "127.0.0.1")
      HiScore.save("User2", 5500, 150, 90, "127.0.0.1")
      HiScore.save("User3", 4500, 100, 50, "127.0.0.1")
      HiScore.save("User4", 4000, 80, 30, "127.0.0.1")
      HiScore.save("User5", 2000, 50, 20, "127.0.0.1")
      :ok
    end

    test "top list" do
      assert [
               %HiScore{name: "User1"},
               %HiScore{name: "User2"},
               %HiScore{name: "User3"},
               %HiScore{name: "User4"},
               %HiScore{name: "User5"}
             ] = HiScore.top_list()
    end

    test "get correctly my index" do
      my_id = Repo.get_by!(HiScore, name: "User1").id

      assert 1 = HiScore.get_order(my_id)
    end

    test "get incorrect index" do
      assert is_nil(HiScore.get_order(0))
    end

    test "stores timestamps and fields in SQLite" do
      assert {:ok, saved} = HiScore.save("SQLite player", 1234, 20, 3, "192.0.2.1")
      stored = Repo.get!(HiScore, saved.id)

      assert stored.name == "SQLite player"
      assert stored.score == 1234
      assert stored.turns == 20
      assert stored.extra_turns == 3
      assert stored.remote_ip == "192.0.2.1"
      assert %NaiveDateTime{} = stored.inserted_at
      assert %NaiveDateTime{} = stored.updated_at
    end

    test "rerunning release migrations preserves high scores" do
      before = HiScore.top_list()
      assert :ok = Leprechaun.ReleaseTasks.run_migrations()
      assert HiScore.top_list() == before
    end
  end
end
