defmodule Leprechaun.Bot do
  use GenServer
  require Logger
  alias Leprechaun.{Board, Bot, Php}

  defstruct board_id: nil,
            websocket_pid: nil,
            code: ""

  def start_link(name, board_id) do
    GenServer.start_link __MODULE__, [board_id, self()], name: via(name)
  end

  def exists?(bot) do
    case Registry.lookup(Leprechaun.Bot.Registry, bot) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  def stop(bot), do: GenServer.stop(via(bot))

  def join(bot) do
    GenServer.cast via(bot), {:join, self()}
  end

  def run(bot, code) do
    GenServer.call via(bot), {:run, code}
  end

  defp via(bot) do
    {:via, Registry, {Leprechaun.Bot.Registry, bot}}
  end

  @impl true
  def init([board_id, websocket_pid]) do
    Board.add_consumer(board_id)
    {:ok, %Bot{board_id: board_id, websocket_pid: websocket_pid}}
  end

  @impl true
  def handle_cast({:join, websocket_pid}, bot) do
    {:noreply, %Bot{bot | websocket_pid: websocket_pid}}
  end

  @impl true
  def handle_call({:run, code}, _from, bot) do
    cells = Board.show(bot.board_id)
    result = Php.run(code, bot.board_id, cells)
    {:reply, result, %Bot{bot | code: code}}
  end

  @impl true
  def handle_info(:play, bot) do
    Process.sleep 2500
    cells = Board.show(bot.board_id)
    Php.run(bot.code, bot.board_id, cells)
    {:noreply, bot}
  end
  def handle_info(:extra_turn, state) do
    {:noreply, state}
  end
  def handle_info({:match, _score, _global_score, _acc, _cells}, state) do
    {:noreply, state}
  end
  def handle_info({:show, _cells}, state) do
    {:noreply, state}
  end
  def handle_info({:gameover, _score}, state) do
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
    Logger.warn "[bot] discarded info => #{other}"
    {:noreply, state}
  end
end
