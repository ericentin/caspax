defmodule Caspax.MixProject do
  use Mix.Project

  def project do
    [
      app: :caspax,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "An Elixir implementation of the CASPaxos distributed compare-and-set KV.",
      package: [
        links: ["https://github.com/ericentin/caspax"],
        maintainers: ["Eric Entin"],
        licenses: ["Apache 2.0"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Caspax.Application, []}
    ]
  end

  defp deps do
    []
  end
end
