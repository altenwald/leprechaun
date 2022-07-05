import Config

config :leprechaun,
  port: 4012,
  family: :inet

config :leprechaun, ecto_repos: [Leprechaun.Repo]

config :ecto_mnesia,
  host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
  storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

# Make sure this directory exists
if Mix.env() == :test do
  config :mnesia, dir: '/tmp/mnesia'
else
  config :mnesia, dir: 'priv/data/mnesia'
end

config :leprechaun, Leprechaun.Repo, adapter: EctoMnesia.Adapter
