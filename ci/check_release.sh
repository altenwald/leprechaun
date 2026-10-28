#!/bin/sh
set -eu

release="$(pwd)/_build/prod/rel/leprechaun/bin/leprechaun"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
export DATABASE_PATH="$work/leprechaun.db"
export RELEASE_DISTRIBUTION=none

# Exercise the packaged SQLite driver, migrations and production snapshot twice.
for attempt in 1 2; do
  "$release" eval 'Logger.configure(level: :warning); Leprechaun.ReleaseTasks.run_migrations()'
done

"$release" eval '
  Logger.configure(level: :warning)
  {:ok, :ok, _} = Ecto.Migrator.with_repo(Leprechaun.Repo, fn repo ->
    snapshot = :leprechaun
      |> Application.app_dir("priv/repo/seeds/production_scores.json")
      |> File.read!()
      |> Jason.decode!()
    expected = length(snapshot["scores"])
    ^expected = repo.aggregate(Leprechaun.HiScore, :count)
    IO.puts("Release verified: #{expected} scores, no duplicates after repeated migrations")
    :ok
  end)
'
