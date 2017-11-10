use Mix.Config

config :php_internals, PhpInternals.Endpoint,
  http: [port: {:system, "PORT"}],
  secret_key_base: "${SECRET_KEY_BASE_PROD}",
  url: [host: "${HOST_PROD}", port: {:system, "PORT"}],
  server: true

config :logger, level: :info

config :neo4j_sips, Neo4j,
  url: "${NEO4J_URL_PROD}",
  basic_auth: [
    username: "${NEO4J_USERNAME_PROD}",
    password: "${NEO4J_PASSWORD_PROD}"
  ],
  pool_size: 5,
  max_overflow: 2,
  timeout: 5_000
