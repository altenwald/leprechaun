import Config

config :leprechaun,
  port: 4012,
  family: :inet

config :throttle, rates: [{:websocket, 1, :per_second}]

config :leprechaun, ecto_repos: [Leprechaun.Repo]

config :ecto_mnesia,
  host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
  storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

# Make sure this directory exists
config :mnesia, dir: 'priv/data/mnesia'

config :leprechaun, Leprechaun.Repo, adapter: EctoMnesia.Adapter
