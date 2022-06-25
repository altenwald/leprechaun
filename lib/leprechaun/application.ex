defmodule Leprechaun.Application do
  @moduledoc """
  Creates the application and the supervision tree for the games.
  This is in charge of running the migrations, starting the base
  for ePHP and configure the supervision tree.
  """
  use Application

  require Logger

  @port 1234
  @family :inet

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    port = Application.get_env(:leprechaun, :port, @port)
    family = Application.get_env(:leprechaun, :family, @family)

    {:ok, _} = EctoBootMigration.migrate(:leprechaun)

    :ephp.start()

    children = [
      # Start the Ecto repository
      Leprechaun.Repo,
      # Start the Registry for boards
      {Registry, keys: :unique, name: Leprechaun.Game.Registry},
      # Start the Registry for bots
      {Registry, keys: :unique, name: Leprechaun.Bot.Registry},
      # Start worker for HTTP listener
      {Leprechaun.Http, [port, family]}
    ]

    Logger.info("[app] iniciada aplicación")

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Leprechaun.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
