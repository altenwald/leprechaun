defmodule Leprechaun.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :leprechaun,
    adapter: Ecto.Adapters.SQLite3
end
