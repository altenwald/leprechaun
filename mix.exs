defmodule Leprechaun.MixProject do
  use Mix.Project

  def project do
    [
      app: :leprechaun,
      version: "1.2.4",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [
        leprechaun: [
          applications: [runtime_tools: :permanent],
          include_executables_for: [:unix],
          steps: [:assemble, :tar]
        ]
      ],
      test_coverage: [summary: [threshold: 90]],
      dialyzer: dialyzer()
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :test,
        credo: :test,
        dialyzer: :test,
        doctor: :test,
        sobelow: :test
      ]
    ]
  end

  defp dialyzer do
    case System.get_env("DIALYZER_PLT_DIR") do
      nil ->
        []

      directory ->
        path = Path.join(directory, to_string(:erlang.system_info(:system_architecture)))
        [plt_local_path: path, plt_core_path: path]
    end
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:jason, "~> 1.3"},
      {:plug, "~> 1.18"},
      {:bandit, "~> 1.8"},
      {:websock_adapter, "~> 0.5"},
      {:uuid, "~> 1.1"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, "~> 0.26.0"},

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
      release: ["deps.get --only prod", "compile", "release --overwrite"],
      check: [
        "ecto.create",
        "ecto.migrate",
        "check"
      ]
    ]
  end
end
