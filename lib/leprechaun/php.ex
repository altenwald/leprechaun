defmodule Leprechaun.Php do
  require Logger

  alias :ephp, as: Ephp
  alias :ephp_config, as: EphpConfig
  alias :ephp_output, as: EphpOutput
  alias :ephp_context, as: EphpContext
  alias :ephp_parser, as: EphpParser
  alias :ephp_array, as: EphpArray
  alias Leprechaun.Board

  @behaviour :ephp_func

  @impl true
  def init_config() do
    []
  end

  @impl true
  def init_func() do
    [
      {:leprechaun_check_move, [:integer, :integer, :integer, :integer]},
      {:leprechaun_move, [:integer, :integer, :integer, :integer]},
      {:leprechaun_get_points, [:integer, :integer]}
    ]
  end
  
  @impl true
  def init_const() do
    []
  end

  def leprechaun_check_move(ctx, _line, {_, x1}, {_, y1}, {_, x2}, {_, y2}) do
    {check, matches} = Board.check_move(EphpContext.get_meta(ctx, :board_id), {x1, y1}, {x2, y2})
    tr(%{"check" => check,
         "matches" => matches})
  end

  def leprechaun_move(ctx, _line, {_, x1}, {_, y1}, {_, x2}, {_, y2}) do
    Board.move(EphpContext.get_meta(ctx, :board_id), {x1, y1}, {x2, y2})
    true
  end

  def leprechaun_get_points(_ctx, _line, {_, x}, {_, y}) when x < 1 or x > 8 or y < 1 or y > 8, do: false
  def leprechaun_get_points(ctx, _line, {_, x}, {_, y}) do
    Board.show(EphpContext.get_meta(ctx, :board_id))
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
  defp tr(other), do: other

  def register_assigns(context, assigns) do
    data = Enum.map(assigns, fn {k, v} -> {to_string(k), tr(v)} end)
    EphpContext.set_bulk(context, data)
  end

  @filename "/bot.php"
  @name "bot.php"

  def run(content, board_id, cells) do
    try do
      parsed = EphpParser.parse(content)
      Logger.debug "[php] content => #{inspect content}"
      EphpConfig.start_link(Application.get_env(:php, :php_ini, "php.ini"))
      EphpConfig.start_local()
      {:ok, ctx} = Ephp.context_new(@filename)
      Logger.debug "[php] cells => #{inspect cells}"
      register_assigns ctx, board: cells
      Ephp.register_superglobals ctx, [@name]
      Ephp.register_module ctx, __MODULE__
      {:ok, output} = EphpOutput.start_link(ctx, false)
      EphpContext.set_output_handler ctx, output
      EphpContext.set_meta ctx, :board_id, board_id
      try do
        Ephp.eval @filename, ctx, parsed
      catch
        {:ok, :die} -> :ok
      end
      out = EphpContext.get_output(ctx)
      EphpContext.destroy_all ctx
      EphpConfig.stop_local()
      out
    catch
      {:error, :eparse, {{:line, line}, _col}, _errorlevel, _data} ->
        <<"PHP ERROR line: #{line}">>
    end
  end
end
