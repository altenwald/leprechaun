defmodule Leprechaun.MixProject do
  use Mix.Project

  def project do
    [
      app: :leprechaun,
      version: "0.7.1",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Leprechaun.Application, []},
      extra_applications: [:logger, :mnesia]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.1"},
      {:plug, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"},
      {:throttle, "~> 0.2.0", hex: :lambda_throttle},
      {:uuid, "~> 1.1"},
      {:ecto_mnesia, "~> 0.9.1"},
      {:ephp, "~> 0.2"},

      # for releases
      {:distillery, "~> 2.0"},
      {:ecto_boot_migration, "~> 0.1.1"},
    ]
  end
end
