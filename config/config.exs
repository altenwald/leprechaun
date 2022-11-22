import Config

config :leprechaun,
  port: 4012,
  family: :inet,
  initial_turns: 10

config :leprechaun, ecto_repos: [Leprechaun.Repo]

# Make sure this directory exists
if config_env() == :test do
  config :mnesia, dir: '/tmp/mnesia'
else
  config :mnesia, dir: 'priv/data/mnesia'
end

config :leprechaun, Leprechaun.Repo, adapter: EctoMnesia.Adapter
