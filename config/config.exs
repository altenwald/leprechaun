import Config

config :leprechaun,
  port: 4012,
  family: :inet,
  initial_turns: 10

config :leprechaun, ecto_repos: [Leprechaun.Repo]

config :leprechaun, Leprechaun.Repo,
  database: Path.expand("../data/leprechaun_#{config_env()}.db", __DIR__),
  pool_size: 1,
  busy_timeout: 5_000
