use Mix.Config

config :leprechaun, port: 1234,
                    family: :inet

config :throttle, rates: [{:websocket, 1, :per_second}]
