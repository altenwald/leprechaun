defmodule Leprechaun.MixProject do
  use Mix.Project

  def project do
    [
      app: :leprechaun,
      version: "0.2.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Leprechaun.Application, []},
      extra_applications: [:logger]
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
    ]
  end
end
