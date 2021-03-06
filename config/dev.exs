use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :php_internals, PhpInternals.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: System.get_env("HOST_DEV") || "${HOST_DEV}", port: {:system, "PORT"}],
  debug_errors: true,
  code_reloader: false,
  server: true,
  check_origin: false,
  watchers: []

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

config :neo4j_sips, Neo4j,
  url: System.get_env("NEO4J_URL_DEV") || "${NEO4J_URL_DEV}",
  basic_auth: [
    username: System.get_env("NEO4J_USERNAME_DEV") || "${NEO4J_USERNAME_DEV}",
    password: System.get_env("NEO4J_PASSWORD_DEV") || "${NEO4J_PASSWORD_DEV}"
  ],
  pool_size: 5,
  max_overflow: 2,
  timeout: 5_000
