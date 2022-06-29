defmodule Leprechaun.Bot do
  @moduledoc """
  The bot is acting like Websocket and playing directly to the game following
  the instructions of a PHP code.
  """
  use GenServer
  require Logger
  alias Leprechaun.{Game, Bot, Php}

  @wait_between_moves 2_500

  @typedoc """
  The opaque type for the internal state of the bot.
  """
  @opaque t() :: %__MODULE__{
            game_name: Game.game_name(),
            websocket_pid: pid() | nil,
            code: String.t()
          }

  defstruct game_name: nil,
            websocket_pid: nil,
            code: ""

  @doc """
  Start the bot using a name to register the bot and requesting the name
  of the game the bot have to play with.
  """
  def start_link(name, game_name) do
    GenServer.start_link(__MODULE__, [game_name, self()], name: via(name))
  end

  @doc """
  Check if the bot exists.
  """
  def exists?(bot) do
    Registry.lookup(Leprechaun.Bot.Registry, bot) != []
  end

  @doc """
  Stop the bot.
  """
  def stop(bot), do: GenServer.stop(via(bot))

  @doc """
  Configure the websocket PID to the caller PID. It's intended to run
  this from the websocket code.
  """
  def set_websocket_pid(bot) do
    GenServer.cast(via(bot), {:set_websocket_pid, self()})
  end

  @doc """
  Order the bot to run a specific PHP code. This is using
  `Leprechaun.Php.run/3` and returning the result to the caller.
  """
  def run(bot, code) do
    GenServer.call(via(bot), {:run, code})
  end

  defp via(bot) do
    {:via, Registry, {Leprechaun.Bot.Registry, bot}}
  end

  @doc false
  @impl true
  def init([game_name, websocket_pid]) do
    Game.add_consumer(game_name)
    {:ok, %Bot{game_name: game_name, websocket_pid: websocket_pid}}
  end

  @doc false
  @impl true
  def handle_cast({:join, websocket_pid}, bot) do
    {:noreply, %Bot{bot | websocket_pid: websocket_pid}}
  end

  @doc false
  @impl true
  def handle_call({:run, code}, _from, bot) do
    cells = Game.show(bot.game_name)
    result = Php.run(code, bot.game_name, cells)
    {:reply, result, %Bot{bot | code: code}}
  end

  @doc false
  @impl true
  def handle_info(:play, bot) do
    Process.sleep(@wait_between_moves)
    cells = Game.show(bot.game_name)
    Php.run(bot.code, bot.game_name, cells)
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

  def handle_info({:hiscore, _position}, state) do
    {:noreply, state}
  end

  def handle_info({:move, _point1, _point2}, state) do
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
