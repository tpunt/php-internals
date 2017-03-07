use Mix.Config

config :php_internals, PhpInternals.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "http://phpinternals.net", port: 80],
  secret_key_base: "1vI7iIBTEechr9R54osamnxE7OzjgMsBNTP8wiE7M3+b7k0c2CqD/XNhqIjpURSw"

config :logger, level: :info

config :neo4j_sips, Neo4j,
  url: "http://localhost:7474",
  basic_auth: [username: "neo4j", password: "neo4j"],
  pool_size: 5,
  max_overflow: 2,
  timeout: 30
