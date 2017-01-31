defmodule PhpInternals do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(PhpInternals.Endpoint, []),
      worker(Neo4j.Sips, [Application.get_env(:neo4j_sips, Neo4j)])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhpInternals.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PhpInternals.Endpoint.config_change(changed, removed)
    :ok
  end
end
