defmodule Leprechaun.ConsoleTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Leprechaun.{Console, Game}

  @board [
    [1, 2, 2, 3, 4, 1, 2, 1],
    [1, 2, 1, 4, 3, 3, 1, 1],
    [3, 1, 2, 3, 2, 1, 2, 2],
    [4, 2, 3, 2, 1, 1, 3, 1],
    [2, 3, 2, 3, 2, 3, 2, 3],
    [3, 2, 3, 2, 3, 2, 3, 2],
    [2, 3, 2, 3, 2, 3, 2, 3],
    [3, 2, 3, 2, 3, 2, 3, 2]
  ]

  test "starts the default game and reports an illegal move" do
    cleanup(Console)
    output = capture_io("1\n1\n8\n8\nn\n", fn -> assert is_nil(Console.run()) end)
    assert output =~ "Leprechaun"
    assert output =~ "from X:"
    assert output =~ "to Y:"
    assert output =~ "illegal_move"
    assert output =~ "continue [Y/n]?"
    assert Game.exists?(Console)
  end

  test "creates a named game and continues when the player answers yes" do
    name = UUID.uuid4()
    cleanup(name)
    input = "1\n1\n8\n8\nyes\n1\n1\n8\n8\nn\n"
    output = capture_io(input, fn -> Console.run(name) end)
    assert length(Regex.scan(~r/continue \[Y\/n\]\?/, output)) == 2
    assert Game.turns(name) == 10
  end

  test "renders all piece types and highlights the selected cell" do
    name = UUID.uuid4()
    cleanup(name)
    pieces = for y <- 0..7, x <- 0..7, do: rem(x + y * 3, 10) + 1
    {:ok, _} = Game.start(name: name, pieces: pieces)
    output = capture_io("1\n1\n8\n8\nn\n", fn -> Console.run(name) end)
    for symbol <- ["💰", "💶", "MX", "🧚‍♀️", "🍀"], do: assert(output =~ symbol)
    assert output =~ IO.ANSI.blink_slow()
  end

  test "renders a match, consumes animation events and offers another turn" do
    name = start_game(2)
    output = capture_io("1\n3\n2\n3\nn\n", fn -> Console.run(name) end)
    assert output =~ "+3 points!"
    assert output =~ "continue [Y/n]?"
    assert Game.score(name) == 3
    assert Game.turns(name) == 1
    refute_receive {:extra_turn, _}
    refute_receive {:slide, _, _, _}
    refute_receive {:new_kind, _, _, _}
  end

  test "prints game over on the last turn without asking to continue" do
    name = start_game(1)
    output = capture_io("1\n3\n2\n3\n", fn -> Console.run(name) end)
    assert output =~ "+3 points!"
    assert output =~ "G A M E   O V E R"
    refute output =~ "continue [Y/n]?"
    assert Game.turns(name) == 0
  end

  defp start_game(turns) do
    name = UUID.uuid4()
    cleanup(name)
    {:ok, _} = Game.start(name: name, pieces: List.flatten(@board) ++ [3, 4], turns: turns)
    name
  end

  defp cleanup(name) do
    on_exit(fn -> if Game.exists?(name), do: Game.stop(name) end)
  end
end
