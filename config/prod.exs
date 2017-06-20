use Mix.Config

config :php_internals, PhpInternals.Endpoint,
  http: [port: {:system, "PORT"}],
  secret_key_base: System.get_env("SECRET_KEY_BASE_PROD"),
  url: [host: "http://phpinternals.net", port: 80]

config :logger, level: :info

config :neo4j_sips, Neo4j,
  url: "http://localhost:7474",
  basic_auth: [
    username: System.get_env("NEO4J_USERNAME_PROD"),
    password: System.get_env("NEO4J_PASSWORD_PROD")
  ],
  pool_size: 5,
  max_overflow: 2,
  timeout: 5_000
