defmodule Leprechaun.Php do
  @moduledoc """
  Implements functions and information needed to configure the sandbox
  for PHP and letting handle the information for a specific game.

  We can find here three functions:

  - `leprechaun_check_move`: which is letting us to check what's happening
    if we perform that move but in a dry-run.
  - `leprechaun_move`: performs the movement.
  - `leprechaun_get_points`: let us check the board in a specific position.

  We have also different global variables registered like:

  - `$board` is an array of arrays including the content of the board.

  IMPORTANT: The PHP code is only running for one turn. It's intended to
  perform a move and finnish. See the `Leprechaun.Bot` to see how it's
  implementing its usage.
  """
  require Logger

  alias :ephp, as: Ephp
  alias :ephp_config, as: EphpConfig
  alias :ephp_output, as: EphpOutput
  alias :ephp_context, as: EphpContext
  alias :ephp_parser, as: EphpParser
  alias :ephp_array, as: EphpArray
  alias Leprechaun.Game

  @behaviour :ephp_lib

  @doc false
  @impl :ephp_lib
  def init_config() do
    []
  end

  @doc false
  @impl :ephp_lib
  def init_func() do
    [
      {:leprechaun_check_move, [args: [:integer, :integer, :integer, :integer]]},
      {:leprechaun_move, [args: [:integer, :integer, :integer, :integer]]},
      {:leprechaun_get_points, [args: [:integer, :integer]]}
    ]
  end

  @doc false
  @impl :ephp_lib
  def init_const() do
    []
  end

  @doc """
  Perform a `Game.check_move/3` based on the data passed to the PHP function
  and translates the output to be handled by PHP:

  ```php
  var_dump(leprechaun_check_move(1, 1, 2, 1))
  # [true, [[1, 1], [1, 2], [1, 3]]

  var_dump(leprechaun_check_move(1, 1, 3, 1))
  # [false, []]
  ```
  """
  def leprechaun_check_move(ctx, _line, {_, x1}, {_, y1}, {_, x2}, {_, y2}) do
    {check, matches} = Game.check_move(EphpContext.get_meta(ctx, :game_id), {x1, y1}, {x2, y2})
    tr(%{"check" => check, "matches" => matches})
  end

  @doc """
  Perform a `Game.move/3` based on the data passed to the PHP function:

  ```php
  var_dump(leprechaun_move(1, 1, 2, 1))
  # true
  ```
  """
  def leprechaun_move(ctx, _line, {_, x1}, {_, y1}, {_, x2}, {_, y2}) do
    Game.move(EphpContext.get_meta(ctx, :game_id), {x1, y1}, {x2, y2})
    true
  end

  @doc """
  Retrieves data for a specific cell from the board:

  ```php
  var_dump(leprechaun_get_points(1, 1))
  # 3
  ```
  """
  def leprechaun_get_points(_ctx, _line, {_, x}, {_, y}) when x < 1 or x > 8 or y < 1 or y > 8,
    do: false

  def leprechaun_get_points(ctx, _line, {_, x}, {_, y}) do
    Game.show(EphpContext.get_meta(ctx, :game_id))
    |> Enum.at(y - 1)
    |> Enum.at(x - 1)
  end

  defp tr(%{} = assigns) do
    assigns
    |> Enum.map(fn {k, v} -> {to_string(k), tr(v)} end)
    |> EphpArray.from_list()
  end

  defp tr(list) when is_list(list) do
    list
    |> Enum.map(&tr/1)
    |> EphpArray.from_list()
  end

  defp tr(true), do: true
  defp tr(false), do: false
  defp tr(nil), do: :undefined
  defp tr(atom) when is_atom(atom), do: to_string(atom)
  defp tr(tuple) when is_tuple(tuple), do: tr(Tuple.to_list(tuple))
  defp tr(list) when is_list(list), do: list
  defp tr(other), do: Enum.to_list(other)

  @doc false
  def register_assigns(context, assigns) do
    data = Enum.map(assigns, fn {k, v} -> {to_string(k), tr(v)} end)
    EphpContext.set_bulk(context, data)
  end

  @filename "/bot.php"
  @name 'bot.php'

  @doc """
  Perform the running of a certain PHP code, it's passing as parameters:

  - `content` the PHP code to be running.
  - `game_id` the ID for the process game.
  - `cells` the board content.

  Every time it's called we have to provide a fresh board representation which
  we could obtain using `Leprechaun.Game.show/1`.
  """
  def run(content, game_id, cells) do
    try do
      parsed = EphpParser.parse(content)
      Logger.debug("[php] content => #{inspect(content)}")
      EphpConfig.start_link(Application.get_env(:php, :php_ini, "php.ini"))
      EphpConfig.start_local()
      {:ok, ctx} = Ephp.context_new(@filename)
      Logger.debug("[php] cells => #{inspect(cells)}")
      register_assigns(ctx, board: cells)
      Ephp.register_superglobals(ctx, @name, [])
      Ephp.register_module(ctx, __MODULE__)
      {:ok, output} = EphpOutput.start_link(ctx, false)
      EphpContext.set_output_handler(ctx, output)
      EphpContext.set_meta(ctx, :game_id, game_id)

      try do
        Ephp.eval(@filename, ctx, parsed)
      catch
        {:ok, :die} -> :ok
      end

      out = EphpContext.get_output(ctx)
      EphpContext.destroy_all(ctx)
      EphpConfig.stop_local()
      out
    catch
      {:error, :eparse, {{:line, line}, _col}, _errorlevel, _data} ->
        <<"PHP ERROR line: #{line}">>
    end
  end
end
