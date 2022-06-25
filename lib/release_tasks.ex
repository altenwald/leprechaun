defmodule Leprechaun.ReleaseTasks do
  @moduledoc """
  When we perform a release we lose Mix and the possibility to use its tasks.
  This module is a way to implement some of the needed tasks only available
  initially in Mix like `ecto.migrate`.

  The idea of this module is to be in use by commands from Distillery or the
  release commands.
  """

  @doc """
  Run the migrations, exactly the same as if we run `mix ecto.migrate` but
  when Mix isn't available.
  """
  @spec run_migrations :: :ok
  def run_migrations do
    Application.get_env(:leprechaun, :ecto_repos, [])
    |> Enum.each(&run_migrations_for/1)
    :ok
  end

  defp run_migrations_for(repo) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running migrations for #{app}")
    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config, :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, repo_underscore, filename])
  end
end
