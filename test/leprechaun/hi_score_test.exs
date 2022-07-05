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

    test "top 5" do
      assert [
        %HiScore{name: "User1"},
        %HiScore{name: "User2"},
        %HiScore{name: "User3"},
        %HiScore{name: "User4"},
        %HiScore{name: "User5"},
      ] = HiScore.top_list()
    end
  end
end
