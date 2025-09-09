defmodule IndexerWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :indexer_web,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :anoma_local_domain],
      included_applications: [],
      mod: {IndexerWeb.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:cors_plug, "~> 3.0"},
      {:anoma_local_domain, path: ".."}    ]
  end
end
