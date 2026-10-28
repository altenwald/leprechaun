defmodule Leprechaun.ReleaseTasks do
  @moduledoc """
  Database tasks for native Elixir releases, without Mix.

      bin/leprechaun eval 'Leprechaun.ReleaseTasks.run_migrations()'
  """

  @doc """
  Applies all pending migrations, starting the repository if necessary.
  """
  @spec run_migrations() :: :ok
  def run_migrations do
    :ok = Application.ensure_loaded(:leprechaun)

    for repo <- Application.fetch_env!(:leprechaun, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :ok
  end
end
