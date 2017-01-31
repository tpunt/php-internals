# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :php_internals, PhpInternals.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "er2XiHOa+FxInCGnRH92sOlm68YiVjfyvvyBTM3SLUIdsXkYy632h4wzRWD6VyB7",
  render_errors: [view: PhpInternals.ErrorView, accepts: ~w(json)],
  pubsub: [name: PhpInternals.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :oauth2, PhpInternals.Auth.GitHub,
  client_id: "dc8b1aaa5cf9d8d9d8ff",#System.get_env("GITHUB_CLIENT_ID"),
  client_secret: "83c8847145dd100230bdae006d1c8212d4c3cd74",#System.get_env("GITHUB_CLIENT_SECRET"),
  redirect_uri: "http://php-internals.herokuapp.com/api/auth/github/callback"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
