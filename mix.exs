defmodule PhpInternals.Mixfile do
  use Mix.Project

  def project do
    [app: :php_internals,
     version: "0.0.1",
     elixir: "~> 1.2",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {PhpInternals, []},
     applications: [:phoenix, :cowboy, :logger, :neo4j_sips, :oauth2, :corsica]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:phoenix, "~> 1.2.1"},
     {:cowboy, "~> 1.0"},
     {:neo4j_sips, "~> 0.2"},
     {:oauth2, "~> 0.9"},
     {:corsica, "~> 0.5"}]
  end
end
