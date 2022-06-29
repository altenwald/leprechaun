defmodule Leprechaun.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :leprechaun,
    adapter: EctoMnesia.Adapter

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end
end
