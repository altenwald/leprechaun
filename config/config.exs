use Mix.Config

config :leprechaun, port: 1234,
                    family: :inet

config :throttle, rates: [{:websocket, 1, :per_second}]

config :leprechaun, ecto_repos: [Leprechaun.Repo]

config :ecto_mnesia,
  host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
  storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

config :mnesia, dir: 'priv/data/mnesia' # Make sure this directory exists

config :leprechaun, Leprechaun.Repo,
  adapter: EctoMnesia.Adapter
