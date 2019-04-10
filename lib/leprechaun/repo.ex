defmodule Leprechaun.Repo do
  use Ecto.Repo,
    otp_app: :leprechaun,
    adapter: EctoMnesia.Adapter
end
