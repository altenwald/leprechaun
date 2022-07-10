defmodule Leprechaun.Console do
  @moduledoc """
  Interface for playing the game in the console. We only need to run the game
  using the following function:

  ```elixir
  Leprechaun.Console.run
  ```

  The game shows interactively the options available. Basically, we have to
  choose the first move `(x1, y1)` to `(x2, y2)` and depending on if that's
  legit, it's going to perform some matches and then asking us if we want to
  perform a new move or back to the Elixir shell.

  If we choose back to the Elixir shell we could return back to the game
  using:

  ```elixir
  Leprechaun.Console.run Leprechaun.Console
  ```

  Note that optionally we can use an extra parameter to localize the game, by
  default it will be the name of this module.
  """
  alias Leprechaun.Game

  @time_to_wait_blink 1500

  defp draw_number(1), do: IO.ANSI.color_background(52) <> " 💰 " <> IO.ANSI.reset()
  defp draw_number(2), do: IO.ANSI.light_black_background() <> " 💰 " <> IO.ANSI.reset()
  defp draw_number(3), do: IO.ANSI.yellow_background() <> " 💰 " <> IO.ANSI.reset()
  defp draw_number(4), do: IO.ANSI.color_background(52) <> " 💶 " <> IO.ANSI.reset()
  defp draw_number(5), do: IO.ANSI.light_black_background() <> " 💶 " <> IO.ANSI.reset()
  defp draw_number(6), do: IO.ANSI.yellow_background() <> " 💶 " <> IO.ANSI.reset()
  defp draw_number(7), do: IO.ANSI.light_black_background() <> " MX " <> IO.ANSI.reset()
  defp draw_number(8), do: IO.ANSI.yellow_background() <> " MX " <> IO.ANSI.reset()

  defp ask_int(prompt) do
    prompt
    |> IO.gets()
    |> String.trim()
    |> Integer.parse()
    |> elem(0)
  end

  defp ask_bool(prompt) do
    input =
      prompt
      |> IO.gets()
      |> String.trim()

    input in ["", "Y", "y", "yes"]
  end

  @doc """
  Start a new process game using the module name as the ID for the game
  and enter in a loop for playing interactively.
  """
  @spec run :: nil
  def run do
    {:ok, _game_pid} = Game.start(name: __MODULE__)
    run(__MODULE__)
  end

  @doc """
  Continue a game providing an ID for the game. If the game doesn't exist
  it's creating a new one with the provided ID.
  """
  @spec run(atom() | String.t()) :: nil
  def run(game) do
    unless Game.exists?(game), do: Game.start(name: game)
    cells = Game.show(game)
    score = Game.score(game)
    turns = Game.turns(game)
    show(score, turns, cells)
    IO.puts(IO.ANSI.underline() <> "move" <> IO.ANSI.reset())
    x1 = ask_int("from X: ")
    y1 = ask_int("from Y: ")

    show(score, turns, cells, blink: [{x1, y1}])
    IO.puts(IO.ANSI.underline() <> "move" <> IO.ANSI.reset())
    x2 = ask_int("to X: ")
    y2 = ask_int("to Y: ")

    Game.move(game, {x1, y1}, {x2, y2})
    continues? = recv_all(score, game, cells)

    if continues? and ask_bool("continue [Y/n]? ") do
      run(game)
    end
  end

  defp recv_all(global_score, game, cells) do
    receive do
      {:match, score, total_score, acc, cells} ->
        points = Enum.flat_map(acc, fn {_, p} -> p end)
        turns = Game.turns(game)
        show(total_score, turns, cells, blink: points)
        IO.puts("+#{score} points!")
        Process.sleep(@time_to_wait_blink)
        recv_all(total_score, game, cells)

      :extra_turn ->
        recv_all(global_score, game, cells)

      :play ->
        true

      {:insert, _x, _symbol} ->
        recv_all(global_score, game, cells)

      {:slide, _x, _y1, _y2} ->
        recv_all(global_score, game, cells)

      {:new_kind, _x, _y, _new_kind} ->
        recv_all(global_score, game, cells)

      {:show, cells} ->
        turns = Game.turns(game)
        show(global_score, turns, cells)
        recv_all(global_score, game, cells)

      {:gameover, score, _has_username} ->
        show(score, 0, cells)
        false

      {:move, _point1, _point2} ->
        recv_all(global_score, game, cells)

      {:error, error} ->
        IO.puts("error: #{inspect(error)}")
        true
    end
  end

  defp show(score, turns, cells, opts \\ []) do
    IO.puts(IO.ANSI.clear() <> "Leprechaun " <> to_string(Application.spec(:leprechaun)[:vsn]))
    IO.puts(IO.ANSI.underline() <> "Score" <> IO.ANSI.reset() <> ": #{score}")
    IO.puts(IO.ANSI.underline() <> "Turns" <> IO.ANSI.reset() <> ": #{turns}\n")
    blink = opts[:blink] || []

    ("     1   2   3   4   5   6   7   8\n" <>
       for y <- 1..8, into: "" do
         " #{y} " <>
           for x <- 1..8, into: "" do
             element =
               cells
               |> Enum.at(y - 1)
               |> Enum.at(x - 1)

             if {x, y} in blink do
               IO.ANSI.blink_slow() <>
                 draw_number(element) <>
                 IO.ANSI.reset()
             else
               draw_number(element)
             end
           end <>
           "\n"
       end)
    |> IO.puts()

    if turns == 0 do
      IO.puts(" G A M E   O V E R !!")
    end
  end
end
