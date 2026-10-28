defmodule Leprechaun.Application do
  @moduledoc """
  Creates the application and the supervision tree for the games.
  This is in charge of running the migrations and configuring the supervision tree.
  """
  use Application

  require Logger

  @port 1234
  @family :inet

  @doc false
  def start(_type, _args) do
    port = Application.get_env(:leprechaun, :port, @port)
    family = Application.get_env(:leprechaun, :family, @family)

    children = [
      # Start the Ecto repository
      Leprechaun.Repo,
      {Ecto.Migrator, repos: [Leprechaun.Repo]},
      # Start the Registry for boards
      {Registry, keys: :unique, name: Leprechaun.Game.Registry},
      # Start DynamicSupervisor for games
      {DynamicSupervisor, strategy: :one_for_one, name: Leprechaun.Games},
      # Start worker for HTTP listener
      {Bandit,
       plug: Leprechaun.Http,
       scheme: :http,
       port: port,
       thousand_island_options: [transport_options: [family]]}
    ]

    Logger.info("[app] iniciada aplicación")

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Leprechaun.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
