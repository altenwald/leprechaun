defmodule Leprechaun.Application do
  use Application

  require Logger

  @port 1234
  @family :inet

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    port = Application.get_env(:leprechaun, :port, @port)
    family = Application.get_env(:leprechaun, :family, @family)

    {:ok, _} = EctoBootMigration.migrate(:leprechaun)

    children = [
      # Start the Ecto repository
      supervisor(Leprechaun.Repo, []),
      # Start the Registry for boards
      supervisor(Registry, [:unique, Leprechaun.Registry]),
      # Start worker for HTTP listener
      worker(Leprechaun.Http, [port, family])
    ]

    Logger.info "[app] iniciada aplicación"

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Leprechaun.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
