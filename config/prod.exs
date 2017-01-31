use Mix.Config

config :php_internals, PhpInternals.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "https://php-internals.herokuapp.com/", port: 443, force_ssl: [rewrite_on: [:x_forwarded_proto]]],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :logger, level: :info

config :neo4j_sips, Neo4j,
  url: System.get_env("DB_URL"),
  basic_auth: [username: System.get_env("DB_USERNAME"), password: System.get_env("DB_PWS")],
  pool_size: 5,
  max_overflow: 2,
  timeout: 30
