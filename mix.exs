defmodule Leprechaun.MixProject do
  use Mix.Project

  def project do
    [
      app: :leprechaun,
      version: "1.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        check: :test,
        credo: :test,
        dialyzer: :test,
        doctor: :test,
        sobelow: :test
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:uuid, "~> 1.1"},
      {:ecto_mnesia, "~> 0.9"},
      {:ephp, "~> 0.3"},

      # for releases
      {:distillery, "~> 2.1"},
      {:ecto_boot_migration, "~> 0.1"},

      # tooling for quality check
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:doctor, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.14", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      check: [
        "ecto.create",
        "ecto.migrate",
        "check"
      ]
    ]
  end
end
