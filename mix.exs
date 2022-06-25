defmodule Leprechaun.MixProject do
  use Mix.Project

  def project do
    [
      app: :leprechaun,
      version: "1.0.1",
      elixir: "~> 1.13",
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
      {:jason, "~> 1.3"},
      {:plug, "~> 1.13"},
      {:plug_cowboy, "~> 2.5"},
      {:throttle, "~> 0.3", hex: :lambda_throttle},
      {:uuid, "~> 1.1"},
      {:ecto_mnesia, "~> 0.9"},
      {:ephp, "~> 0.3"},

      # for releases
      {:distillery, "~> 2.1"},
      {:ecto_boot_migration, "~> 0.1"},

      # tooling for quality check
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
