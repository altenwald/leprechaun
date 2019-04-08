defmodule Leprechaun.Game do

  alias Leprechaun.Board

  @time_to_wait 500
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
    input = prompt
            |> IO.gets()
            |> String.trim()
    input in ["", "Y", "y", "yes"]
  end

  def run do
    {:ok, board} = Board.start_link(__MODULE__)
    run board
  end

  def run(board) do
    cells = Board.show(board)
    score = Board.score(board)
    turns = Board.turns(board)
    show score, turns, cells
    IO.puts IO.ANSI.underline() <> "move" <> IO.ANSI.reset()
    x1 = ask_int "from X: "
    y1 = ask_int "from Y: "

    show score, turns, cells, blink: [{x1, y1}]
    IO.puts IO.ANSI.underline() <> "move" <> IO.ANSI.reset()
    x2 = ask_int "to X: "
    y2 = ask_int "to Y: "

    Board.move board, {x1, y1}, {x2, y2}
    continues? = recv_all score, board, cells

    if continues? and ask_bool("continue [Y/n]? ") do
      run(board)
    end
  end

  defp recv_all(global_score, board, cells) do
    receive do
      {:match, score, extra_turn, acc, cells} ->
        points = for({_, p} <- acc, do: p)
                 |> List.flatten()
        turns = Board.turns(board)
        show global_score, turns, cells, blink: points
        IO.puts "+#{score} points!" <> if(extra_turn == :extra_turn, do: " EXTRA!", else: "")
        Process.sleep @time_to_wait_blink
        recv_all global_score + score, board, cells
      {:show, cells} ->
        turns = Board.turns(board)
        show global_score, turns, cells
        recv_all global_score, board, cells
      {:gameover, score} ->
        show score, 0, cells
        show_stats Board.stats(board)
        false
      {:error, error} ->
        IO.inspect error
        true
    after @time_to_wait ->
      true
    end
  end

  defp show(score, turns, cells, opts \\ []) do
    IO.puts IO.ANSI.clear() <> "Leprechaun " <> to_string(Application.spec(:leprechaun)[:vsn])
    IO.puts IO.ANSI.underline() <> "Score" <> IO.ANSI.reset() <> ": #{score}"
    IO.puts IO.ANSI.underline() <> "Turns" <> IO.ANSI.reset() <> ": #{turns}\n"
    blink = if opts[:blink] do
      opts[:blink]
    else
      []
    end
    "     1   2   3   4   5   6   7   8\n" <>
    for y <- 1..8, into: "" do
      " #{y} " <>
      for x <- 1..8, into: "" do
        element = cells
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
    end
    |> IO.puts()
    if turns == 0 do
      IO.puts " G A M E   O V E R !!"
    end
  end

  defp humanize("played_turns"), do: "Played Turns"
  defp humanize("extra_turns"), do: "Extra Turns"
  defp humanize(other), do: other

  defp show_stats(stats) do
    for {key, value} <- stats do
      IO.puts "#{humanize(key)} = #{value}"
    end
  end
end
