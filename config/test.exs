use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :php_internals, PhpInternals.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :logger, :console,
  format: "$message\n",
  colors: [warn: :green]

config :neo4j_sips, Neo4j,
  url: "http://localhost:7474",
  basic_auth: [
    username: System.get_env("NEO4J_USERNAME_TEST"),
    password: System.get_env("NEO4J_PASSWORD_TEST")
  ],
  pool_size: 10,
  max_overflow: 2,
  timeout: 5_000
