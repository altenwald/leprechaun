import Config

if port = System.get_env("PORT") do
  config :leprechaun, port: String.to_integer(port)
end

# Production data must live outside the release directory.
if config_env() == :prod do
  database = System.fetch_env!("DATABASE_PATH")
  config :leprechaun, Leprechaun.Repo, database: Path.expand(database)
else
  if database = System.get_env("DATABASE_PATH") do
    config :leprechaun, Leprechaun.Repo, database: Path.expand(database)
  end
end
