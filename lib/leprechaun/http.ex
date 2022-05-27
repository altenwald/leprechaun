defmodule Leprechaun.Http do
  require Logger

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

  def start_link([port_number, family]) do
    opts = %{env: %{dispatch: dispatch()}}
    port = [{:port, port_number}, family]
    {:ok, _} = :cowboy.start_clear(__MODULE__, port, opts)
  end

  def code_upgrade do
    :cowboy.set_env(__MODULE__, :dispatch, dispatch())
  end

  def init(req, opts) do
    {:cowboy_websocket, req, opts}
  end

  def handle(req, state) do
    Logger.debug("Unexpected request: #{inspect(req)}")
    headers = %{"content-Type" => "text/html"}
    {:ok, req} = :cowboy_req.reply(404, headers)
    {:ok, req, state}
  end

  def terminate(_reason, _req, _state) do
    Logger.info("terminate (#{inspect(self())})")
    :ok
  end
end
