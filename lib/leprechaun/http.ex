defmodule Leprechaun.Http do
  require Logger

  defp priv(file), do: priv('/' ++ file, file)
  defp priv(path, file) do
    {path, :cowboy_static, {:priv_file, :leprechaun, file}}
  end

  defp priv_dir(path, dir) do
    {path, :cowboy_static, {:priv_dir, :leprechaun, dir,
                            [{:mimetypes, :cow_mimetypes, :all}]}}
  end

  def start_link(port_number, family) do
    dispatch = :cowboy_router.compile [
      {:_, [
        priv('/', 'index.html'),
        priv('favicon.ico'),
        priv('app.css'),
        priv('app.js'),
        priv_dir('/img/[...]', 'img'),
        priv_dir('/js/[...]', 'js'),
        {'/websession', Leprechaun.Websocket, []}
      ]}
    ]
    opts = %{env: %{dispatch: dispatch}}
    port = [{:port, port_number}, family]
    {:ok, _} = :cowboy.start_clear(__MODULE__, port, opts)
  end

  def init(req, opts) do
    {:cowboy_websocket, req, opts}
  end

  def handle(req, state) do
    Logger.debug "Unexpected request: #{inspect req}"
    headers = %{"content-Type" => "text/html"}
    {:ok, req} = :cowboy_req.reply(404, headers)
    {:ok, req, state}
  end

  def terminate(_reason, _req, _state) do
    Logger.info "terminate (#{inspect self()})"
    :ok
  end
end
