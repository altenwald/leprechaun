defmodule Leprechaun.Http do
  @moduledoc """
  Implements the functions needed to use cowboy, mainly the dispatching for the
  static files and starting of the websocket connection.
  """
  require Logger

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  defp priv(file), do: priv('/' ++ file, file)

  defp priv(path, file) do
    {path, :cowboy_static, {:priv_file, :leprechaun, file}}
  end

  defp priv_dir(path, dir) do
    {path, :cowboy_static, {:priv_dir, :leprechaun, dir, [{:mimetypes, :cow_mimetypes, :all}]}}
  end

  defp dispatch do
    :cowboy_router.compile([
      {:_,
       [
         priv('/', 'index.html'),
         priv('/bot/', 'bot.html'),
         priv('favicon.ico'),
         priv_dir('/audio/[...]', 'audio'),
         priv_dir('/img/[...]', 'img'),
         priv_dir('/js/[...]', 'js'),
         priv_dir('/css/[...]', 'css'),
         {'/websession', Leprechaun.Websocket, []}
       ]}
    ])
  end

  @doc """
  Start the HTTP server for the port and family (IPv4 or IPv6) indicated by the options.
  """
  def start_link([port_number, family]) do
    opts = %{env: %{dispatch: dispatch()}}
    port = [{:port, port_number}, family]
    {:ok, _} = :cowboy.start_clear(__MODULE__, port, opts)
  end

  @doc false
  def code_upgrade do
    :cowboy.set_env(__MODULE__, :dispatch, dispatch())
  end

  @doc false
  def init(req, opts) do
    {:cowboy_websocket, req, opts}
  end

  @doc false
  def handle(req, state) do
    Logger.debug("Unexpected request: #{inspect(req)}")
    headers = %{"content-type" => "text/html"}
    req = :cowboy_req.reply(404, headers, req)
    {:ok, req, state}
  end

  @doc false
  def terminate(_reason, _req, _state) do
    Logger.info("terminate (#{inspect(self())})")
    :ok
  end
end
