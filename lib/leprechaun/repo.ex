defmodule Leprechaun.Repo do
  use Ecto.Repo,
    otp_app: :leprechaun,
    adapter: EctoMnesia.Adapter

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end
end
