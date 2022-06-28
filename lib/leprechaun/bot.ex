defmodule Leprechaun.Bot do
  @moduledoc """
  The bot is acting like Websocket and playing directly to the game following
  the instructions of a PHP code.
  """
  use GenServer
  require Logger
  alias Leprechaun.{Game, Bot, Php}

  defstruct board_id: nil,
            websocket_pid: nil,
            code: ""

  def start_link(name, board_id) do
    GenServer.start_link(__MODULE__, [board_id, self()], name: via(name))
  end

  def exists?(bot) do
    Registry.lookup(Leprechaun.Bot.Registry, bot) != []
  end

  def stop(bot), do: GenServer.stop(via(bot))

  def join(bot) do
    GenServer.cast(via(bot), {:join, self()})
  end

  def run(bot, code) do
    GenServer.call(via(bot), {:run, code})
  end

  defp via(bot) do
    {:via, Registry, {Leprechaun.Bot.Registry, bot}}
  end

  @impl true
  def init([board_id, websocket_pid]) do
    Game.add_consumer(board_id)
    {:ok, %Bot{board_id: board_id, websocket_pid: websocket_pid}}
  end

  @impl true
  def handle_cast({:join, websocket_pid}, bot) do
    {:noreply, %Bot{bot | websocket_pid: websocket_pid}}
  end

  @impl true
  def handle_call({:run, code}, _from, bot) do
    cells = Game.show(bot.board_id)
    result = Php.run(code, bot.board_id, cells)
    {:reply, result, %Bot{bot | code: code}}
  end

  @impl true
  def handle_info(:play, bot) do
    Process.sleep(2500)
    cells = Game.show(bot.board_id)
    Php.run(bot.code, bot.board_id, cells)
    {:noreply, bot}
  end

  def handle_info(:extra_turn, state) do
    {:noreply, state}
  end

  def handle_info({:match, _score, _global_score, _acc, _cells}, state) do
    {:noreply, state}
  end

  def handle_info({:slide, _x, _y_orig, _y_dest}, state) do
    {:noreply, state}
  end

  def handle_info({:insert, _x, _piece}, state) do
    {:noreply, state}
  end

  def handle_info({:show, _cells}, state) do
    {:noreply, state}
  end

  def handle_info({:gameover, _score, _}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:error, :gameover}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:hiscore, {:ok, _order}}, state) do
    {:noreply, state}
  end

  def handle_info({:error, {:illegal_move, {_x1, _y1}, {_x2, _y2}}}, state) do
    {:stop, :normal, state}
  end

  def handle_info(other, state) do
    Logger.warn("[bot] discarded info => #{inspect(other)}")
    {:noreply, state}
  end
end
